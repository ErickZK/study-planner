import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../../core/database/seeds/tjsp_2026_material_seed.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../projects/application/project_providers.dart';
import '../../syllabus/application/syllabus_providers.dart';
import '../application/schedule_providers.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_template_repository.dart';

class SchedulesPage extends ConsumerStatefulWidget {
  const SchedulesPage({super.key});

  @override
  ConsumerState<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends ConsumerState<SchedulesPage> {
  bool importingMaterial = false;
  bool importingTemplate = false;

  ScheduleTemplateRepository get _templateRepository =>
      ScheduleTemplateRepository(ref.read(databaseProvider).requireValue);

  Future<void> _exportTemplate(StudySchedule schedule) async {
    try {
      final contents = await _templateRepository.exportTemplate(schedule.id);
      final safeName = schedule.name
          .replaceAll(
            RegExp(r'[^a-zA-Z0-9áàâãéèêíìîóòôõúùûçÁÀÂÃÉÈÊÍÌÎÓÒÔÕÚÙÛÇ _-]'),
            '',
          )
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Exportar template do cronograma',
        fileName: '${safeName.isEmpty ? 'cronograma' : safeName}.tjspplan',
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/vnd.tjsp-planner.template+json',
      );
      if (uri != null && mounted) {
        showPlannerNotice(
          context,
          'Template exportado sem dados pessoais ou histórico do aluno',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $error')),
        );
      }
    }
  }

