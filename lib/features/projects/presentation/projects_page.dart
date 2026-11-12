import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/project_providers.dart';
import '../data/project_repository.dart';
import '../../../app/theme/app_theme.dart';

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
    } catch (_) {
      if (mounted) {
        setState(() => failure = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppTokens.large),
    children: [
      const Text('Criar projeto vazio'),
      const Text(
        'Nesta fase, apenas o nome é cadastrado. Edital e cronogramas virão depois.',
      ),
      const SizedBox(height: AppTokens.medium),
      Form(
        key: form,
        child: TextFormField(
          controller: name,
          validator: (v) => ProjectRepository.validateName(v ?? ''),
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Nome do projeto'),
          onFieldSubmitted: (_) => save(),
        ),
      ),
      const SizedBox(height: AppTokens.medium),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Salvando…' : 'Salvar projeto'),
        ),
      ),
      if (failure != null) Text(failure!),
      const Divider(),
      ref
          .watch(projectsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => TextButton(
              onPressed: () => ref.invalidate(projectsProvider),
              child: const Text('Recarregar projetos'),
            ),
            data: (items) => Column(
              children: [
                if (items.isEmpty) const Text('Nenhum projeto por enquanto.'),
                for (final p in items) ListTile(title: Text(p.name)),
              ],
            ),
          ),
    ],
  );
}
