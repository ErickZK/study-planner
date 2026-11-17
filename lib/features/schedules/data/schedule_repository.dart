import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class StudySchedule {
  const StudySchedule({
    required this.id,
    required this.projectId,
    required this.name,
    required this.dailyMinutes,
    required this.startMinute,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.longBreakMinutes,
    required this.roundsPerLongBreak,
    required this.archived,
  });
  final int id;
  final int projectId;
  final String name;
  final int dailyMinutes;
  final int startMinute;
  final int focusMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int roundsPerLongBreak;
  final bool archived;
}

class ScheduleRepository {
  ScheduleRepository(this.database);
  final AppDatabase database;
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Internal compatibility owner for the legacy `project_id` column.
  /// Projects are no longer exposed as a product concept.
  Future<int> ensureOwner() async {
    final rows = await database
        .customSelect('SELECT id FROM projects ORDER BY id LIMIT 1')
        .get();
    if (rows.isNotEmpty) return rows.single.read<int>('id');
    return database.customInsert(
      'INSERT INTO projects(name,created_at) VALUES(?,?)',
      variables: [const Variable('Planner'), Variable(_now)],
    );
  }

  Future<List<StudySchedule>> listAll() async {
    final rows = await database
        .customSelect(
          'SELECT * FROM schedules WHERE archived=0 ORDER BY name,id',
        )
        .get();
    return rows.map(_readSchedule).toList();
  }

  StudySchedule _readSchedule(QueryRow r) => StudySchedule(
    id: r.read<int>('id'),
    projectId: r.read<int>('project_id'),
    name: r.read<String>('name'),
    dailyMinutes: r.read<int>('daily_minutes'),
    startMinute: r.read<int>('start_minute'),
    focusMinutes: r.read<int>('focus_minutes'),
    breakMinutes: r.read<int>('break_minutes'),
    longBreakMinutes: r.read<int>('long_break_minutes'),
    roundsPerLongBreak: r.read<int>('rounds_per_long_break'),
    archived: r.read<int>('archived') == 1,
  );

