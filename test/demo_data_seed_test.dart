import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/core/database/seeds/demo_data_seed.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.initialize();
  });

  tearDown(() => database.close());

  test('carrega a quantidade esperada e é idempotente', () async {
    final seed = DemoDataSeed(database);
    final first = await seed.load();
    final second = await seed.load();

    expect(first.disciplines, 6);
    expect(first.subjects, greaterThan(40));
    expect(second.subjects, first.subjects);
    expect(await _count(database, 'disciplines'), 6);
    expect(await _count(database, 'subjects'), first.subjects);
  });

  test('preserva hierarquia profunda e remove somente dados demonstrativos', () async {
    final repository = CatalogRepository(database);
    final realId = await repository.createDiscipline('Disciplina real');
    await DemoDataSeed(database).load();

    final catalog = await repository.load();
    expect(catalog.disciplines, hasLength(7));
    expect(catalog.subtree('demo-v1-s-1-2-2-2-1'), isNotEmpty);

    final removed = await DemoDataSeed(database).remove();
    expect(removed.disciplines, 6);
    expect(removed.subjects, demoExpectedStats.subjects);
    final after = await repository.load();
    expect(after.discipline(realId).name, 'Disciplina real');
    expect(after.disciplines, hasLength(1));
  });

  test('faz rollback quando o carregamento falha', () async {
    expect(
      () => DemoDataSeed(database).load(failAfter: 3),
      throwsA(isA<StateError>()),
    );
    expect(await _count(database, 'disciplines'), 0);
    expect(await _count(database, 'subjects'), 0);
  });

  test('mantém dados após reabertura do banco', () async {
    final directory = await Directory.systemTemp.createTemp('study-planner-seed-');
    final path = '${directory.path}${Platform.pathSeparator}catalog.sqlite';
    final first = AppDatabase(NativeDatabase(File(path)));
    await first.initialize();
    await DemoDataSeed(first).load();
    await first.close();

    final second = AppDatabase(NativeDatabase(File(path)));
    await second.initialize();
    expect(await _count(second, 'disciplines'), demoExpectedStats.disciplines);
    expect(await _count(second, 'subjects'), demoExpectedStats.subjects);
    await second.close();
    await directory.delete(recursive: true);
  });
}

Future<int> _count(AppDatabase database, String table) async {
  final rows = await database.customSelect(
    'SELECT COUNT(*) AS total FROM $table WHERE deleted_at IS NULL',
  ).get();
  return rows.single.read<int>('total');
}
