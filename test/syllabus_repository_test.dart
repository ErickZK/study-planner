import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/syllabus/data/syllabus_repository.dart';

void main() {
  late AppDatabase database;
  late ProjectRepository projects;
  late CatalogRepository catalog;
  late SyllabusRepository syllabus;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.initialize();
    projects = ProjectRepository(database);
    catalog = CatalogRepository(database);
    syllabus = SyllabusRepository(database);
  });
  tearDown(() => database.close());

  test('cria um edital único e seleciona conteúdos parcialmente', () async {
    await projects.create('Projeto A');
    final project = (await projects.list()).single;
    final discipline = await catalog.createDiscipline('Português');
    final root = await catalog.createSubject(discipline, 'Gramática');
    final child = await catalog.createSubject(discipline, 'Sintaxe', parentId: root);

    final firstSyllabus = await syllabus.ensureForProject(project.id);
    final secondSyllabus = await syllabus.ensureForProject(project.id);
    expect(secondSyllabus, firstSyllabus);
    await syllabus.replaceSelection(project.id, {discipline}, {root, child});

    final snapshot = await syllabus.loadForProject(project.id);
    expect(snapshot.disciplineIds, {discipline});
    expect(snapshot.topics.map((item) => item.topicId), containsAll([root, child]));
    expect(snapshot.leaves, hasLength(1));
  });

  test('compartilha progresso global entre projetos', () async {
    await projects.create('A');
    await projects.create('B');
    final items = await projects.list();
    final discipline = await catalog.createDiscipline('Direito');
    final topic = await catalog.createSubject(discipline, 'Princípios');
    for (final project in items) {
      await syllabus.replaceSelection(project.id, {discipline}, {topic});
    }

    await syllabus.toggleTopic(items.first.id, topic, true);
    expect((await syllabus.loadForProject(items.last.id)).completion, 1);
  });

  test('copy-on-write isola edição e progresso', () async {
    await projects.create('A');
    await projects.create('B');
    final items = await projects.list();
    final discipline = await catalog.createDiscipline('Informática');
    final topic = await catalog.createSubject(discipline, 'Redes');
    for (final project in items) {
      await syllabus.replaceSelection(project.id, {discipline}, {topic});
    }
    await syllabus.toggleTopic(items.first.id, topic, true);
    final copyId = await syllabus.copyOnWrite(items.first.id, topic, 'Redes avançadas');
    expect(copyId, isNot(topic));
    final first = await syllabus.loadForProject(items.first.id);
    final second = await syllabus.loadForProject(items.last.id);
    expect(first.topics.single.name, 'Redes avançadas');
    expect(first.topics.single.completed, isTrue);
    expect(second.topics.single.name, 'Redes');
    expect(second.topics.single.completed, isTrue);
    await syllabus.toggleTopic(items.first.id, copyId, false);
    expect((await syllabus.loadForProject(items.last.id)).completion, 1);
    expect((await syllabus.loadForProject(items.first.id)).completion, 0);
  });

  test('falha na seleção não remove o estado anterior', () async {
    await projects.create('Projeto');
    final project = (await projects.list()).single;
    final discipline = await catalog.createDiscipline('Matemática');
    final topic = await catalog.createSubject(discipline, 'Frações');
    await syllabus.replaceSelection(project.id, {discipline}, {topic});
    expect(
      () => syllabus.replaceSelection(project.id, {discipline}, {'inexistente'}),
      throwsA(isA<CatalogException>()),
    );
    expect((await syllabus.loadForProject(project.id)).topics.single.topicId, topic);
  });
}