  Future<List<StudySchedule>> list(int projectId) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM schedules WHERE project_id=? ORDER BY archived,id',
          variables: [Variable(projectId)],
        )
        .get();
    return rows
        .map(
          (r) => StudySchedule(
            id: r.read<int>('id'),
            projectId: r.read<int>('project_id'),
            name: r.read<String>('name'),
            dailyMinutes: r.read<int>('daily_minutes'),
            startMinute: r.read<int>('start_minute'),
            focusMinutes: r.read<int>('focus_minutes'),
            breakMinutes: r.read<int>('break_minutes'),
            longBreakMinutes: r.read<int>('long_break_minutes'),
            roundsPerLongBreak: r.read<int>('rounds_per_long_break'),
            archived: r.read<int>('archived') == 1,
          ),
        )
        .toList();
  }

  Future<StudySchedule> get(int id) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM schedules WHERE id=?',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isEmpty) throw StateError('Cronograma não encontrado.');
    final r = rows.single;
    return StudySchedule(
      id: r.read<int>('id'),
      projectId: r.read<int>('project_id'),
      name: r.read<String>('name'),
      dailyMinutes: r.read<int>('daily_minutes'),
      startMinute: r.read<int>('start_minute'),
      focusMinutes: r.read<int>('focus_minutes'),
      breakMinutes: r.read<int>('break_minutes'),
      longBreakMinutes: r.read<int>('long_break_minutes'),
      roundsPerLongBreak: r.read<int>('rounds_per_long_break'),
      archived: r.read<int>('archived') == 1,
    );
  }

  Future<int> create(
    int projectId,
    String name, {
    int dailyMinutes = 120,
    int startMinute = 480,
    int focusMinutes = 25,
    int breakMinutes = 5,
    int longBreakMinutes = 15,
    int roundsPerLongBreak = 4,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe um nome para o cronograma.');
    }
    return database.customInsert(
      'INSERT INTO schedules(project_id,name,daily_minutes,start_minute,focus_minutes,break_minutes,long_break_minutes,rounds_per_long_break,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)',
      variables: [
        Variable(projectId),
        Variable(name.trim()),
        Variable(dailyMinutes),
        Variable(startMinute),
        Variable(focusMinutes),
        Variable(breakMinutes),
        Variable(longBreakMinutes),
        Variable(roundsPerLongBreak),
        Variable(_now),
        Variable(_now),
      ],
    );
  }

  Future<int> createStudyPlan({
    required int projectId,
    required String name,
    required DateTime startDate,
    required int dailyMinutes,
    required Set<int> studyDays,
    bool useSelectedSyllabus = true,
  }) async {
    if (studyDays.isEmpty) {
      throw ArgumentError('Selecione pelo menos um dia de estudo.');
    }
    return database.transaction(() async {
      final scheduleId = await create(
        projectId,
        name,
        dailyMinutes: dailyMinutes,
      );
      final syllabusItems = useSelectedSyllabus
          ? await _selectedSyllabusItems(scheduleId)
          : const <(String, String)>[];
      if (useSelectedSyllabus && syllabusItems.isNotEmpty) {
        await _generateFromSyllabus(
          scheduleId,
          startDate,
          dailyMinutes,
          studyDays,
          syllabusItems,
        );
      }
      return scheduleId;
    });
  }

  Future<List<(String, String)>> _selectedSyllabusItems(int scheduleId) async {
    final rows = await database
        .customSelect(
          '''
      SELECT COALESCE(d.name,'Disciplina') AS discipline_name,
             COALESCE(t.name_override,c.name,s.name,'Assunto') AS topic_name
      FROM vertical_syllabi v
      JOIN syllabus_topics t ON t.syllabus_id=v.id
      LEFT JOIN subjects c ON c.id=t.topic_id
      LEFT JOIN subjects s ON s.id=t.copy_source_id
      LEFT JOIN disciplines d ON d.id=COALESCE(c.discipline_id,s.discipline_id)
      WHERE v.schedule_id=?
        AND NOT EXISTS (
          SELECT 1 FROM syllabus_topics child
          WHERE child.syllabus_id=t.syllabus_id
            AND child.parent_topic_id=t.topic_id
        )
      ORDER BY t.position,t.topic_id
      ''',
          variables: [Variable(scheduleId)],
        )
        .get();
    return rows
        .map(
          (row) => (
            row.read<String>('discipline_name'),
            row.read<String>('topic_name'),
          ),
        )
        .toList();
  }

  Future<void> _generateFromSyllabus(
    int scheduleId,
    DateTime startDate,
    int dailyMinutes,
    Set<int> studyDays,
    List<(String, String)> items,
  ) async {
    var cursor = _firstStudyDate(startDate, studyDays);
    var index = 0;
    while (index < items.length) {
      final dayItems = items.skip(index).take(2).toList();
      for (var position = 0; position < dayItems.length; position++) {
        final item = dayItems[position];
        await _insertActivity(
          scheduleId,
          cursor,
          '${item.$1} — ${item.$2}',
          position,
          dailyMinutes ~/ dayItems.length,
        );
      }
      index += dayItems.length;
      cursor = _nextStudyDate(cursor, studyDays);
    }
  }

  Future<void> _insertActivity(
    int scheduleId,
    DateTime date,
    String title,
    int position,
    int minutes,
  ) => database.customStatement(
    '''INSERT INTO activities
       (schedule_id,local_date,title,position,planned_minutes,created_at,updated_at)
       VALUES(?,?,?,?,?,?,?)''',
    [scheduleId, _dateKey(date), title, position, minutes, _now, _now],
  );

  DateTime _firstStudyDate(DateTime value, Set<int> studyDays) {
    var result = DateTime(value.year, value.month, value.day);
    while (!studyDays.contains(result.weekday)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime _nextStudyDate(DateTime value, Set<int> studyDays) {
    var result = value.add(const Duration(days: 1));
    while (!studyDays.contains(result.weekday)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  String _dateKey(DateTime value) => value.toIso8601String().substring(0, 10);

  Future<void> update(
    int id, {
    String? name,
    int? dailyMinutes,
    int? startMinute,
    int? focusMinutes,
    int? breakMinutes,
    int? longBreakMinutes,
    int? roundsPerLongBreak,
    bool? archived,
  }) async {
    final current = await database
        .customSelect(
          'SELECT * FROM schedules WHERE id=?',
          variables: [Variable(id)],
        )
        .get();
    if (current.isEmpty) throw StateError('Cronograma não encontrado.');
    final row = current.single;
    await database.customStatement(
      'UPDATE schedules SET name=?,daily_minutes=?,start_minute=?,focus_minutes=?,break_minutes=?,long_break_minutes=?,rounds_per_long_break=?,archived=?,updated_at=? WHERE id=?',
      [
        name?.trim() ?? row.read<String>('name'),
        dailyMinutes ?? row.read<int>('daily_minutes'),
        startMinute ?? row.read<int>('start_minute'),
        focusMinutes ?? row.read<int>('focus_minutes'),
        breakMinutes ?? row.read<int>('break_minutes'),
        longBreakMinutes ?? row.read<int>('long_break_minutes'),
        roundsPerLongBreak ?? row.read<int>('rounds_per_long_break'),
        (archived ?? row.read<int>('archived') == 1) ? 1 : 0,
        _now,
        id,
      ],
    );
  }

  Future<int> duplicate(int id) async {
    return database.transaction(() async {
      final rows = await database
          .customSelect(
            'SELECT * FROM schedules WHERE id=?',
            variables: [Variable(id)],
          )
          .get();
      if (rows.isEmpty) throw StateError('Cronograma não encontrado.');
      final r = rows.single;
      final copyId = await create(
        r.read<int>('project_id'),
        '${r.read<String>('name')} (cópia)',
        dailyMinutes: r.read<int>('daily_minutes'),
        startMinute: r.read<int>('start_minute'),
        focusMinutes: r.read<int>('focus_minutes'),
        breakMinutes: r.read<int>('break_minutes'),
        longBreakMinutes: r.read<int>('long_break_minutes'),
        roundsPerLongBreak: r.read<int>('rounds_per_long_break'),
      );
      final source = await database
          .customSelect(
            'SELECT id FROM vertical_syllabi WHERE schedule_id=?',
            variables: [Variable(id)],
          )
          .get();
      if (source.isNotEmpty) {
        final now = _now;
        final syllabusId = await database.customInsert(
          'INSERT INTO vertical_syllabi(schedule_id,created_at,updated_at) VALUES(?,?,?)',
          variables: [Variable(copyId), Variable(now), Variable(now)],
        );
        final sourceId = source.single.read<int>('id');
        await database.customStatement(
          '''INSERT INTO syllabus_disciplines(syllabus_id,discipline_id,position)
             SELECT ?,discipline_id,position FROM syllabus_disciplines WHERE syllabus_id=?''',
          [syllabusId, sourceId],
        );
        await database.customStatement(
          '''INSERT INTO syllabus_topics
             (syllabus_id,topic_id,parent_topic_id,position,is_copy,name_override,copy_source_id)
             SELECT ?,topic_id,parent_topic_id,position,is_copy,name_override,copy_source_id
             FROM syllabus_topics WHERE syllabus_id=?''',
          [syllabusId, sourceId],
        );
        await database.customStatement(
          '''INSERT INTO topic_progress(syllabus_id,topic_id,completed,updated_at)
             SELECT ?,topic_id,completed,updated_at FROM topic_progress WHERE syllabus_id=?''',
          [syllabusId, sourceId],
        );
      }
      return copyId;
    });
  }

  Future<void> archive(int id) => update(id, archived: true);
  Future<void> delete(int id) =>
      database.customStatement('DELETE FROM schedules WHERE id=?', [id]);
}
