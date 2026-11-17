import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/planner/data/planner_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_template_repository.dart';
import 'package:study_planner/features/syllabus/data/syllabus_repository.dart';

void main() {
  test('exporta e importa somente a estrutura reutilizável do plano', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.initialize();
    final schedules = ScheduleRepository(database);
    final planner = PlannerRepository(database);
    final catalog = CatalogRepository(database);
    final templates = ScheduleTemplateRepository(database);
    final owner = await schedules.ensureOwner();
    final schedule = await schedules.create(
      owner,
      'TJSP 2026',
      dailyMinutes: 150,
      focusMinutes: 30,
    );
    final discipline = await catalog.createDiscipline('Direito Administrativo');
    final parent = await catalog.createSubject(
      discipline,
      'Atos administrativos',
    );
    final topic = await catalog.createSubject(
      discipline,
      'Conceito e atributos',
      parentId: parent,
    );
    await SyllabusRepository(
      database,
    ).replaceSelection(schedule, {discipline}, {parent, topic});
    final activity = await planner.create(
      schedule,
      '2026-11-18',
      'Estudar atos administrativos',
      topicIds: [topic],
    );
    await planner.create(
      schedule,
      '2026-11-21',
      'Revisar atos administrativos',
      topicIds: [topic],
    );
    final session = await planner.startSession(activity);
    await planner.finishSession(
      session,
      1800,
      questions: 10,
      correct: 8,
      notes: 'observação privada do aluno',
    );
    await planner.saveActivityNotes(activity, 'anotação privada do aluno');
    await planner.addMaterial(
      activity,
      kind: 'link',
      title: 'link particular',
      location: 'https://example.com/token-privado',
    );
    await planner.saveQuestionAttempt(activity, const [
      QuestionAnswerDraft(number: 1, answer: 'A', isCorrect: true),
    ]);
    await planner.completeActivityWithTopics(
      activity,
      {topic},
      reviewTopicIds: {topic},
    );

    final exported = await templates.exportTemplate(schedule);

    expect(exported, contains('tjsp-planner-template'));
    expect(exported, contains('Conceito e atributos'));
    expect(exported, isNot(contains('privada do aluno')));
    expect(exported, isNot(contains('token-privado')));
    expect(exported, isNot(contains('questionAnswers')));
    expect(exported, isNot(contains('topicProgress')));

    final imported = await templates.importTemplate(
      exported,
      startDate: DateTime(2027, 1, 11),
      restDays: const {DateTime.sunday, DateTime.thursday},
    );
    final copy = await schedules.get(imported.scheduleId);
    expect(copy.name, 'TJSP 2026 (importado)');
    expect(copy.dailyMinutes, 150);
    expect(copy.focusMinutes, 30);
    final copiedActivities = await planner.list(
      imported.scheduleId,
      '2027-01-11',
    );
    expect(copiedActivities.single.status, 'pending');
    expect(copiedActivities.single.topicIds, hasLength(1));
    final laterActivities = await planner.list(
      imported.scheduleId,
      '2027-01-15',
    );
    expect(laterActivities.single.title, 'Revisar atos administrativos');
    final copiedSyllabus = await SyllabusRepository(
      database,
    ).loadForSchedule(imported.scheduleId);
    expect(copiedSyllabus.topics, hasLength(2));
    expect(copiedSyllabus.completedLeaves, 0);
    for (final table in [
      'study_sessions',
      'study_materials',
      'activity_notes',
      'question_attempts',
      'topic_reviews',
    ]) {
      final count = await database
          .customSelect(
            '''SELECT COUNT(*) AS total FROM $table row
               JOIN activities activity ON activity.id=row.activity_id
               WHERE activity.schedule_id=?''',
            variables: [Variable(imported.scheduleId)],
          )
          .getSingle();
      expect(count.read<int>('total'), 0, reason: table);
    }
  });
}
