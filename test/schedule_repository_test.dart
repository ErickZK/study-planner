import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_repository.dart';
import 'package:study_planner/features/planner/data/planner_repository.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/syllabus/data/syllabus_repository.dart';

void main() {
  late AppDatabase database;
  late ProjectRepository projects;
  late ScheduleRepository schedules;
  late PlannerRepository planner;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.initialize();
    projects = ProjectRepository(database);
    schedules = ScheduleRepository(database);
    planner = PlannerRepository(database);
  });
  tearDown(() => database.close());

  test('isola cronogramas e distribui tempo por assuntos', () async {
    await projects.create('MVP');
    final project = (await projects.list()).single;
    final first = await schedules.create(
      project.id,
      'Manhã',
      dailyMinutes: 180,
    );
    final second = await schedules.create(project.id, 'Noite');
    final activity = await planner.create(
      first,
      '2026-11-12',
      'Bloco',
      topicIds: const ['a', 'b', 'c'],
    );
    expect((await planner.list(first, '2026-11-12')).single.plannedMinutes, 60);
    expect((await planner.list(second, '2026-11-12')), isEmpty);
    await planner.setStatus(activity, 'done');
    expect((await planner.list(first, '2026-11-12')).single.status, 'done');
    final session = await planner.startSession(activity);
    await expectLater(
      planner.startSession(activity),
      throwsA(isA<StateError>()),
    );
    await planner.finishSession(session, 90, questions: 10, correct: 8);
    expect(
      () => planner.createManualSession(activity, '2999-01-01', 60),
      throwsA(isA<ArgumentError>()),
    );
    final metrics = await planner.performance();
    expect(metrics.seconds, 90);
    expect(metrics.accuracy, 0.8);
  });

  test('duplica e arquiva cronograma sem misturar atividades', () async {
    await projects.create('MVP');
    final project = (await projects.list()).single;
    final id = await schedules.create(project.id, 'Original');
    await schedules.update(
      id,
      focusMinutes: 40,
      breakMinutes: 10,
      longBreakMinutes: 20,
      roundsPerLongBreak: 3,
    );
    final copy = await schedules.duplicate(id);
    expect(
      (await schedules.list(project.id)).map((item) => item.id),
      containsAll([id, copy]),
    );
    final copied = await schedules.get(copy);
    expect(copied.focusMinutes, 40);
    expect(copied.breakMinutes, 10);
    expect(copied.longBreakMinutes, 20);
    expect(copied.roundsPerLongBreak, 3);
    await schedules.archive(id);
    expect(
      (await schedules.list(
        project.id,
      )).firstWhere((item) => item.id == id).archived,
      isTrue,
    );
  });

  test('excluir projeto remove cronogramas e tarefas em cascata', () async {
    await projects.create('Descartável');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Agenda');
    await planner.create(schedule, '2026-11-14', 'Tarefa');

    await projects.delete(project.id);

    expect(await projects.list(), isEmpty);
    expect(await schedules.list(project.id), isEmpty);
    final activities = await database
        .customSelect('SELECT COUNT(*) AS total FROM activities')
        .getSingle();
    expect(activities.read<int>('total'), 0);
  });

  test('cria agenda vazia quando o usuário não escolhe conteúdo', () async {
    await projects.create('Plano manual');
    final project = (await projects.list()).single;
    final id = await schedules.createStudyPlan(
      projectId: project.id,
      name: 'Pós-edital',
      startDate: DateTime(2026, 11, 9),
      dailyMinutes: 150,
      studyDays: const {1, 2, 3, 4, 5, 6},
      useSelectedSyllabus: false,
    );

    final week = await planner.listRange(id, '2026-11-09', '2026-11-15');
    expect(week, isEmpty);
  });

  test('mantém o tempo de sessão em execução como fonte persistente', () async {
    await projects.create('TJSP');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Plano');
    final activity = await planner.create(schedule, '2026-11-13', 'Português');
    final session = await planner.startSession(activity);
    final fiveSecondsAgo = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;
    await database.customStatement(
      'UPDATE study_sessions SET accumulated_seconds=3,started_at=? WHERE id=?',
      [fiveSecondsAgo, session],
    );

    final running = (await planner.sessions(activity)).single;
    expect(running.status, 'running');
    expect(running.seconds, inInclusiveRange(8, 9));
    expect(running.accumulatedSeconds, 3);
  });

  test('agrega dados reais para os gráficos de estatísticas', () async {
    await projects.create('TJSP');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Plano');
    final activity = await planner.create(
      schedule,
      '2026-11-16',
      'Direito Administrativo',
    );
    await planner.setStatus(activity, 'done');
    await planner.createManualSession(
      activity,
      '2026-11-16',
      3600,
      questions: 20,
      correct: 15,
    );

    final analytics = await planner.analytics(
      from: DateTime(2026, 11, 15),
      to: DateTime(2026, 11, 17),
    );

    expect(analytics.daily, hasLength(3));
    expect(analytics.seconds, 3600);
    expect(analytics.questions, 20);
    expect(analytics.accuracy, .75);
    expect(analytics.completedTasks, 1);
    expect(analytics.plannedTasks, 1);
    expect(analytics.disciplines.single.name, 'Sem disciplina');
  });

  test(
    'persiste a pausa do pomodoro sem contar descanso como estudo',
    () async {
      await projects.create('TJSP');
      final project = (await projects.list()).single;
      final schedule = await schedules.create(project.id, 'Pomodoro');
      final activity = await planner.create(
        schedule,
        '2026-11-14',
        'Direito Administrativo',
      );
      final session = await planner.startSession(activity);

      await planner.startPomodoroBreak(session, 25 * 60);
      final resting = (await planner.sessions(activity)).single;
      expect(resting.status, 'break');
      expect(resting.seconds, 25 * 60);
      expect(resting.accumulatedSeconds, 25 * 60);
      expect(resting.startedAt, isNotNull);
      await expectLater(
        planner.startSession(activity),
        throwsA(isA<StateError>()),
      );

      await planner.resumeSession(session);
      final focused = (await planner.sessions(activity)).single;
      expect(focused.status, 'running');
      expect(focused.seconds, inInclusiveRange(25 * 60, (25 * 60) + 1));
    },
  );

  test('concluir atividade marca os assuntos escolhidos no edital', () async {
    await projects.create('TJSP');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Plano TJSP');
    final catalog = CatalogRepository(database);
    final discipline = await catalog.createDiscipline('Direito Administrativo');
    final firstTopic = await catalog.createSubject(
      discipline,
      'Atos administrativos',
    );
    final secondTopic = await catalog.createSubject(
      discipline,
      'Poderes administrativos',
    );
    await SyllabusRepository(
      database,
    ).replaceSelection(schedule, {discipline}, {firstTopic, secondTopic});
    final activity = await planner.create(
      schedule,
      '2026-11-17',
      'Direito Administrativo — Módulo 01',
    );
    final options = await planner.completionTopics(activity);
    expect(options.topics, hasLength(2));
    expect(options.suggestedDisciplineIds, {discipline});

    await planner.completeActivityWithTopics(
      activity,
      {firstTopic},
      reviewTopicIds: {firstTopic},
    );

    final snapshot = await SyllabusRepository(
      database,
    ).loadForSchedule(schedule);
    expect(
      snapshot.topics
          .firstWhere((topic) => topic.topicId == firstTopic)
          .completed,
      isTrue,
    );
    expect(
      snapshot.topics
          .firstWhere((topic) => topic.topicId == secondTopic)
          .completed,
      isFalse,
    );
    expect((await planner.findActivity(activity))!.status, 'done');
    final reviews = await database
        .customSelect(
          "SELECT topic_id,due_date FROM topic_reviews WHERE status='pending'",
        )
        .get();
    expect(reviews.single.read<String>('topic_id'), firstTopic);
    expect(reviews.single.read<String>('due_date'), isNotEmpty);
  });

  test('finalizar sessão não conclui a atividade', () async {
    await projects.create('TJSP');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Plano TJSP');
    final activity = await planner.create(
      schedule,
      '2026-11-17',
      'Direito Administrativo',
    );
    final session = await planner.startSession(activity);

    await planner.finishSession(session, 1500);

    expect((await planner.findActivity(activity))!.status, 'pending');
  });

  test('persiste materiais, anotações e histórico de gabaritos', () async {
    await projects.create('TJSP');
    final project = (await projects.list()).single;
    final schedule = await schedules.create(project.id, 'Plano TJSP');
    final activity = await planner.create(
      schedule,
      '2026-11-17',
      'Direito Administrativo',
    );
    final session = await planner.startSession(activity);

    final material = await planner.addMaterial(
      activity,
      kind: 'link',
      title: 'Aula de atos administrativos',
      location: 'https://example.com/aula',
    );
    await planner.setMaterialUsed(material, true);
    await planner.saveActivityNotes(activity, 'Resumo da atividade');
    await planner.saveQuestionAttempt(activity, const [
      QuestionAnswerDraft(number: 1, answer: 'A', isCorrect: true),
      QuestionAnswerDraft(number: 2, answer: 'C', isCorrect: false),
    ], studySessionId: session);

    expect((await planner.materials(activity)).single.isUsed, isTrue);
    expect(await planner.activityNotes(activity), 'Resumo da atividade');
    final attempts = await planner.questionAttempts(activity);
    expect(attempts.single.answers, hasLength(2));
    expect(attempts.single.correct, 1);
    final recordedSession = (await planner.sessions(activity)).single;
    expect(recordedSession.questions, 2);
    expect(recordedSession.correct, 1);
  });
}
