import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('creates SQLite schema, validates and reads projects', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.initialize();
    final repository = ProjectRepository(db);
    expect(await repository.list(), isEmpty);
    await repository.create('  Meu estudo  ');
    expect((await repository.list()).single.name, 'Meu estudo');
    final projectId = (await repository.list()).single.id;
    await repository.delete(projectId);
    expect(await repository.list(), isEmpty);
    await repository.create('Meu estudo');
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
      11,
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

  test('resets a real v1 file into schema v11', () async {
    final directory = await Directory.systemTemp.createTemp(
      'study_planner_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/legacy.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(
      'CREATE TABLE projects(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,created_at INTEGER NOT NULL)',
    );
    raw.execute("INSERT INTO projects(name,created_at) VALUES('Legacy',0)");
    raw.execute('PRAGMA user_version=1');
    raw.dispose();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.initialize();
    expect(await ProjectRepository(db).list(), isEmpty);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      11,
    );
    expect(
      (await db.customSelect('PRAGMA table_info(study_sessions)').get()).where(
        (r) => r.read<String>('name') == 'local_study_date',
      ),
      hasLength(1),
    );
    expect(
      (await db.customSelect('PRAGMA table_info(activities)').get()).where(
        (r) => r.read<String>('name') == 'original_date',
      ),
      hasLength(1),
    );
  });

  test('migrates v7 Pomodoro settings without losing schedules', () async {
    final directory = await Directory.systemTemp.createTemp(
      'study_planner_v7_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/v7.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(
      'CREATE TABLE projects(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,created_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE schedules(id INTEGER PRIMARY KEY AUTOINCREMENT,project_id INTEGER NOT NULL,name TEXT NOT NULL,daily_minutes INTEGER NOT NULL DEFAULT 120,start_minute INTEGER NOT NULL DEFAULT 480,break_minutes INTEGER NOT NULL DEFAULT 5,archived INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL)',
    );
    raw.execute("INSERT INTO projects(name,created_at) VALUES('TJSP',0)");
    raw.execute(
      "INSERT INTO schedules(project_id,name,daily_minutes,start_minute,break_minutes,archived,created_at,updated_at) VALUES(1,'Plano',120,480,10,0,0,0)",
    );
    raw.execute('PRAGMA user_version=7');
    raw.dispose();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.initialize();
    final schedule = await db
        .customSelect('SELECT * FROM schedules')
        .getSingle();
    expect(schedule.read<String>('name'), 'Plano');
    expect(schedule.read<int>('break_minutes'), 10);
    expect(schedule.read<int>('focus_minutes'), 25);
    expect(schedule.read<int>('long_break_minutes'), 15);
    expect(schedule.read<int>('rounds_per_long_break'), 4);
  });
}
