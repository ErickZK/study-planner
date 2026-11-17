import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class Project {
  const Project(this.id, this.name);
  final int id;
  final String name;
}

class ProjectStats {
  const ProjectStats({
    required this.topicTotal,
    required this.topicDone,
    required this.activityTotal,
    required this.activityDone,
    required this.weekPlannedMinutes,
    required this.weekStudiedSeconds,
  });

  final int topicTotal;
  final int topicDone;
  final int activityTotal;
  final int activityDone;
  final int weekPlannedMinutes;
  final int weekStudiedSeconds;

  double get coverage => topicTotal == 0 ? 0 : topicDone / topicTotal;
  double get scheduleProgress =>
      activityTotal == 0 ? 0 : activityDone / activityTotal;
  double get weeklyProgress => weekPlannedMinutes == 0
      ? 0
      : (weekStudiedSeconds / (weekPlannedMinutes * 60)).clamp(0, 1);
}

class ProjectRepository {
  ProjectRepository(this.database);
  final AppDatabase database;

  static String? validateName(String value) {
    if (value.trim().isEmpty) return 'Informe o nome do projeto.';
    if (value.trim().length > 120) return 'Use até 120 caracteres.';
    return null;
  }

  Future<List<Project>> list() async {
    final rows = await database
        .customSelect('SELECT id, name FROM projects ORDER BY created_at, id')
        .get();
    return rows
        .map((r) => Project(r.read<int>('id'), r.read<String>('name')))
        .toList();
  }

  Future<Project?> find(int id) async {
    final rows = await database
        .customSelect(
          'SELECT id, name FROM projects WHERE id=?',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isEmpty) return null;
    return Project(
      rows.single.read<int>('id'),
      rows.single.read<String>('name'),
    );
  }

  Future<void> create(String name) async {
    final error = validateName(name);
    if (error != null) throw ArgumentError(error);
    await database.customInsert(
      'INSERT INTO projects (name, created_at) VALUES (?, ?)',
      variables: [
        Variable(name.trim()),
        Variable(DateTime.now().toUtc().millisecondsSinceEpoch),
      ],
    );
  }

  Future<void> delete(int id) =>
      database.customStatement('DELETE FROM projects WHERE id=?', [id]);

  Future<ProjectStats> stats(int projectId, {DateTime? today}) async {
    final current = today ?? DateTime.now();
    final monday = current.subtract(Duration(days: current.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    String date(DateTime value) => value.toIso8601String().substring(0, 10);

    final topics = await database
        .customSelect(
          '''SELECT COUNT(*) AS total,
                COALESCE(SUM(CASE WHEN p.completed=1 THEN 1 ELSE 0 END),0) AS done
         FROM syllabus_topics t
         JOIN vertical_syllabi v ON v.id=t.syllabus_id
         JOIN schedules sc ON sc.id=v.schedule_id
         LEFT JOIN topic_progress p ON p.syllabus_id=t.syllabus_id AND p.topic_id=t.topic_id
         WHERE sc.project_id=?
           AND NOT EXISTS (
             SELECT 1 FROM syllabus_topics child
             WHERE child.syllabus_id=t.syllabus_id
               AND child.parent_topic_id=t.topic_id
           )''',
          variables: [Variable(projectId)],
        )
        .getSingle();
    final activities = await database
        .customSelect(
          '''SELECT COUNT(*) AS total,
                COALESCE(SUM(CASE WHEN a.status='done' THEN 1 ELSE 0 END),0) AS done,
                COALESCE(SUM(CASE WHEN a.local_date BETWEEN ? AND ?
                                  THEN a.planned_minutes ELSE 0 END),0) AS planned
         FROM activities a
         JOIN schedules s ON s.id=a.schedule_id
         WHERE s.project_id=? AND s.archived=0''',
          variables: [
            Variable(date(monday)),
            Variable(date(sunday)),
            Variable(projectId),
          ],
        )
        .getSingle();
    final sessions = await database
        .customSelect(
          '''SELECT COALESCE(SUM(ss.actual_seconds),0) AS studied
         FROM study_sessions ss
         JOIN activities a ON a.id=ss.activity_id
         JOIN schedules s ON s.id=a.schedule_id
         WHERE s.project_id=? AND ss.status='finished'
           AND ss.local_study_date BETWEEN ? AND ?''',
          variables: [
            Variable(projectId),
            Variable(date(monday)),
            Variable(date(sunday)),
          ],
        )
        .getSingle();
    return ProjectStats(
      topicTotal: topics.read<int>('total'),
      topicDone: topics.read<int>('done'),
      activityTotal: activities.read<int>('total'),
      activityDone: activities.read<int>('done'),
      weekPlannedMinutes: activities.read<int>('planned'),
      weekStudiedSeconds: sessions.read<int>('studied'),
    );
  }
}
