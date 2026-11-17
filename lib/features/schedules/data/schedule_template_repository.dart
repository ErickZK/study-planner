import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'schedule_repository.dart';

class ScheduleTemplateImportResult {
  const ScheduleTemplateImportResult({
    required this.scheduleId,
    required this.disciplines,
    required this.topics,
    required this.activities,
  });

  final int scheduleId, disciplines, topics, activities;
}

class ScheduleTemplateRepository {
  ScheduleTemplateRepository(this.database);

  final AppDatabase database;
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<String> exportTemplate(int scheduleId) async {
    final scheduleRows = await database
        .customSelect(
          'SELECT * FROM schedules WHERE id=? LIMIT 1',
          variables: [Variable(scheduleId)],
        )
        .get();
    if (scheduleRows.isEmpty) throw StateError('Cronograma não encontrado.');
    final schedule = scheduleRows.single;
    final syllabusRows = await database
        .customSelect(
          'SELECT id FROM vertical_syllabi WHERE schedule_id=? LIMIT 1',
          variables: [Variable(scheduleId)],
        )
        .get();
    final syllabusId = syllabusRows.isEmpty
        ? null
        : syllabusRows.single.read<int>('id');

    final disciplines = syllabusId == null
        ? const <QueryRow>[]
        : await database
              .customSelect(
                '''SELECT d.id,d.name,d.description,sd.position
                   FROM syllabus_disciplines sd
                   JOIN disciplines d ON d.id=sd.discipline_id
                   WHERE sd.syllabus_id=? ORDER BY sd.position,d.id''',
                variables: [Variable(syllabusId)],
              )
              .get();
    final disciplineKeys = <String, String>{};
    final disciplineJson = <Map<String, Object?>>[];
    for (var index = 0; index < disciplines.length; index++) {
      final row = disciplines[index];
      final id = row.read<String>('id');
      final key = 'd$index';
      disciplineKeys[id] = key;
      disciplineJson.add({
        'key': key,
        'name': row.read<String>('name'),
        'description': row.readNullable<String>('description'),
        'position': index,
      });
    }

    final topics = syllabusId == null
        ? const <QueryRow>[]
        : await database
              .customSelect(
                '''SELECT t.topic_id,t.parent_topic_id,t.position,
                          COALESCE(current.discipline_id,source.discipline_id) AS discipline_id,
                          COALESCE(t.name_override,current.name,source.name,'Assunto') AS name,
                          COALESCE(current.description,source.description) AS description
                   FROM syllabus_topics t
                   LEFT JOIN subjects current ON current.id=t.topic_id
                   LEFT JOIN subjects source ON source.id=t.copy_source_id
                   WHERE t.syllabus_id=? ORDER BY t.position,t.topic_id''',
                variables: [Variable(syllabusId)],
              )
              .get();
    final topicKeys = <String, String>{};
    for (var index = 0; index < topics.length; index++) {
      topicKeys[topics[index].read<String>('topic_id')] = 't$index';
    }
    final topicJson = <Map<String, Object?>>[];
    for (var index = 0; index < topics.length; index++) {
      final row = topics[index];
      topicJson.add({
        'key': 't$index',
        'discipline': disciplineKeys[row.read<String>('discipline_id')],
        'parent': topicKeys[row.readNullable<String>('parent_topic_id')],
        'name': row.read<String>('name'),
        'description': row.readNullable<String>('description'),
        'position': row.read<int>('position'),
      });
    }

    final activities = await database
        .customSelect(
          '''SELECT id,local_date,original_date,title,position,planned_minutes
             FROM activities WHERE schedule_id=? ORDER BY local_date,position,id''',
          variables: [Variable(scheduleId)],
        )
        .get();
    final activityJson = <Map<String, Object?>>[];
    for (var index = 0; index < activities.length; index++) {
      final row = activities[index];
      final links = await database
          .customSelect(
            'SELECT topic_id FROM activity_topics WHERE activity_id=? ORDER BY position',
            variables: [Variable(row.read<int>('id'))],
          )
          .get();
      activityJson.add({
        'key': 'a$index',
        'date': row.read<String>('local_date'),
        'originalDate': row.read<String>('original_date'),
        'title': row.read<String>('title'),
        'position': row.read<int>('position'),
        'plannedMinutes': row.read<int>('planned_minutes'),
        'topics': links
            .map((link) => topicKeys[link.read<String>('topic_id')])
            .whereType<String>()
            .toList(),
      });
    }

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'tjsp-planner-template',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'schedule': {
        'name': schedule.read<String>('name'),
        'dailyMinutes': schedule.read<int>('daily_minutes'),
        'startMinute': schedule.read<int>('start_minute'),
        'pomodoro': {
          'focusMinutes': schedule.read<int>('focus_minutes'),
          'shortBreakMinutes': schedule.read<int>('break_minutes'),
          'longBreakMinutes': schedule.read<int>('long_break_minutes'),
          'roundsPerLongBreak': schedule.read<int>('rounds_per_long_break'),
        },
      },
      'syllabus': {'disciplines': disciplineJson, 'topics': topicJson},
      'activities': activityJson,
    });
  }

  Future<ScheduleTemplateImportResult> importTemplate(
    String source, {
    required DateTime startDate,
    Set<int> restDays = const {},
  }) async {
    if (source.length > 10 * 1024 * 1024) {
      throw const FormatException('O template excede o limite de 10 MB.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'tjsp-planner-template' ||
        decoded['version'] != 1) {
      throw const FormatException('Arquivo de template incompatível.');
    }
    final schedule = _map(decoded['schedule'], 'schedule');
    final syllabus = _map(decoded['syllabus'], 'syllabus');
    final disciplines = _list(syllabus['disciplines'], 'disciplines');
    final topics = _list(syllabus['topics'], 'topics');
    final activities = _list(decoded['activities'], 'activities');
    if (disciplines.length > 100 ||
        topics.length > 10000 ||
        activities.length > 100000) {
      throw const FormatException('O template contém itens demais.');
    }
    final name = _text(schedule['name'], 'nome do cronograma');
    final pomodoro = _map(schedule['pomodoro'], 'pomodoro');
    final activityMaps = activities
        .map((value) => _map(value, 'atividade'))
        .toList();
    final normalizedStart = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    if (restDays.any((day) => day < 1 || day > 7) || restDays.length == 7) {
      throw const FormatException('Dias de folga inválidos.');
    }
    final dateMap = <String, String>{};
    final sourceDates =
        activityMaps.map((activity) => _date(activity['date'])).toSet().toList()
          ..sort();
    DateTime? previousSourceDate;
    DateTime? previousImportedDate;
    for (final sourceDate in sourceDates) {
      final parsed = DateTime.parse(sourceDate);
      final sourceDay = DateTime.utc(parsed.year, parsed.month, parsed.day);
      var importedDay = previousSourceDate == null
          ? normalizedStart
          : previousImportedDate!.add(
              Duration(
                days: sourceDay
                    .difference(previousSourceDate)
                    .inDays
                    .clamp(1, 3660),
              ),
            );
      while (restDays.contains(importedDay.weekday)) {
        importedDay = importedDay.add(const Duration(days: 1));
      }
      dateMap[sourceDate] = importedDay.toIso8601String().substring(0, 10);
      previousSourceDate = sourceDay;
      previousImportedDate = importedDay;
    }

    return database.transaction(() async {
      final owner = await ScheduleRepository(database).ensureOwner();
      final importedName = await _availableScheduleName(name);
      final scheduleId = await ScheduleRepository(database).create(
        owner,
        importedName,
        dailyMinutes: _integer(schedule['dailyMinutes'], 1, 1440),
        startMinute: _integer(schedule['startMinute'], 0, 1439),
        focusMinutes: _integer(pomodoro['focusMinutes'], 1, 180),
        breakMinutes: _integer(pomodoro['shortBreakMinutes'], 1, 120),
        longBreakMinutes: _integer(pomodoro['longBreakMinutes'], 1, 240),
        roundsPerLongBreak: _integer(pomodoro['roundsPerLongBreak'], 1, 20),
      );
      final syllabusId = await database.customInsert(
        'INSERT INTO vertical_syllabi(schedule_id,created_at,updated_at) VALUES(?,?,?)',
        variables: [Variable(scheduleId), Variable(_now), Variable(_now)],
      );

      final disciplineIds = <String, String>{};
      for (var index = 0; index < disciplines.length; index++) {
        final item = _map(disciplines[index], 'disciplina');
        final key = _key(item['key']);
        if (disciplineIds.containsKey(key)) {
          throw const FormatException('Chave de disciplina duplicada.');
        }
        final disciplineName = _text(item['name'], 'disciplina');
        final id = await _findOrCreateDiscipline(
          disciplineName,
          _optionalText(item['description']),
        );
        disciplineIds[key] = id;
        await database.customStatement(
          'INSERT INTO syllabus_disciplines(syllabus_id,discipline_id,position) VALUES(?,?,?)',
          [syllabusId, id, index],
        );
      }

      final pendingTopics = topics
          .map((value) => _map(value, 'assunto'))
          .toList();
      final topicIds = <String, String>{};
      var guard = 0;
      while (pendingTopics.isNotEmpty) {
        if (guard++ > topics.length + 1) {
          throw const FormatException('Hierarquia de assuntos inválida.');
        }
        var inserted = 0;
        for (final item in [...pendingTopics]) {
          final key = _key(item['key']);
          if (topicIds.containsKey(key)) {
            throw const FormatException('Chave de assunto duplicada.');
          }
          final disciplineId = disciplineIds[_key(item['discipline'])];
          if (disciplineId == null) {
            throw const FormatException('Disciplina do assunto inválida.');
          }
          final parentKey = item['parent'] == null
              ? null
              : _key(item['parent']);
          if (parentKey != null && !topicIds.containsKey(parentKey)) continue;
          final parentId = parentKey == null ? null : topicIds[parentKey];
          final topicName = _text(item['name'], 'assunto');
          final id = await _findOrCreateSubject(
            disciplineId,
            parentId,
            topicName,
            _optionalText(item['description']),
          );
          topicIds[key] = id;
          await database.customStatement(
            '''INSERT INTO syllabus_topics
               (syllabus_id,topic_id,parent_topic_id,position)
               VALUES(?,?,?,?)''',
            [syllabusId, id, parentId, _integer(item['position'], 0, 1000000)],
          );
          pendingTopics.remove(item);
          inserted++;
        }
        if (inserted == 0) {
          throw const FormatException('Hierarquia de assuntos inválida.');
        }
      }

      for (final item in activityMaps) {
        final date = dateMap[_date(item['date'])]!;
        final activityId = await database.customInsert(
          '''INSERT INTO activities
             (schedule_id,local_date,original_date,title,status,position,
              planned_minutes,created_at,updated_at)
             VALUES(?,?,?,?,'pending',?,?,?,?)''',
          variables: [
            Variable(scheduleId),
            Variable(date),
            const Variable(''),
            Variable(_text(item['title'], 'atividade')),
            Variable(_integer(item['position'], 0, 1000000)),
            Variable(_integer(item['plannedMinutes'], 0, 1440)),
            Variable(_now),
            Variable(_now),
          ],
        );
        final links = _list(item['topics'], 'tópicos da atividade');
        for (var position = 0; position < links.length; position++) {
          final topicId = topicIds[_key(links[position])];
          if (topicId == null) {
            throw const FormatException('Vínculo de atividade inválido.');
          }
          await database.customStatement(
            'INSERT INTO activity_topics(activity_id,topic_id,position) VALUES(?,?,?)',
            [activityId, topicId, position],
          );
        }
      }
      return ScheduleTemplateImportResult(
        scheduleId: scheduleId,
        disciplines: disciplines.length,
        topics: topics.length,
        activities: activities.length,
      );
    });
  }

  Future<String> _availableScheduleName(String base) async {
    var candidate = base;
    var copy = 0;
    while (true) {
      final rows = await database
          .customSelect(
            'SELECT 1 FROM schedules WHERE lower(name)=lower(?) LIMIT 1',
            variables: [Variable(candidate)],
          )
          .get();
      if (rows.isEmpty) return candidate;
      copy++;
      candidate = copy == 1 ? '$base (importado)' : '$base (importado $copy)';
    }
  }

  Future<String> _randomId() async =>
      (await database
              .customSelect('SELECT lower(hex(randomblob(16))) AS id')
              .getSingle())
          .read<String>('id');

  Future<String> _findOrCreateDiscipline(
    String name,
    String? description,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT id FROM disciplines WHERE deleted_at IS NULL AND lower(name)=lower(?) ORDER BY id LIMIT 1',
          variables: [Variable(name)],
        )
        .get();
    if (rows.isNotEmpty) return rows.single.read<String>('id');
    final id = await _randomId();
    final position =
        (await database
                .customSelect(
                  'SELECT COUNT(*) AS total FROM disciplines WHERE deleted_at IS NULL',
                )
                .getSingle())
            .read<int>('total');
    await database.customStatement(
      '''INSERT INTO disciplines
         (id,name,description,position,created_at,updated_at)
         VALUES(?,?,?,?,?,?)''',
      [id, name, description, position, _now, _now],
    );
    return id;
  }

  Future<String> _findOrCreateSubject(
    String disciplineId,
    String? parentId,
    String name,
    String? description,
  ) async {
    final rows = await database
        .customSelect(
          '''SELECT id FROM subjects
             WHERE discipline_id=? AND deleted_at IS NULL
               AND lower(name)=lower(?)
               AND ((parent_id IS NULL AND ? IS NULL) OR parent_id=?)
             ORDER BY id LIMIT 1''',
          variables: [
            Variable(disciplineId),
            Variable(name),
            Variable(parentId),
            Variable(parentId),
          ],
        )
        .get();
    if (rows.isNotEmpty) return rows.single.read<String>('id');
    final id = await _randomId();
    final position =
        (await database
                .customSelect(
                  '''SELECT COUNT(*) AS total FROM subjects
                 WHERE discipline_id=? AND deleted_at IS NULL
                   AND ((parent_id IS NULL AND ? IS NULL) OR parent_id=?)''',
                  variables: [
                    Variable(disciplineId),
                    Variable(parentId),
                    Variable(parentId),
                  ],
                )
                .getSingle())
            .read<int>('total');
    await database.customStatement(
      '''INSERT INTO subjects
         (id,discipline_id,parent_id,name,description,position,created_at,updated_at)
         VALUES(?,?,?,?,?,?,?,?)''',
      [id, disciplineId, parentId, name, description, position, _now, _now],
    );
    return id;
  }

  Map<String, dynamic> _map(Object? value, String field) {
    if (value is! Map) throw FormatException('$field inválido.');
    return value.map((key, value) => MapEntry('$key', value));
  }

  List<dynamic> _list(Object? value, String field) {
    if (value is! List) throw FormatException('$field inválido.');
    return value;
  }

  String _key(Object? value) {
    final key = '$value';
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{0,63}$').hasMatch(key)) {
      throw const FormatException('Chave inválida.');
    }
    return key;
  }

  String _text(Object? value, String field) {
    if (value is! String || value.trim().isEmpty || value.trim().length > 120) {
      throw FormatException('$field inválido.');
    }
    return value.trim();
  }

  String? _optionalText(Object? value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    final text = '$value'.trim();
    if (text.length > 4000) throw const FormatException('Descrição inválida.');
    return text;
  }

  int _integer(Object? value, int minimum, int maximum) {
    if (value is! int || value < minimum || value > maximum) {
      throw const FormatException('Valor numérico inválido.');
    }
    return value;
  }

  String _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Data inválida.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Data inválida.');
    }
    return value;
  }
}
