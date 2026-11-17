import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog.dart';
import '../application/syllabus_providers.dart';
import '../data/syllabus_repository.dart';
import '../../schedules/application/schedule_providers.dart';

class SyllabusPage extends ConsumerStatefulWidget {
  const SyllabusPage({required this.scheduleId, super.key});
  final int scheduleId;

  @override
  ConsumerState<SyllabusPage> createState() => _SyllabusPageState();
}

class _SyllabusPageState extends ConsumerState<SyllabusPage> {
  String query = '';
  String? selectedDisciplineId;
  String? selectedTopicId;
  String filter = 'all';

  Future<void> _selectContents(Catalog catalog, Set<String> current) async {
    final selected = {...current};
    final disciplines = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = catalog.subjects
              .where(
                (subject) =>
                    query.trim().isEmpty ||
                    '${subject.name} ${catalog.path(subject.id)}'
                        .toLowerCase()
                        .contains(query.trim().toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('Adicionar conteúdos'),
            content: SizedBox(
              width: 620,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Pesquisar assuntos',
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final discipline in catalog.disciplines)
                          ExpansionTile(
                            title: Text(discipline.name),
                            children: [
                              for (final subject in filtered.where(
                                (s) => s.disciplineId == discipline.id,
                              ))
                                CheckboxListTile(
                                  value: selected.contains(subject.id),
                                  contentPadding: EdgeInsets.only(
                                    left: 16.0 * _depth(catalog, subject.id),
                                  ),
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar seleção'),
              ),
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
    await repository.replaceSelection(widget.scheduleId, disciplines, selected);
    ref.invalidate(syllabusProvider(widget.scheduleId));
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
    final syllabus = ref.watch(syllabusProvider(widget.scheduleId));
    final catalog = ref.watch(catalogProvider);
    final schedule = ref.watch(scheduleProvider(widget.scheduleId));
    return syllabus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Não foi possível abrir o edital: $error')),
      data: (snapshot) => catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Não foi possível carregar o catálogo: $error')),
        data: (catalog) =>
            _content(context, snapshot, catalog, schedule.value?.name),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    SyllabusSnapshot snapshot,
    Catalog catalog,
    String? scheduleName,
  ) {
    final byParent = <String?, List<SyllabusTopic>>{};
    for (final topic in snapshot.topics) {
      (byParent[topic.parentTopicId] ??= []).add(topic);
    }
    for (final items in byParent.values) {
      items.sort((a, b) => a.position.compareTo(b.position));
    }
    final disciplineId = snapshot.disciplineIds.contains(selectedDisciplineId)
        ? selectedDisciplineId
        : snapshot.disciplineIds.firstOrNull;
    final disciplineTopics = snapshot.topics
        .where((topic) => topic.disciplineId == disciplineId)
        .toList();
    final selectedTopic = disciplineTopics
        .where((topic) => topic.topicId == selectedTopicId)
        .firstOrNull;
    return PlannerPageFrame(
      icon: Icons.description_outlined,
      title: 'Edital verticalizado',
      subtitle: scheduleName == null
          ? 'Transforme o edital em uma lista de estudos acompanhável.'
          : '$scheduleName · acompanhe cada assunto do edital.',
      actions: [
        FilledButton.icon(
          onPressed: () => _selectContents(
            catalog,
            snapshot.topics.map((topic) => topic.topicId).toSet(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar disciplinas'),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final cards = [
                MetricCard(
                  icon: Icons.layers_outlined,
                  label: 'Cobertura',
                  value: '${(snapshot.completion * 100).round()}%',
                  progress: snapshot.completion,
                  onTap: () => setState(() => filter = 'all'),
                ),
                MetricCard(
                  icon: Icons.check_box_outlined,
                  label: 'Assuntos estudados',
                  value:
                      '${snapshot.completedLeaves} / ${snapshot.leaves.length}',
                  onTap: () => setState(() => filter = 'studied'),
                ),
                MetricCard(
                  icon: Icons.pending_actions_outlined,
                  label: 'Assuntos pendentes',
                  value:
                      '${snapshot.leaves.where((topic) => !topic.completed).length}',
                  onTap: () => setState(() => filter = 'pending'),
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index < cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (snapshot.topics.isEmpty)
            PlannerCard(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined, size: 46),
                    const SizedBox(height: 12),
                    const Text(
                      'Este edital ainda está vazio.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Adicione disciplinas e escolha os assuntos que fazem parte do concurso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTokens.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _selectContents(catalog, const {}),
                      icon: const Icon(Icons.add),
                      label: const Text('Montar edital'),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final disciplines = _disciplinesPanel(
                  snapshot,
                  catalog,
                  disciplineId,
                );
                final tree = _topicsPanel(
                  snapshot,
                  byParent,
                  catalog,
                  disciplineId,
                );
                final details = _detailsPanel(selectedTopic);
                if (compact) {
                  return Column(
                    children: [
                      disciplines,
                      const SizedBox(height: 12),
                      tree,
                      const SizedBox(height: 12),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 280, child: disciplines),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: tree),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: details),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _disciplinesPanel(
    SyllabusSnapshot snapshot,
    Catalog catalog,
    String? selectedId,
  ) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Disciplinas do edital',
          icon: Icons.layers_outlined,
        ),
        const SizedBox(height: 12),
        for (final entry in snapshot.disciplineIds.indexed)
          Builder(
            builder: (context) {
              final id = entry.$2;
              final leaves = snapshot.leaves
                  .where((topic) => topic.disciplineId == id)
                  .toList();
              final completed = leaves.where((topic) => topic.completed).length;
              final progress = leaves.isEmpty ? 0.0 : completed / leaves.length;
              final selected = id == selectedId;
              return InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() {
                  selectedDisciplineId = id;
                  selectedTopicId = null;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTokens.blueSoft : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color:
                              disciplinePalette[entry.$1 %
                                  disciplinePalette.length],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          catalog.discipline(id).name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 58, child: MiniProgress(value: progress)),
                      const SizedBox(width: 7),
                      Text('${(progress * 100).round()}%'),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );

  Widget _topicsPanel(
    SyllabusSnapshot snapshot,
    Map<String?, List<SyllabusTopic>> byParent,
    Catalog catalog,
    String? disciplineId,
  ) {
    final discipline = disciplineId == null
        ? null
        : catalog.discipline(disciplineId);
    final roots = snapshot.topics
        .where(
          (topic) =>
              topic.disciplineId == disciplineId &&
              (topic.parentTopicId == null ||
                  !snapshot.topics.any(
                    (candidate) => candidate.topicId == topic.parentTopicId,
                  )),
        )
        .toList();
    Widget node(SyllabusTopic topic, int depth) {
      final children = (byParent[topic.topicId] ?? const <SyllabusTopic>[])
          .where((child) => child.disciplineId == disciplineId)
          .toList();
      if (filter == 'studied' && !topic.completed && children.isEmpty) {
        return const SizedBox.shrink();
      }
      if (filter == 'pending' && topic.completed && children.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.only(left: depth * 12.0),
        child: children.isEmpty
            ? InkWell(
                onTap: () => setState(() => selectedTopicId = topic.topicId),
                child: CheckboxListTile(
                  dense: true,
                  value: topic.completed,
                  onChanged: (value) => _toggleTopic(topic, value == true),
                  title: Row(
                    children: [
                      Expanded(child: Text(topic.name)),
                      _topicStatus(topic),
                    ],
                  ),
                ),
              )
            : ExpansionTile(
                initiallyExpanded: depth < 2,
                title: Text(
                  topic.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: Text(
                  '${children.where((child) => child.completed).length}/${children.length}',
                ),
                children: [
                  for (final child in children) node(child, depth + 1),
                ],
              ),
      );
    }

    return PlannerCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SectionTitle(
              discipline?.name ?? 'Assuntos',
              icon: Icons.menu_book_outlined,
              trailing: Text(
                '${snapshot.completedLeaves}/${snapshot.leaves.length} (${(snapshot.completion * 100).round()}%)',
              ),
            ),
          ),
          const Divider(height: 22),
          if (roots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nenhum assunto nesta disciplina.'),
            ),
          for (final root in roots) node(root, 0),
        ],
      ),
    );
  }

  Widget _topicStatus(SyllabusTopic topic) {
    final label = topic.completed ? 'Estudado' : 'Pendente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: topic.completed ? AppTokens.greenSoft : AppTokens.hover,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: topic.completed ? AppTokens.green : AppTokens.muted,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _toggleTopic(SyllabusTopic topic, bool completed) async {
    try {
      await ref
          .read(syllabusRepositoryProvider)
          .toggleTopic(widget.scheduleId, topic.topicId, completed);
      ref.invalidate(syllabusProvider(widget.scheduleId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _detailsPanel(SyllabusTopic? topic) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Detalhes do assunto',
          icon: Icons.description_outlined,
        ),
        const Divider(height: 24),
        Text(
          topic?.name ?? 'Selecione um assunto',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          topic == null
              ? 'Clique em um assunto da lista para acompanhar seu progresso.'
              : topic.completed
              ? 'Este assunto está marcado como estudado.'
              : 'Este assunto ainda está pendente.',
          style: const TextStyle(color: AppTokens.muted),
        ),
        const Divider(height: 28),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: topic?.completed ?? false,
          onChanged: topic == null
              ? null
              : (value) => _toggleTopic(topic, value == true),
          title: const Text('Tema estudado'),
          subtitle: const Text('A alteração é salva imediatamente.'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.go('/planner/${widget.scheduleId}'),
          icon: const Icon(Icons.calendar_today_outlined),
          label: const Text('Abrir plano de estudos'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    ),
  );
}
