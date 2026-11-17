import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../application/project_providers.dart';
import '../data/project_repository.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});
  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? failure;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await ref.read(projectRepositoryProvider).create(name.text);
      ref.invalidate(projectsProvider);
      name.clear();
      if (mounted) showPlannerNotice(context, 'Projeto criado com sucesso');
    } catch (_) {
      if (mounted) {
        setState(() => failure = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir projeto?'),
        content: Text(
          '“${project.name}” e todos os seus editais, cronogramas, tarefas e sessões serão excluídos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            child: const Text('Excluir projeto'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(projectRepositoryProvider).delete(project.id);
    ref.invalidate(projectsProvider);
    ref.invalidate(dashboardProvider);
    if (mounted) showPlannerNotice(context, 'Projeto excluído');
  }

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.layers_outlined,
    title: 'Meus projetos',
    subtitle: 'Organize cada concurso em um espaço separado.',
    actions: [
      FilledButton.icon(
        onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
        icon: const Icon(Icons.add),
        label: const Text('Novo projeto'),
      ),
    ],
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final cards = ref
            .watch(projectsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(projectsProvider),
                  child: const Text('Recarregar projetos'),
                ),
              ),
              data: (items) => Column(
                children: [
                  if (items.isEmpty)
                    _emptyProject()
                  else
                    for (var i = 0; i < items.length; i++) ...[
                      _projectCard(items[i], i),
                      const SizedBox(height: 14),
                    ],
                  _emptyProject(compact: true),
                ],
              ),
            );
        if (narrow) {
          return Column(
            children: [cards, const SizedBox(height: 16), _createPanel()],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: cards),
            const SizedBox(width: 20),
            SizedBox(width: 360, child: _createPanel()),
          ],
        );
      },
    ),
  );

  Widget _projectCard(Project project, int index) => PlannerCard(
    padding: const EdgeInsets.all(20),
    child: InkWell(
      onTap: () => context.go('/syllabus/${project.id}'),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: index.isEven ? AppTokens.redSoft : AppTokens.lavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Projeto criado pelo usuário',
                      style: TextStyle(color: AppTokens.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções do projeto',
                onSelected: (value) {
                  if (value == 'delete') _deleteProject(project);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 8),
                        Text('Excluir projeto'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<ProjectStats>(
            future: ref.read(projectRepositoryProvider).stats(project.id),
            builder: (context, snapshot) => LayoutBuilder(
              builder: (context, c) {
                final stats = snapshot.data;
                final metrics = <(String, String, double, IconData)>[
                  (
                    'Edital (cobertura)',
                    _percent(stats?.coverage ?? 0),
                    stats?.coverage ?? 0,
                    Icons.layers_outlined,
                  ),
                  (
                    'Cronograma concluído',
                    _percent(stats?.scheduleProgress ?? 0),
                    stats?.scheduleProgress ?? 0,
                    Icons.calendar_month_outlined,
                  ),
                  (
                    'Estudo na semana',
                    '${_hours(stats?.weekStudiedSeconds ?? 0)} / ${_minutes(stats?.weekPlannedMinutes ?? 0)}',
                    stats?.weeklyProgress ?? 0,
                    Icons.track_changes,
                  ),
                ];
                if (c.maxWidth < 620) {
                  return Column(
                    children: [
                      for (final m in metrics)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _projectMetric(m),
                        ),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      Expanded(child: _projectMetric(metrics[i])),
                      if (i < metrics.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _projectMetric((String, String, double, IconData) metric) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTokens.background,
      border: Border.all(color: AppTokens.border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(metric.$4, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(metric.$1, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          metric.$2,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        MiniProgress(value: metric.$3),
      ],
    ),
  );

  Widget _emptyProject({bool compact = false}) => InkWell(
    onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
    borderRadius: BorderRadius.circular(AppTokens.radius),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 30 : 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppTokens.border),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: const Column(
        children: [
          Icon(Icons.add, size: 32, color: AppTokens.muted),
          SizedBox(height: 8),
          Text(
            'Novo projeto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Crie um novo projeto para organizar os estudos de outro concurso.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.muted),
          ),
        ],
      ),
    ),
  );

  Widget _createPanel() => PlannerCard(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Criar projeto', icon: Icons.note_add_outlined),
          const SizedBox(height: 20),
          const Text(
            'Nome do concurso',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: name,
            validator: (v) => ProjectRepository.validateName(v ?? ''),
            maxLength: 120,
            decoration: const InputDecoration(
              hintText: 'Ex.: TJSP 2026',
              counterText: '',
            ),
            onFieldSubmitted: (_) => save(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Salvando…' : 'Continuar'),
            ),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                failure!,
                style: const TextStyle(color: AppTokens.error),
              ),
            ),
        ],
      ),
    ),
  );

  String _percent(double value) => '${(value * 100).round()}%';
  String _hours(int seconds) =>
      '${seconds ~/ 3600}h${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}';
  String _minutes(int minutes) =>
      '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
}
