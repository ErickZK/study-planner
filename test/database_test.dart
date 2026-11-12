import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';

void main() {
  test('creates SQLite schema, validates and reads projects', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.initialize();
    final repository = ProjectRepository(db);
    expect(await repository.list(), isEmpty);
    await repository.create('  Meu estudo  ');
    expect((await repository.list()).single.name, 'Meu estudo');
    await expectLater(repository.create(' '), throwsArgumentError);
    await expectLater(
      db.customStatement(
        "INSERT INTO projects(name, created_at) VALUES ('', 0)",
      ),
      throwsA(anything),
    );
  });

  test('retains data after closing and reopening the same file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'study_planner_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await first.initialize();
    await ProjectRepository(first).create('Persistido');
    await first.close();
    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    await second.initialize();
    expect((await ProjectRepository(second).list()).single.name, 'Persistido');
    expect(
      (await second.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      2,
    );
  });

  test('multi-entity writes can roll back atomically', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.initialize();
    await expectLater(
      db.transaction(() async {
        await ProjectRepository(db).create('Reverter');
        throw StateError('falha simulada');
      }),
      throwsStateError,
    );
    expect(await ProjectRepository(db).list(), isEmpty);
  });
}
