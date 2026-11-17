import 'package:drift/drift.dart';
import 'migrations/catalog_schema.dart';
import 'migrations/syllabus_schema.dart';
import 'migrations/mvp_schema.dart';
import 'migrations/study_workspace_schema.dart';
import 'migrations/topic_review_schema.dart';

/// Schema v11 adds topic-level revision requests.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 11;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => _createFreshSchema(),
    onUpgrade: (m, from, to) async {
      if (from > 11 || to < from) {
        throw StateError('Migração não implementada: $from -> $to');
      }
      if (from < 7) {
        await transaction(_resetSchema);
        return;
      }
      if (from == 7) {
        await transaction(() async {
          await customStatement(
            'ALTER TABLE schedules ADD COLUMN focus_minutes INTEGER NOT NULL DEFAULT 25',
          );
          await customStatement(
            'ALTER TABLE schedules ADD COLUMN long_break_minutes INTEGER NOT NULL DEFAULT 15',
          );
          await customStatement(
            'ALTER TABLE schedules ADD COLUMN rounds_per_long_break INTEGER NOT NULL DEFAULT 4',
          );
        });
      }
      if (from <= 8) {
        await transaction(() async {
          final table = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='vertical_syllabi'",
          ).get();
          if (table.isEmpty) {
            await _createSyllabus();
          } else {
            await _migrateSyllabiToSchedules();
          }
        });
      }
      if (from <= 9) {
        await transaction(_createStudyWorkspace);
      }
      if (from <= 10) {
        await transaction(_createTopicReviews);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createFreshSchema() async {
    await customStatement('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
        created_at INTEGER NOT NULL
      )
    ''');
    await _createCatalog();
    await _createMvp();
    await _createSyllabus();
    await _createStudyWorkspace();
    await _createTopicReviews();
  }

  Future<void> _resetSchema() async {
    const tables = [
      'topic_reviews',
      'question_answers',
      'question_attempts',
      'activity_notes',
      'study_materials',
      'study_sessions',
      'activity_topics',
      'activities',
      'topic_progress',
      'syllabus_topics',
      'syllabus_disciplines',
      'vertical_syllabi',
      'schedules',
      'subjects',
      'disciplines',
      'projects',
    ];
    for (final table in tables) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
    await _createFreshSchema();
  }

  Future<void> _createCatalog() async {
    for (final statement in catalogSchema) {
      await customStatement(statement);
    }
  }

  Future<void> _createSyllabus() async {
    for (final statement in syllabusSchema) {
      await customStatement(statement);
    }
  }

  Future<void> _createMvp() async {
    for (final statement in mvpSchema) {
      await customStatement(statement);
    }
  }

  Future<void> _createStudyWorkspace() async {
    for (final statement in studyWorkspaceSchema) {
      await customStatement(statement);
    }
  }

  Future<void> _createTopicReviews() async {
    for (final statement in topicReviewSchema) {
      await customStatement(statement);
    }
  }

  Future<void> _migrateSyllabiToSchedules() async {
    await customStatement('DROP INDEX IF EXISTS syllabus_topics_parent_idx');
    await customStatement('''
      CREATE TABLE vertical_syllabi_v9 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id INTEGER NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE syllabus_disciplines_v9 (
        syllabus_id INTEGER NOT NULL,
        discipline_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (syllabus_id, discipline_id),
        FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi_v9(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE syllabus_topics_v9 (
        syllabus_id INTEGER NOT NULL,
        topic_id TEXT NOT NULL,
        parent_topic_id TEXT,
        position INTEGER NOT NULL,
        is_copy INTEGER NOT NULL DEFAULT 0,
        name_override TEXT,
        copy_source_id TEXT,
        PRIMARY KEY (syllabus_id, topic_id),
        FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi_v9(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE topic_progress_v9 (
        syllabus_id INTEGER NOT NULL,
        topic_id TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (syllabus_id, topic_id),
        FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi_v9(id) ON DELETE CASCADE
      )
    ''');

    final schedules = await customSelect(
      'SELECT id, project_id FROM schedules ORDER BY id',
    ).get();
    for (final schedule in schedules) {
      final scheduleId = schedule.read<int>('id');
      final projectId = schedule.read<int>('project_id');
      final old = await customSelect(
        'SELECT id,created_at,updated_at FROM vertical_syllabi WHERE project_id=?',
        variables: [Variable(projectId)],
      ).get();
      if (old.isEmpty) continue;
      final oldSyllabusId = old.single.read<int>('id');
      final newSyllabusId = await customInsert(
        'INSERT INTO vertical_syllabi_v9(schedule_id,created_at,updated_at) VALUES(?,?,?)',
        variables: [
          Variable(scheduleId),
          Variable(old.single.read<int>('created_at')),
          Variable(old.single.read<int>('updated_at')),
        ],
      );
      await customStatement(
        '''
        INSERT INTO syllabus_disciplines_v9(syllabus_id,discipline_id,position)
        SELECT ?,discipline_id,position FROM syllabus_disciplines WHERE syllabus_id=?
      ''',
        [newSyllabusId, oldSyllabusId],
      );
      await customStatement(
        '''
        INSERT INTO syllabus_topics_v9
          (syllabus_id,topic_id,parent_topic_id,position,is_copy,name_override,copy_source_id)
        SELECT ?,topic_id,parent_topic_id,position,is_copy,name_override,copy_source_id
        FROM syllabus_topics WHERE syllabus_id=?
      ''',
        [newSyllabusId, oldSyllabusId],
      );
      await customStatement(
        '''
        INSERT INTO topic_progress_v9(syllabus_id,topic_id,completed,updated_at)
        SELECT ?,p.topic_id,p.completed,p.updated_at
        FROM topic_progress p
        JOIN syllabus_topics t ON t.topic_id=p.topic_id
        WHERE t.syllabus_id=?
      ''',
        [newSyllabusId, oldSyllabusId],
      );
    }

    await customStatement('DROP TABLE topic_progress');
    await customStatement('DROP TABLE syllabus_topics');
    await customStatement('DROP TABLE syllabus_disciplines');
    await customStatement('DROP TABLE vertical_syllabi');
    await customStatement(
      'ALTER TABLE vertical_syllabi_v9 RENAME TO vertical_syllabi',
    );
    await customStatement(
      'ALTER TABLE syllabus_disciplines_v9 RENAME TO syllabus_disciplines',
    );
    await customStatement(
      'ALTER TABLE syllabus_topics_v9 RENAME TO syllabus_topics',
    );
    await customStatement(
      'ALTER TABLE topic_progress_v9 RENAME TO topic_progress',
    );
    await customStatement(
      'CREATE INDEX syllabus_topics_parent_idx ON syllabus_topics(syllabus_id, parent_topic_id, position)',
    );
  }

  Future<void> initialize() async {
    await customSelect('SELECT id FROM projects LIMIT 1').get();
  }

  Future<void> clearAllData() => transaction(_resetSchema);
}
