import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog.dart';
import '../application/syllabus_providers.dart';
import '../data/syllabus_repository.dart';
import '../../projects/application/project_providers.dart';

class SyllabusPage extends ConsumerStatefulWidget {
  const SyllabusPage({required this.projectId, super.key});
  final int projectId;

  @override
  ConsumerState<SyllabusPage> createState() => _SyllabusPageState();
}

class _SyllabusPageState extends ConsumerState<SyllabusPage> {
  String query = '';

  Future<void> _selectContents(Catalog catalog, Set<String> current) async {
    final selected = {...current};
    final disciplines = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = catalog.subjects
              .where((subject) =>
                  query.trim().isEmpty ||
                  '${subject.name} ${catalog.path(subject.id)}'.toLowerCase().contains(query.trim().toLowerCase()))
              .toList();
          return AlertDialog(
            title: const Text('Adicionar conteúdos'),
            content: SizedBox(
              width: 620,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Pesquisar assuntos'),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final discipline in catalog.disciplines)
                          ExpansionTile(
                            title: Text(discipline.name),
                            children: [
                              for (final subject in filtered.where((s) => s.disciplineId == discipline.id))
                                CheckboxListTile(
                                  value: selected.contains(subject.id),
                                  contentPadding: EdgeInsets.only(left: 16.0 * _depth(catalog, subject.id)),
                                  title: Text(subject.name),
                                  subtitle: Text(catalog.path(subject.id)),
                                  onChanged: (value) => setDialogState(() {
                                    if (value == true) {
                                      selected.add(subject.id);
                                      disciplines.add(subject.disciplineId);
                                    } else {
                                      selected.remove(subject.id);
                                    }
                                  }),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar seleção')),
            ],
          );
        },
      ),
    );
    query = '';
    if (result != true || !mounted) return;
    disciplines
      ..clear()
      ..addAll(selected.map((id) => catalog.subject(id).disciplineId));
    final repository = ref.read(syllabusRepositoryProvider);
    await repository.replaceSelection(widget.projectId, disciplines, selected);
    ref.invalidate(syllabusProvider(widget.projectId));
  }

  int _depth(Catalog catalog, String id) {
    var depth = 0;
    var subject = catalog.subject(id);
    while (subject.parentId != null) {
      depth++;
      subject = catalog.subject(subject.parentId!);
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final syllabus = ref.watch(syllabusProvider(widget.projectId));
    final catalog = ref.watch(catalogProvider);
    final project = ref.watch(projectProvider(widget.projectId));
    return syllabus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Não foi possível abrir o edital: $error')),
      data: (snapshot) => catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Não foi possível carregar o catálogo: $error')),
        data: (catalog) => _content(context, snapshot, catalog, project.value?.name),
      ),
    );
  }

  Widget _content(BuildContext context, SyllabusSnapshot snapshot, Catalog catalog, String? projectName) {
    final byParent = <String?, List<SyllabusTopic>>{};
    for (final topic in snapshot.topics) {
      (byParent[topic.parentTopicId] ??= []).add(topic);
    }
    for (final items in byParent.values) items.sort((a, b) => a.position.compareTo(b.position));
    return ListView(
      padding: const EdgeInsets.all(AppTokens.large),
      children: [
        Row(
          children: [
            Expanded(child: Text(projectName == null ? 'Edital Verticalizado' : '$projectName — Edital Verticalizado', style: Theme.of(context).textTheme.headlineSmall)),
            FilledButton.icon(
              onPressed: () => _selectContents(catalog, snapshot.topics.map((t) => t.topicId).toSet()),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar disciplinas'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.medium),
        LinearProgressIndicator(value: snapshot.completion),
        const SizedBox(height: AppTokens.small),
        Text('${snapshot.completedLeaves}/${snapshot.leaves.length} assuntos concluídos — ${(snapshot.completion * 100).round()}%'),
        const SizedBox(height: AppTokens.large),
        if (snapshot.topics.isEmpty)
          const Text('Este edital está vazio. Adicione disciplinas e selecione os assuntos.'),
        for (final disciplineId in snapshot.disciplineIds)
          _disciplineSection(disciplineId, snapshot, byParent, catalog),
      ],
    );
  }

  Widget _disciplineSection(String disciplineId, SyllabusSnapshot snapshot,
      Map<String?, List<SyllabusTopic>> byParent, Catalog catalog) {
    final discipline = catalog.discipline(disciplineId);
    Widget tree(String? parent) => Column(
          children: [
            for (final topic in byParent[parent] ?? const <SyllabusTopic>[])
              ExpansionTile(
                title: Text(topic.name),
                leading: Checkbox(
                  value: topic.completed,
                  onChanged: (value) async {
                    try {
                      await ref.read(syllabusRepositoryProvider).toggleTopic(widget.projectId, topic.topicId, value == true);
                      ref.invalidate(syllabusProvider(widget.projectId));
                    } catch (error) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  },
                ),
                children: [tree(topic.topicId)],
              ),
          ],
        );
    return Card(
      child: ExpansionTile(title: Text(discipline.name), children: [tree(null)]),
    );
  }
}
