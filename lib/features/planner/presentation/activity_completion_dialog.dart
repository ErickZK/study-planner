import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../syllabus/application/syllabus_providers.dart';
import '../application/planner_providers.dart';
import '../data/planner_repository.dart';

class ActivityCompletionSelection {
  const ActivityCompletionSelection({
    required this.studiedTopicIds,
    required this.reviewTopicIds,
  });

  final Set<String> studiedTopicIds;
  final Set<String> reviewTopicIds;
}

Future<ActivityCompletionSelection?> showActivityCompletionDialog(
  BuildContext context,
  WidgetRef ref,
  PlannedActivity activity,
) async {
  final repository = ref.read(plannerRepositoryProvider);
  CompletionTopicSelection review;
  try {
    review = await repository.completionTopics(activity.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
    return null;
  }
  if (!context.mounted) return null;

  final selected = review.topics
      .where((topic) => topic.linkedToActivity)
      .map((topic) => topic.id)
      .toSet();
  final markedForReview = <String>{};
  final disciplineNames = <String, String>{
    for (final topic in review.topics) topic.disciplineId: topic.disciplineName,
  };
  String? selectedDiscipline = review.suggestedDisciplineIds.isEmpty
      ? null
      : review.suggestedDisciplineIds.first;
  selectedDiscipline ??= disciplineNames.keys.isEmpty
      ? null
      : disciplineNames.keys.first;
  var query = '';

  return showDialog<ActivityCompletionSelection>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final visibleTopics = review.topics.where((topic) {
          if (topic.disciplineId != selectedDiscipline) return false;
          final search = query.trim().toLowerCase();
          return search.isEmpty || topic.name.toLowerCase().contains(search);
        }).toList();
        final hasTopics = review.topics.isNotEmpty;
        return AlertDialog(
          title: const Text('Quais assuntos foram estudados?'),
          content: SizedBox(
            width: 700,
            height: hasTopics ? 540 : 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.activityTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                if (!hasTopics)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'O cronograma ainda não possui um edital verticalizado com assuntos. Você pode concluir a atividade sem atualizar o edital.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTokens.muted),
                      ),
                    ),
                  )
                else ...[
                  if (disciplineNames.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: selectedDiscipline,
                      decoration: const InputDecoration(
                        labelText: 'Disciplina da atividade',
                      ),
                      items: [
                        for (final entry in disciplineNames.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => selectedDiscipline = value),
                    ),
                  if (disciplineNames.length > 1) const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Pesquisar assunto',
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${selected.length} selecionado(s)'),
                      const Spacer(),
                      TextButton(
                        onPressed: visibleTopics.isEmpty
                            ? null
                            : () => setDialogState(() {
                                final visibleIds = visibleTopics
                                    .map((topic) => topic.id)
                                    .toSet();
                                if (visibleIds.every(selected.contains)) {
                                  selected.removeAll(visibleIds);
                                  markedForReview.removeAll(visibleIds);
                                } else {
                                  selected.addAll(visibleIds);
                                }
                              }),
                        child: const Text('Selecionar visíveis'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 7, 4, 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('Assunto')),
                        SizedBox(
                          width: 76,
                          child: Text('Estudado', textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 76,
                          child: Text('Revisar', textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleTopics.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum assunto encontrado nesta disciplina.',
                              style: TextStyle(color: AppTokens.muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibleTopics.length,
                            itemBuilder: (context, index) {
                              final topic = visibleTopics[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(topic.name),
                                subtitle: topic.completed
                                    ? const Text('Já marcado como estudado')
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 76,
                                      child: Checkbox(
                                        value: selected.contains(topic.id),
                                        onChanged: (checked) => setDialogState(
                                          () {
                                            if (checked == true) {
                                              selected.add(topic.id);
                                            } else {
                                              selected.remove(topic.id);
                                              markedForReview.remove(topic.id);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 76,
                                      child: Checkbox(
                                        value: markedForReview.contains(
                                          topic.id,
                                        ),
                                        activeColor: AppTokens.blue,
                                        checkColor: Colors.white,
                                        side: const BorderSide(
                                          color: AppTokens.blue,
                                          width: 1.6,
                                        ),
                                        overlayColor:
                                            const WidgetStatePropertyAll(
                                              AppTokens.blueSoft,
                                            ),
                                        onChanged: (checked) => setDialogState(
                                          () {
                                            if (checked == true) {
                                              selected.add(topic.id);
                                              markedForReview.add(topic.id);
                                            } else {
                                              markedForReview.remove(topic.id);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
              onPressed: hasTopics && selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      ActivityCompletionSelection(
                        studiedTopicIds: {...selected},
                        reviewTopicIds: {...markedForReview},
                      ),
                    ),
              icon: const Icon(Icons.check),
              label: Text(
                hasTopics ? 'Concluir atividade' : 'Concluir sem assunto',
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<bool> completeActivityWithReview(
  BuildContext context,
  WidgetRef ref,
  PlannedActivity activity,
) async {
  final selection = await showActivityCompletionDialog(context, ref, activity);
  if (selection == null || !context.mounted) return false;

  try {
    await ref
        .read(plannerRepositoryProvider)
        .completeActivityWithTopics(
          activity.id,
          selection.studiedTopicIds,
          reviewTopicIds: selection.reviewTopicIds,
        );
    ref.invalidate(
      activitiesProvider((
        scheduleId: activity.scheduleId,
        date: activity.date,
      )),
    );
    ref.invalidate(syllabusProvider(activity.scheduleId));
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}
