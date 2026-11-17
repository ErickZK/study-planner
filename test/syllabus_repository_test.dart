import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/catalog/domain/catalog.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_repository.dart';
import 'package:study_planner/features/syllabus/data/syllabus_repository.dart';

void main() {
  late AppDatabase database;
  late ProjectRepository projects;
  late CatalogRepository catalog;
  late SyllabusRepository syllabus;
  late ScheduleRepository schedules;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.initialize();
    projects = ProjectRepository(database);
    catalog = CatalogRepository(database);
    syllabus = SyllabusRepository(database);
    schedules = ScheduleRepository(database);
  });
  tearDown(() => database.close());

  test('cria um edital único e seleciona conteúdos parcialmente', () async {
    await projects.create('Projeto A');
    final project = (await projects.list()).single;
    final scheduleId = await schedules.create(project.id, 'Plano A');
    final discipline = await catalog.createDiscipline('Português');
    final root = await catalog.createSubject(discipline, 'Gramática');
    final child = await catalog.createSubject(
      discipline,
      'Sintaxe',
      parentId: root,
    );

    final firstSyllabus = await syllabus.ensureForSchedule(scheduleId);
    final secondSyllabus = await syllabus.ensureForSchedule(scheduleId);
    expect(secondSyllabus, firstSyllabus);
    await syllabus.replaceSelection(scheduleId, {discipline}, {root, child});

    final snapshot = await syllabus.loadForSchedule(scheduleId);
    expect(snapshot.disciplineIds, {discipline});
    expect(
      snapshot.topics.map((item) => item.topicId),
      containsAll([root, child]),
    );
    expect(snapshot.leaves, hasLength(1));
  });

  test('isola o progresso entre cronogramas', () async {
    await projects.create('A');
    await projects.create('B');
    final items = await projects.list();
    final scheduleIds = <int>[];
    final discipline = await catalog.createDiscipline('Direito');
    final topic = await catalog.createSubject(discipline, 'Princípios');
    for (final project in items) {
      final id = await schedules.create(project.id, 'Plano ${project.id}');
      scheduleIds.add(id);
      await syllabus.replaceSelection(id, {discipline}, {topic});
    }

    await syllabus.toggleTopic(scheduleIds.first, topic, true);
    expect((await syllabus.loadForSchedule(scheduleIds.last)).completion, 0);
  });

  test('copy-on-write isola edição e progresso', () async {
    await projects.create('A');
    await projects.create('B');
    final items = await projects.list();
    final scheduleIds = <int>[];
    final discipline = await catalog.createDiscipline('Informática');
    final topic = await catalog.createSubject(discipline, 'Redes');
    for (final project in items) {
      final id = await schedules.create(project.id, 'Plano ${project.id}');
      scheduleIds.add(id);
      await syllabus.replaceSelection(id, {discipline}, {topic});
    }
    await syllabus.toggleTopic(scheduleIds.first, topic, true);
    final copyId = await syllabus.copyOnWrite(
      scheduleIds.first,
      topic,
      'Redes avançadas',
    );
    expect(copyId, isNot(topic));
    final first = await syllabus.loadForSchedule(scheduleIds.first);
    final second = await syllabus.loadForSchedule(scheduleIds.last);
    expect(first.topics.single.name, 'Redes avançadas');
    expect(first.topics.single.completed, isTrue);
    expect(second.topics.single.name, 'Redes');
    expect(second.topics.single.completed, isFalse);
    await syllabus.toggleTopic(scheduleIds.first, copyId, false);
    expect((await syllabus.loadForSchedule(scheduleIds.last)).completion, 0);
    expect((await syllabus.loadForSchedule(scheduleIds.first)).completion, 0);
  });

  test('falha na seleção não remove o estado anterior', () async {
    await projects.create('Projeto');
    final project = (await projects.list()).single;
    final scheduleId = await schedules.create(project.id, 'Plano');
    final discipline = await catalog.createDiscipline('Matemática');
    final topic = await catalog.createSubject(discipline, 'Frações');
    await syllabus.replaceSelection(scheduleId, {discipline}, {topic});
    expect(
      () =>
          syllabus.replaceSelection(scheduleId, {discipline}, {'inexistente'}),
      throwsA(isA<CatalogException>()),
    );
    expect(
      (await syllabus.loadForSchedule(scheduleId)).topics.single.topicId,
      topic,
    );
  });
}
