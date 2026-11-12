import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../catalog/data/catalog_repository.dart';

class SyllabusTopic {
  const SyllabusTopic({
    required this.topicId,
    required this.parentTopicId,
    required this.position,
    required this.name,
    required this.disciplineId,
    required this.completed,
    required this.isCopy,
  });

  final String topicId;
  final String? parentTopicId;
  final int position;
  final String name;
  final String disciplineId;
  final bool completed;
  final bool isCopy;
}

class SyllabusSnapshot {
  const SyllabusSnapshot({
    required this.syllabusId,
    required this.projectId,
    required this.disciplineIds,
    required this.topics,
  });

  final int syllabusId;
  final int projectId;
  final Set<String> disciplineIds;
  final List<SyllabusTopic> topics;

  List<SyllabusTopic> get leaves {
    final parents = topics.map((item) => item.parentTopicId).whereType<String>().toSet();
    return topics.where((item) => !parents.contains(item.topicId)).toList();
  }

  int get completedLeaves => leaves.where((item) => item.completed).length;
  double get completion => leaves.isEmpty ? 0 : completedLeaves / leaves.length;
}

class SyllabusRepository {
  SyllabusRepository(this.database);

  final AppDatabase database;

  Future<int> ensureForProject(int projectId) => database.transaction(() => _ensureForProject(projectId));

  Future<int> _ensureForProject(int projectId) async {
    final rows = await database.customSelect(
      'SELECT id FROM vertical_syllabi WHERE project_id=?',
      variables: [Variable(projectId)],
    ).get();
    if (rows.isNotEmpty) return rows.single.read<int>('id');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return database.customInsert(
      'INSERT INTO vertical_syllabi(project_id,created_at,updated_at) VALUES(?,?,?)',
      variables: [Variable(projectId), Variable(now), Variable(now)],
    );
  }

  Future<SyllabusSnapshot> loadForProject(int projectId) async {
    final syllabusId = await ensureForProject(projectId);
    final disciplines = await database.customSelect(
      'SELECT discipline_id FROM syllabus_disciplines WHERE syllabus_id=? ORDER BY position, discipline_id',
      variables: [Variable(syllabusId)],
    ).get();
    final rows = await database.customSelect('''
      SELECT t.topic_id,t.parent_topic_id,t.position,t.is_copy,t.name_override,
             COALESCE(p.completed,0) AS completed,
             COALESCE(s.discipline_id,c.discipline_id) AS discipline_id,
             COALESCE(t.name_override,c.name,s.name) AS topic_name
      FROM syllabus_topics t
      LEFT JOIN topic_progress p ON p.topic_id=t.topic_id
      LEFT JOIN subjects c ON c.id=t.topic_id
      LEFT JOIN subjects s ON s.id=t.copy_source_id
      WHERE t.syllabus_id=?
      ORDER BY t.position,t.topic_id
    ''', variables: [Variable(syllabusId)]).get();
    final topics = rows
        .map(
          (r) => SyllabusTopic(
            topicId: r.read<String>('topic_id'),
            parentTopicId: r.readNullable<String>('parent_topic_id'),
            position: r.read<int>('position'),
            name: r.read<String>('topic_name'),
            disciplineId: r.read<String>('discipline_id'),
            completed: r.read<int>('completed') == 1,
            isCopy: r.read<int>('is_copy') == 1,
          ),
        )
        .toList();
    final childIds = topics.map((item) => item.parentTopicId).whereType<String>().toSet();
    for (var index = 0; index < topics.length; index++) {
      final item = topics[index];
      if (!childIds.contains(item.topicId)) continue;
      final descendants = _descendants(topics, item.topicId);
      final leaves = descendants.where((candidate) => !childIds.contains(candidate.topicId));
      topics[index] = SyllabusTopic(
        topicId: item.topicId,
        parentTopicId: item.parentTopicId,
        position: item.position,
        name: item.name,
        disciplineId: item.disciplineId,
        completed: leaves.isNotEmpty && leaves.every((leaf) => leaf.completed),
        isCopy: item.isCopy,
      );
    }
    return SyllabusSnapshot(
      syllabusId: syllabusId,
      projectId: projectId,
      disciplineIds: disciplines.map((r) => r.read<String>('discipline_id')).toSet(),
      topics: topics,
    );
  }

