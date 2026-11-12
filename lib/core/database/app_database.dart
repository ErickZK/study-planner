import 'package:drift/drift.dart';
import 'migrations/catalog_schema.dart';

/// SQL migrations are explicit; no destructive fallback is allowed.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
        created_at INTEGER NOT NULL
      )
    ''');
      await _createCatalog();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        await transaction(_createCatalog);
      } else {
        throw StateError('Migração não implementada: $from -> $to');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createCatalog() async {
    for (final statement in catalogSchema) {
      await customStatement(statement);
    }
  }

  Future<void> initialize() async {
    await customSelect('SELECT id FROM projects LIMIT 1').get();
  }
}