  Future<void> _importTemplate() async {
    if (importingTemplate) return;
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Importar template do Planner',
      type: FileType.custom,
      allowedExtensions: const ['tjspplan', 'json'],
    );
    if (selected == null) return;
    if (!mounted) return;
    final settings = await _templateImportSettings();
    if (settings == null || !mounted) return;
    setState(() => importingTemplate = true);
    try {
      final length = await selected.length();
      if (length != null && length > 10 * 1024 * 1024) {
        throw const FormatException('O template excede o limite de 10 MB.');
      }
      final source = await selected.xFile.readAsString();
      final result = await _templateRepository.importTemplate(
        source,
        startDate: settings.startDate,
        restDays: settings.restDays,
      );
      ref.invalidate(catalogProvider);
      ref.invalidate(allSchedulesProvider);
      ref.invalidate(syllabusProvider(result.scheduleId));
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Template importado: ${result.disciplines} disciplinas, ${result.topics} assuntos e ${result.activities} atividades.',
          ),
        ),
      );
      context.go('/planner/${result.scheduleId}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível importar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => importingTemplate = false);
    }
  }

  Future<({DateTime startDate, Set<int> restDays})?>
  _templateImportSettings() async {
    var startDate = DateTime.now();
    final restDays = <int>{DateTime.sunday};
    const labels = <int, String>{
      DateTime.monday: 'Seg',
      DateTime.tuesday: 'Ter',
      DateTime.wednesday: 'Qua',
      DateTime.thursday: 'Qui',
      DateTime.friday: 'Sex',
      DateTime.saturday: 'Sáb',
      DateTime.sunday: 'Dom',
    };
    return showDialog<({DateTime startDate, Set<int> restDays})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configurar início do cronograma'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A primeira atividade será colocada na data inicial ou no próximo dia permitido.',
                  style: TextStyle(color: AppTokens.muted),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Data inicial'),
                  subtitle: Text(
                    '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      helpText: 'Escolha a data inicial',
                      cancelText: 'Cancelar',
                      confirmText: 'Usar esta data',
                      fieldLabelText: 'Data inicial',
                      fieldHintText: 'DD/MM/AAAA',
                    );
                    if (selected != null) {
                      setDialogState(() => startDate = selected);
                    }
                  },
                ),
                const Divider(height: 24),
                const Text(
                  'Dias de folga',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nenhuma atividade será colocada nos dias selecionados.',
                  style: TextStyle(color: AppTokens.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in labels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: restDays.contains(entry.key),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            restDays.add(entry.key);
                          } else {
                            restDays.remove(entry.key);
                          }
                        }),
                      ),
                  ],
                ),
                if (restDays.length == 7) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Deixe pelo menos um dia disponível para estudos.',
                    style: TextStyle(color: AppTokens.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: restDays.length == 7
                  ? null
                  : () => Navigator.pop(dialogContext, (
                      startDate: startDate,
                      restDays: {...restDays},
                    )),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Importar cronograma'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configurePomodoro(StudySchedule schedule) async {
    var focus = schedule.focusMinutes;
    var shortBreak = schedule.breakMinutes;
    var longBreak = schedule.longBreakMinutes;
    var rounds = schedule.roundsPerLongBreak;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Text('🍅', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text('Configurar Pomodoro'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _timeSetting(
                  label: 'Tempo de foco',
                  value: focus,
                  values: const [15, 20, 25, 30, 40, 45, 50, 60],
                  onChanged: (value) => setDialogState(() => focus = value),
                ),
                const SizedBox(height: 12),
                _timeSetting(
                  label: 'Pausa curta',
                  value: shortBreak,
                  values: const [3, 5, 10, 15],
                  onChanged: (value) =>
                      setDialogState(() => shortBreak = value),
                ),
                const SizedBox(height: 12),
                _timeSetting(
                  label: 'Pausa longa',
                  value: longBreak,
                  values: const [10, 15, 20, 25, 30],
                  onChanged: (value) => setDialogState(() => longBreak = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: rounds,
                  decoration: const InputDecoration(
                    labelText: 'Ciclos antes da pausa longa',
                  ),
                  items: [
                    for (final value in const [2, 3, 4, 5, 6])
                      DropdownMenuItem(
                        value: value,
                        child: Text('$value ciclos'),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => rounds = value ?? rounds),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A configuração vale para todas as sessões deste planejamento e também para os widgets.',
                  style: TextStyle(color: AppTokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await ref
        .read(scheduleRepositoryProvider)
        .update(
          schedule.id,
          focusMinutes: focus,
          breakMinutes: shortBreak,
          longBreakMinutes: longBreak,
          roundsPerLongBreak: rounds,
        );
    ref.invalidate(allSchedulesProvider);
    if (mounted) showPlannerNotice(context, 'Configuração do Pomodoro salva');
  }

  Widget _timeSetting({
    required String label,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final minutes in values)
        DropdownMenuItem(value: minutes, child: Text('$minutes minutos')),
    ],
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );

  Future<void> _deleteSchedule(StudySchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cronograma?'),
        content: Text(
          '“${schedule.name}” e todas as suas tarefas e sessões de estudo serão excluídas permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            child: const Text('Excluir cronograma'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(scheduleRepositoryProvider).delete(schedule.id);
    ref.invalidate(allSchedulesProvider);
    ref.invalidate(dashboardProvider);
    if (mounted) showPlannerNotice(context, 'Cronograma excluído');
  }

  Future<void> _importTjspMaterial() async {
    if (importingMaterial) return;
    setState(() => importingMaterial = true);
    try {
      final database = ref.read(databaseProvider).requireValue;
      final projectId = await ref
          .read(scheduleRepositoryProvider)
          .ensureOwner();
      final result = await Tjsp2026MaterialSeed(
        database,
      ).importIntoProject(projectId);
      ref.invalidate(catalogProvider);
      ref.invalidate(syllabusProvider(result.scheduleId));
      ref.invalidate(allSchedulesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyImported
                ? 'O material já estava importado. Abrindo o cronograma existente.'
                : '${result.disciplines} disciplinas, ${result.topics} tópicos e ${result.activities} sessões importados.',
          ),
        ),
      );
      context.go('/planner/${result.scheduleId}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível importar o material: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => importingMaterial = false);
    }
  }

  Future<void> _openCreatePlanner() async {
    final name = TextEditingController(text: 'Meu cronograma');
    var startDate = DateTime.now();
    var dailyMinutes = 150;
    var saving = false;
    final studyDays = <int>{1, 2, 3, 4, 5, 6};

    final scheduleId = await showDialog<int>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (name.text.trim().isEmpty || studyDays.isEmpty || saving) return;
            setDialogState(() => saving = true);
            try {
              final projectId = await ref
                  .read(scheduleRepositoryProvider)
                  .ensureOwner();
              final id = await ref
                  .read(scheduleRepositoryProvider)
                  .createStudyPlan(
                    projectId: projectId,
                    name: name.text,
                    startDate: startDate,
                    dailyMinutes: dailyMinutes,
                    studyDays: studyDays,
                    useSelectedSyllabus: false,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, id);
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Não foi possível criar: $error')),
                );
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            title: const Row(
              children: [
                Icon(Icons.calendar_month_outlined),
                SizedBox(width: 12),
                Text('Criar planejamento'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome do planejamento',
                        hintText: 'Ex.: Pós-edital TJSP',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Início e carga diária',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(_friendlyDate(startDate)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => startDate = picked);
                            }
                          },
                        ),
                        for (final minutes in const [120, 150, 180, 240])
                          ChoiceChip(
                            label: Text(_duration(minutes)),
                            selected: dailyMinutes == minutes,
                            onSelected: (_) =>
                                setDialogState(() => dailyMinutes = minutes),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Dias de estudo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(_weekShort[day - 1]),
                            selected: studyDays.contains(day),
                            onSelected: (selected) => setDialogState(() {
                              selected
                                  ? studyDays.add(day)
                                  : studyDays.remove(day);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Depois de criar, adicione o conteúdo no edital deste cronograma e organize as tarefas pelo calendário.',
                      style: TextStyle(color: AppTokens.muted),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(saving ? 'Criando...' : 'Criar agenda'),
              ),
            ],
          );
        },
      ),
    );
    // `showDialog` completes before Material finishes the exit animation.
    // Keep the controller alive until the dialog's TextField is unmounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    if (scheduleId == null || !mounted) return;
    ref.invalidate(allSchedulesProvider);
    context.go('/planner/$scheduleId');
  }

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.calendar_month_outlined,
    title: 'Plano de estudos',
    subtitle: 'Defina o conteúdo do edital e organize quando estudar.',
    actions: [
      OutlinedButton.icon(
        onPressed: importingTemplate ? null : _importTemplate,
        icon: importingTemplate
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_upload_outlined, size: 18),
        label: Text(importingTemplate ? 'Importando…' : 'Importar template'),
      ),
      FilledButton.icon(
        onPressed: _openCreatePlanner,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Novo cronograma'),
      ),
    ],
    child: ref
        .watch(allSchedulesProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _EmptyState(
            icon: Icons.error_outline,
            title: 'Não foi possível carregar',
            message: '$error',
            action: TextButton(
              onPressed: () => ref.invalidate(allSchedulesProvider),
              child: const Text('Tentar novamente'),
            ),
          ),
          data: (items) {
            final active = items.where((item) => !item.archived).toList();
            if (active.isEmpty) {
              return _EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Monte sua primeira agenda',
                message:
                    'Escolha os dias e a carga diária. O Planner distribui o edital e você ajusta tudo pelo calendário.',
                action: FilledButton.icon(
                  onPressed: _openCreatePlanner,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar planejamento'),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1000;
                final schedules = Column(
                  children: [
                    for (var index = 0; index < active.length; index++) ...[
                      SizedBox(
                        height: 220,
                        child: _ScheduleCard(
                          schedule: active[index],
                          onOpen: () =>
                              context.go('/planner/${active[index].id}'),
                          onSyllabus: () =>
                              context.go('/syllabus/${active[index].id}'),
                          onDuplicate: () async {
                            await ref
                                .read(scheduleRepositoryProvider)
                                .duplicate(active[index].id);
                            ref.invalidate(allSchedulesProvider);
                          },
                          onArchive: () async {
                            await ref
                                .read(scheduleRepositoryProvider)
                                .archive(active[index].id);
                            ref.invalidate(allSchedulesProvider);
                          },
                          onDelete: () => _deleteSchedule(active[index]),
                          onConfigure: () => _configurePomodoro(active[index]),
                          onExport: () => _exportTemplate(active[index]),
                        ),
                      ),
                      if (index < active.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
                final builder = _workflowPanel();
                if (compact) {
                  return Column(
                    children: [schedules, const SizedBox(height: 14), builder],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: schedules),
                    const SizedBox(width: 18),
                    Expanded(flex: 6, child: builder),
                  ],
                );
              },
            );
          },
        ),
  );

  Widget _workflowPanel() {
    return PlannerCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Como o plano funciona',
            icon: Icons.route_outlined,
          ),
          const SizedBox(height: 10),
          const Text(
            'O edital define o que estudar. O cronograma define quando estudar. O progresso só muda quando você marca um tópico ou conclui uma sessão.',
            style: TextStyle(color: AppTokens.muted),
          ),
          const SizedBox(height: 20),
          _realStep(
            number: 1,
            icon: Icons.description_outlined,
            title: 'Conteúdo do edital',
            detail: 'Cada cronograma possui seu próprio edital verticalizado.',
            actionLabel: 'Use “Editar edital” no cartão',
          ),
          const SizedBox(height: 12),
          _realStep(
            number: 2,
            icon: Icons.calendar_month_outlined,
            title: 'Cronograma',
            detail: 'Distribua o conteúdo em dias e sessões de estudo.',
            actionLabel: 'Criar cronograma',
            onPressed: _openCreatePlanner,
          ),
          const Divider(height: 34),
          const SectionTitle(
            'Reproduzir o material fornecido',
            icon: Icons.upload_file_outlined,
          ),
          const SizedBox(height: 8),
          const Text(
            'Importa as 13 disciplinas, todos os tópicos do edital e as 19 semanas do cronograma diário de 2h a 3h. Repetir a operação atualiza o plano sem duplicar tarefas.',
            style: TextStyle(color: AppTokens.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: importingMaterial ? null : _importTjspMaterial,
            icon: importingMaterial
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(
              importingMaterial ? 'Importando…' : 'Importar material TJSP 2026',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _realStep({
    required int number,
    required IconData icon,
    required String title,
    required String detail,
    required String actionLabel,
    VoidCallback? onPressed,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: AppTokens.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppTokens.lavender,
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppTokens.purple,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 25),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                detail,
                style: const TextStyle(color: AppTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (onPressed == null)
          Text(
            actionLabel,
            style: const TextStyle(color: AppTokens.muted, fontSize: 12),
          )
        else
          OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onOpen,
    required this.onSyllabus,
    required this.onDuplicate,
    required this.onArchive,
    required this.onDelete,
    required this.onConfigure,
    required this.onExport,
  });
  final StudySchedule schedule;
  final VoidCallback onOpen,
      onSyllabus,
      onDuplicate,
      onArchive,
      onDelete,
      onConfigure,
      onExport;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTokens.lavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, size: 20),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (value) {
                    if (value == 'duplicate') onDuplicate();
                    if (value == 'pomodoro') onConfigure();
                    if (value == 'archive') onArchive();
                    if (value == 'delete') onDelete();
                    if (value == 'export') onExport();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'pomodoro',
                      child: Row(
                        children: [
                          Text('🍅'),
                          SizedBox(width: 8),
                          Text('Configurar Pomodoro'),
                        ],
                      ),
                    ),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.file_download_outlined),
                          SizedBox(width: 8),
                          Text('Exportar template'),
                        ],
                      ),
                    ),
                    PopupMenuItem(value: 'archive', child: Text('Arquivar')),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 8),
                          Text('Excluir cronograma'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              schedule.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              '${_duration(schedule.dailyMinutes)} por dia  ·  ${schedule.focusMinutes}/${schedule.breakMinutes} min',
              style: const TextStyle(color: AppTokens.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Abrir calendário',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward, size: 16),
                const Spacer(),
                TextButton.icon(
                  onPressed: onSyllabus,
                  icon: const Icon(Icons.description_outlined, size: 17),
                  label: const Text('Editar edital'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppTokens.muted),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTokens.muted),
            ),
          ),
          const SizedBox(height: 18),
          action,
        ],
      ),
    ),
  );
}

const _weekShort = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0
      ? '${hours}h'
      : '${hours}h${remainder.toString().padLeft(2, '0')}';
}

String _friendlyDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