  Future<void> replaceSelection(
    int projectId,
    Set<String> disciplineIds,
    Set<String> topicIds,
  ) => database.transaction(() async {
        final syllabusId = await _ensureForProject(projectId);
        await database.customStatement('DELETE FROM syllabus_topics WHERE syllabus_id=?', [syllabusId]);
        await database.customStatement('DELETE FROM syllabus_disciplines WHERE syllabus_id=?', [syllabusId]);
        var disciplinePosition = 0;
        for (final disciplineId in disciplineIds) {
          await database.customStatement(
            'INSERT INTO syllabus_disciplines(syllabus_id,discipline_id,position) VALUES(?,?,?)',
            [syllabusId, disciplineId, disciplinePosition++],
          );
        }
        final catalog = await CatalogRepository(database).load();
        final selected = topicIds.map(catalog.subject).toList();
        for (var index = 0; index < selected.length; index++) {
          final subject = selected[index];
          await database.customStatement(
            '''INSERT INTO syllabus_topics
              (syllabus_id,topic_id,parent_topic_id,position)
              VALUES(?,?,?,?)''',
            [
              syllabusId,
              subject.id,
              topicIds.contains(subject.parentId) ? subject.parentId : null,
              index,
            ],
          );
        }
        await _touch(syllabusId);
      });

  Future<void> toggleTopic(int projectId, String topicId, bool completed) async {
    final syllabusId = await ensureForProject(projectId);
    final snapshot = await loadForProject(projectId);
    final topic = snapshot.topics.firstWhere((item) => item.topicId == topicId);
    final descendants = _descendants(snapshot.topics, topic.topicId);
    if (completed && descendants.isNotEmpty &&
        descendants.any((item) => !item.completed)) {
      throw StateError('Conclua os descendentes antes de concluir este assunto.');
    }
    await database.transaction(() async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await database.customStatement(
        '''INSERT INTO topic_progress(topic_id,completed,updated_at) VALUES(?,?,?)
           ON CONFLICT(topic_id) DO UPDATE SET completed=excluded.completed,updated_at=excluded.updated_at''',
        [topicId, completed ? 1 : 0, now],
      );
      await _touch(syllabusId);
    });
  }

  Future<String> copyOnWrite(int projectId, String topicId, String newName) async {
    final syllabusId = await ensureForProject(projectId);
    return database.transaction(() async {
      final usages = await database.customSelect(
        'SELECT COUNT(*) AS total FROM syllabus_topics WHERE topic_id=?',
        variables: [Variable(topicId)],
      ).get();
      if (usages.single.read<int>('total') <= 1) {
        await database.customStatement(
          'UPDATE syllabus_topics SET name_override=? WHERE syllabus_id=? AND topic_id=?',
          [newName.trim(), syllabusId, topicId],
        );
        return topicId;
      }
      final rows = await database.customSelect(
        'SELECT topic_id,parent_topic_id,position,is_copy,copy_source_id FROM syllabus_topics WHERE syllabus_id=?',
        variables: [Variable(syllabusId)],
      ).get();
      final subtree = <String>{topicId};
      var changed = true;
      while (changed) {
        changed = false;
        for (final row in rows) {
          final parent = row.readNullable<String>('parent_topic_id');
          if (parent != null && subtree.contains(parent) && subtree.add(row.read<String>('topic_id'))) {
            changed = true;
          }
        }
      }
      final mapping = <String, String>{};
      var counter = 0;
      for (final row in rows.where((r) => subtree.contains(r.read<String>('topic_id')))) {
        mapping[row.read<String>('topic_id')] = 'copy-$syllabusId-${DateTime.now().microsecondsSinceEpoch}-${counter++}';
      }
      for (final row in rows.where((r) => subtree.contains(r.read<String>('topic_id')))) {
        final oldId = row.read<String>('topic_id');
        final parent = row.readNullable<String>('parent_topic_id');
        final newId = mapping[oldId]!;
        await database.customStatement(
          '''UPDATE syllabus_topics SET topic_id=?, parent_topic_id=?, is_copy=1,
             copy_source_id=?, name_override=? WHERE syllabus_id=? AND topic_id=?''',
          [
            newId,
            mapping[parent] ?? parent,
            oldId,
            oldId == topicId ? newName.trim() : null,
            syllabusId,
            oldId,
          ],
        );
        final progress = await database.customSelect(
          'SELECT completed FROM topic_progress WHERE topic_id=?',
          variables: [Variable(oldId)],
        ).get();
        if (progress.isNotEmpty) {
          await database.customStatement(
            'INSERT OR REPLACE INTO topic_progress(topic_id,completed,updated_at) VALUES(?,?,?)',
            [newId, progress.single.read<int>('completed'), DateTime.now().toUtc().millisecondsSinceEpoch],
          );
        }
      }
      await _touch(syllabusId);
      return mapping[topicId]!;
    });
  }

  List<SyllabusTopic> _descendants(List<SyllabusTopic> topics, String id) {
    final result = <SyllabusTopic>[];
    final pending = [id];
    while (pending.isNotEmpty) {
      final parent = pending.removeLast();
      final children = topics.where((item) => item.parentTopicId == parent);
      result.addAll(children);
      pending.addAll(children.map((item) => item.topicId));
    }
    return result;
  }

  Future<void> _touch(int syllabusId) => database.customStatement(
        'UPDATE vertical_syllabi SET updated_at=? WHERE id=?',
        [DateTime.now().toUtc().millisecondsSinceEpoch, syllabusId],
      );
}
