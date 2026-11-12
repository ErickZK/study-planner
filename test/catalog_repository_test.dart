import 'dart:io';
import 'package:drift/drift.dart'
    show
        GeneratedDatabase,
        TableInfo,
        Table,
        DatabaseSchemaEntity,
        MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/catalog/domain/catalog.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository repository;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    repository = CatalogRepository(db);
  });
  tearDown(() => db.close());

  test('validates names and persists descriptions and edits', () async {
    expect(validateCatalogName(' '), isNotNull);
    expect(validateCatalogName('x' * 121), isNotNull);
    await expectLater(
      repository.createDiscipline(' '),
      throwsA(isA<CatalogException>()),
    );
    final d = await repository.createDiscipline(
      '  Direito  ',
      description: ' Texto ',
    );
    final s = await repository.createSubject(
      d,
      'Introdução',
      description: 'Base',
    );
    await repository.editDiscipline(
      d,
      'Direito civil',
      description: 'Catálogo',
    );
    await repository.editSubject(s, 'Conceitos', description: '');
    final catalog = await repository.load();
    expect(catalog.discipline(d).name, 'Direito civil');
    expect(catalog.subject(s).description, isNull);
    expect(catalog.subject(s).createdAt.isUtc, isTrue);
    expect((await repository.search('CIVIL')).single.id, d);
    expect(await repository.search('inexistente'), isEmpty);
  });

  test('loads multi-level tree and expands iteratively', () async {
    final d = await repository.createDiscipline('Disciplina');
    final root = await repository.createSubject(d, 'Raiz');
    final child = await repository.createSubject(d, 'Filho', parentId: root);
    final leaf = await repository.createSubject(d, 'Folha', parentId: child);
    final catalog = await repository.load();
    expect(catalog.subtree(root).map((s) => s.id), [root, child, leaf]);
    expect(catalog.visible(d, {}).length, 1);
    expect(catalog.visible(d, {root, child}).map((r) => r.$2), [0, 1, 2]);
    expect(catalog.validParents(root), isEmpty);
  });

  test(
    'reorders siblings and disciplines with contiguous persisted positions',
    () async {
      final d = await repository.createDiscipline('Primeira');
      final other = await repository.createDiscipline('Segunda');
      await repository.reorderDiscipline(other, 0);
      final a = await repository.createSubject(d, 'A');
      final b = await repository.createSubject(d, 'B');
      final c = await repository.createSubject(d, 'C');
      await repository.placeSubjectBefore(a, c);
      var catalog = await repository.load();
      expect(catalog.children(d, null).map((s) => s.id), [b, a, c]);
      await repository.moveSubject(c, null, index: 0);
      catalog = await repository.load();
      expect(catalog.children(d, null).map((s) => s.id), [c, b, a]);
      expect(catalog.children(d, null).map((s) => s.position), [0, 1, 2]);
      expect(catalog.disciplines.first.id, other);
      await repository.placeDisciplineBefore(d, other);
      expect((await repository.load()).disciplines.first.id, d);
    },
  );

  test(
    'moves subtree across levels, rejects cycles, self and other disciplines',
    () async {
      final d = await repository.createDiscipline('D');
      final other = await repository.createDiscipline('Outra');
      final a = await repository.createSubject(d, 'A');
      final b = await repository.createSubject(d, 'B', parentId: a);
      final c = await repository.createSubject(d, 'C', parentId: b);
      final foreign = await repository.createSubject(other, 'Outro');
      await expectLater(
        repository.moveSubject(a, c),
        throwsA(isA<CatalogException>()),
      );
      await expectLater(
        repository.moveSubject(a, a),
        throwsA(isA<CatalogException>()),
      );
      await expectLater(
        repository.moveSubject(a, foreign),
        throwsA(isA<CatalogException>()),
      );
      await repository.moveSubject(b, null, index: 0);
      final catalog = await repository.load();
      expect(catalog.subject(b).parentId, isNull);
      expect(catalog.subject(c).parentId, b);
      expect(catalog.children(d, a), isEmpty);
      expect(catalog.children(d, null).map((s) => s.id), [b, a]);
    },
  );

  test(
    'SQLite rejects direct cycles and cross-discipline references',
    () async {
      final d = await repository.createDiscipline('D');
      final other = await repository.createDiscipline('Outra');
      final a = await repository.createSubject(d, 'A');
      final b = await repository.createSubject(d, 'B', parentId: a);
      final foreign = await repository.createSubject(other, 'Outro');
      await expectLater(
        db.customStatement('UPDATE subjects SET parent_id=? WHERE id=?', [
          b,
          a,
        ]),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement('UPDATE subjects SET parent_id=? WHERE id=?', [
          foreign,
          a,
        ]),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement('UPDATE subjects SET parent_id=? WHERE id=?', [
          a,
          a,
        ]),
        throwsA(anything),
      );
      expect((await repository.load()).subject(a).parentId, isNull);
    },
  );

  test(
    'duplicates complete subtree and discipline with independent identities',
    () async {
      final d = await repository.createDiscipline(
        'D',
        description: 'Descrição',
      );
      final a = await repository.createSubject(d, 'A');
      final b = await repository.createSubject(d, 'B', parentId: a);
      await repository.createSubject(d, 'C', parentId: b);
      final copy = await repository.duplicateSubject(a);
      var catalog = await repository.load();
      expect(catalog.subtree(copy).map((s) => s.name), ['A', 'B', 'C']);
      expect(
        catalog
            .subtree(copy)
            .map((s) => s.id)
            .toSet()
            .intersection(catalog.subtree(a).map((s) => s.id).toSet()),
        isEmpty,
      );
      await repository.editSubject(copy, 'Independente');
      expect((await repository.load()).subject(a).name, 'A');
      final disciplineCopy = await repository.duplicateDiscipline(d);
      catalog = await repository.load();
      expect(
        catalog.subjects.where((s) => s.disciplineId == disciplineCopy).length,
        6,
      );
      expect(catalog.discipline(disciplineCopy).description, 'Descrição');
      expect(catalog.children(disciplineCopy, null).length, 2);
    },
  );

  test(
    'logical subtree deletion preserves identities and normalizes surviving order',
    () async {
      final d = await repository.createDiscipline('D');
      final root = await repository.createSubject(d, 'Raiz');
      await repository.createSubject(d, 'Filho', parentId: root);
      final survivor = await repository.createSubject(d, 'Sobrevive');
      await repository.deleteSubject(root);
      var catalog = await repository.load();
      expect(catalog.subjects.single.id, survivor);
      expect(catalog.subjects.single.position, 0);
      expect(
        (await db
                .customSelect(
                  'SELECT count(*) AS n FROM subjects WHERE deleted_at IS NOT NULL',
                )
                .getSingle())
            .read<int>('n'),
        2,
      );
      await expectLater(
        repository.createSubject(d, 'Inválido', parentId: root),
        throwsA(isA<CatalogException>()),
      );
      await repository.deleteDiscipline(d);
      catalog = await repository.load();
      expect(catalog.disciplines, isEmpty);
      expect(catalog.subjects, isEmpty);
      expect(
        (await db.customSelect('PRAGMA foreign_key_check').get()),
        isEmpty,
      );
    },
  );

  test(
    'rolls back a clone that fails after inserting its discipline and root',
    () async {
      final d = await repository.createDiscipline('D');
      final root = await repository.createSubject(d, 'Raiz');
      await repository.createSubject(d, 'Falhar', parentId: root);
      await db.customStatement(
        """CREATE TRIGGER fail_copy BEFORE INSERT ON subjects
      WHEN NEW.name='Falhar' BEGIN SELECT RAISE(ABORT, 'injected_failure'); END""",
      );
      await expectLater(repository.duplicateDiscipline(d), throwsA(anything));
      final catalog = await repository.load();
      expect(catalog.disciplines.length, 1);
      expect(catalog.subjects.length, 2);
      await expectLater(
        db.transaction(() async {
          await repository.moveSubject(root, null, index: 0);
          await repository.deleteDiscipline(d);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect((await repository.load()).subjects.length, 2);
    },
  );

  test(
    'retains hierarchy and order after closing and reopening a file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'catalog_reopen_',
      );
      final file = File('${directory.path}/app.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      try {
        await first.initialize();
        final repo = CatalogRepository(first);
        final d = await repo.createDiscipline('Persistente');
        final s = await repo.createSubject(d, 'Raiz');
        await repo.createSubject(d, 'Filho', parentId: s);
      } finally {
        await first.close();
      }
      final second = AppDatabase(NativeDatabase(file));
      try {
        await second.initialize();
        final catalog = await CatalogRepository(second).load();
        expect(catalog.disciplines.single.name, 'Persistente');
        expect(
          catalog
              .subtree(
                catalog.children(catalog.disciplines.single.id, null).single.id,
              )
              .length,
          2,
        );
      } finally {
        await second.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('migrates actual v1 file without losing projects', () async {
    final directory = await Directory.systemTemp.createTemp(
      'catalog_migration_',
    );
    final file = File('${directory.path}/v1.sqlite');
    final legacy = _LegacyDatabase(NativeDatabase(file));
    await legacy.customStatement(
      "INSERT INTO projects(name,created_at) VALUES ('Projeto anterior',0)",
    );
    await legacy.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    try {
      await upgraded.initialize();
      expect(
        (await ProjectRepository(upgraded).list()).single.name,
        'Projeto anterior',
      );
      expect((await CatalogRepository(upgraded).load()).disciplines, isEmpty);
      await CatalogRepository(upgraded).createDiscipline('Nova');
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
      expect(
        await upgraded.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });

  test('domain traversal supports deep hierarchies without recursion', () {
    final now = DateTime.utc(2026);
    final catalog = Catalog([], [
      for (var i = 0; i < 2000; i++)
        Subject(
          id: '$i',
          disciplineId: 'd',
          parentId: i == 0 ? null : '${i - 1}',
          name: '$i',
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    expect(catalog.subtree('0').length, 2000);
    expect(catalog.visible('d', catalog.byId.keys.toSet()).last.$2, 1999);
  });
}

class _LegacyDatabase extends GeneratedDatabase {
  _LegacyDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => customStatement('''
    CREATE TABLE projects (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120), created_at INTEGER NOT NULL)
  '''),
  );
}
