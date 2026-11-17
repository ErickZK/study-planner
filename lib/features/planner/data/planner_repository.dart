import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class PlannedActivity {
  const PlannedActivity({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.title,
    required this.status,
    required this.position,
    required this.plannedMinutes,
    required this.topicIds,
  });
  final int id, scheduleId, position, plannedMinutes;
  final String date, title, status;
  final List<String> topicIds;
}

class PomodoroSettings {
  const PomodoroSettings({
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.roundsPerLongBreak,
  });
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsPerLongBreak;
}

class CompletionTopicOption {
  const CompletionTopicOption({
    required this.id,
    required this.name,
    required this.disciplineId,
    required this.disciplineName,
    required this.completed,
    required this.linkedToActivity,
  });

  final String id, name, disciplineId, disciplineName;
  final bool completed, linkedToActivity;
}

class CompletionTopicSelection {
  const CompletionTopicSelection({
    required this.activityTitle,
    required this.topics,
    required this.suggestedDisciplineIds,
  });

  final String activityTitle;
  final List<CompletionTopicOption> topics;
  final Set<String> suggestedDisciplineIds;
}

class StudySessionRecord {
  const StudySessionRecord({
    required this.id,
    required this.activityId,
    required this.date,
    required this.status,
    required this.seconds,
    required this.accumulatedSeconds,
    required this.startedAt,
    required this.questions,
    required this.correct,
    this.notes,
  });
  final int id, activityId, seconds, accumulatedSeconds, questions, correct;
  final String date, status;
  final int? startedAt;
  final String? notes;
}

class StudyMaterialRecord {
  const StudyMaterialRecord({
    required this.id,
    required this.activityId,
    required this.kind,
    required this.title,
    required this.location,
    required this.isUsed,
  });

  final int id, activityId;
  final String kind, title, location;
  final bool isUsed;
}

class QuestionAnswerDraft {
  const QuestionAnswerDraft({
    required this.number,
    required this.answer,
    required this.isCorrect,
  });

  final int number;
  final String answer;
  final bool isCorrect;
}

class QuestionAttemptRecord {
  const QuestionAttemptRecord({
    required this.id,
    required this.activityId,
    required this.createdAt,
    required this.answers,
  });

  final int id, activityId, createdAt;
  final List<QuestionAnswerDraft> answers;
  int get correct => answers.where((answer) => answer.isCorrect).length;
}

class PerformanceMetrics {
  const PerformanceMetrics({
    required this.seconds,
    required this.questions,
    required this.correct,
    required this.pendingActivities,
    required this.completedActivities,
  });
  final int seconds, questions, correct, pendingActivities, completedActivities;
  int get errors => questions - correct;
  double get accuracy => questions == 0 ? 0 : correct / questions;
}

class DailyStudyMetric {
  const DailyStudyMetric({
    required this.date,
    required this.seconds,
    required this.questions,
    required this.correct,
  });
  final DateTime date;
  final int seconds, questions, correct;
  double get accuracy => questions == 0 ? 0 : correct / questions;
}

class DisciplineStudyMetric {
  const DisciplineStudyMetric({
    required this.name,
    required this.seconds,
    required this.questions,
    required this.correct,
  });
  final String name;
  final int seconds, questions, correct;
  double get accuracy => questions == 0 ? 0 : correct / questions;
}

class PlannerAnalytics {
  const PlannerAnalytics({
    required this.daily,
    required this.disciplines,
    required this.plannedTasks,
    required this.completedTasks,
    required this.studyDays,
    required this.streak,
  });
  final List<DailyStudyMetric> daily;
  final List<DisciplineStudyMetric> disciplines;
  final int plannedTasks, completedTasks, studyDays, streak;
  int get seconds => daily.fold(0, (sum, item) => sum + item.seconds);
  int get questions => daily.fold(0, (sum, item) => sum + item.questions);
  int get correct => daily.fold(0, (sum, item) => sum + item.correct);
  double get accuracy => questions == 0 ? 0 : correct / questions;
  double get taskCompletion =>
      plannedTasks == 0 ? 0 : completedTasks / plannedTasks;
}

class PlannerRepository {
  PlannerRepository(this.database);
  final AppDatabase database;
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<PlannedActivity?> findActivity(int id) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM activities WHERE id=? LIMIT 1',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    final topics = await database
        .customSelect(
          'SELECT topic_id FROM activity_topics WHERE activity_id=? ORDER BY position',
          variables: [Variable(id)],
        )
        .get();
    return PlannedActivity(
      id: id,
      scheduleId: row.read<int>('schedule_id'),
      date: row.read<String>('local_date'),
      title: row.read<String>('title'),
      status: row.read<String>('status'),
      position: row.read<int>('position'),
      plannedMinutes: row.read<int>('planned_minutes'),
      topicIds: topics.map((item) => item.read<String>('topic_id')).toList(),
    );
  }

  Future<PomodoroSettings> pomodoroSettings(int activityId) async {
    final rows = await database
        .customSelect(
          '''SELECT s.focus_minutes,s.break_minutes,s.long_break_minutes,
         s.rounds_per_long_break
         FROM activities a JOIN schedules s ON s.id=a.schedule_id
         WHERE a.id=? LIMIT 1''',
          variables: [Variable(activityId)],
        )
        .get();
    if (rows.isEmpty) {
      return const PomodoroSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        roundsPerLongBreak: 4,
      );
    }
    final row = rows.single;
    return PomodoroSettings(
      focusMinutes: row.read<int>('focus_minutes'),
      shortBreakMinutes: row.read<int>('break_minutes'),
      longBreakMinutes: row.read<int>('long_break_minutes'),
      roundsPerLongBreak: row.read<int>('rounds_per_long_break'),
    );
  }

  Future<CompletionTopicSelection> completionTopics(int activityId) async {
    final activityRows = await database
        .customSelect(
          'SELECT schedule_id,title FROM activities WHERE id=? LIMIT 1',
          variables: [Variable(activityId)],
        )
        .get();
    if (activityRows.isEmpty) {
      throw StateError('Atividade não encontrada.');
    }
    final activity = activityRows.single;
    final title = activity.read<String>('title');
    final rows = await database
        .customSelect(
          '''
      SELECT t.topic_id,
             COALESCE(t.name_override,current_subject.name,source_subject.name,'Assunto') AS topic_name,
             COALESCE(current_subject.discipline_id,source_subject.discipline_id) AS discipline_id,
             discipline.name AS discipline_name,
             COALESCE(progress.completed,0) AS completed,
             CASE WHEN activity_topic.topic_id IS NULL THEN 0 ELSE 1 END AS linked
      FROM vertical_syllabi syllabus
      JOIN syllabus_topics t ON t.syllabus_id=syllabus.id
      LEFT JOIN subjects current_subject ON current_subject.id=t.topic_id
      LEFT JOIN subjects source_subject ON source_subject.id=t.copy_source_id
      JOIN disciplines discipline
        ON discipline.id=COALESCE(current_subject.discipline_id,source_subject.discipline_id)
      LEFT JOIN topic_progress progress
        ON progress.syllabus_id=syllabus.id AND progress.topic_id=t.topic_id
      LEFT JOIN activity_topics activity_topic
        ON activity_topic.activity_id=? AND activity_topic.topic_id=t.topic_id
      WHERE syllabus.schedule_id=?
        AND NOT EXISTS (
          SELECT 1 FROM syllabus_topics child
          WHERE child.syllabus_id=t.syllabus_id
            AND child.parent_topic_id=t.topic_id
        )
      ORDER BY discipline.name,t.position,t.topic_id
      ''',
          variables: [
            Variable(activityId),
            Variable(activity.read<int>('schedule_id')),
          ],
        )
        .get();
    final topics = rows
        .map(
          (row) => CompletionTopicOption(
            id: row.read<String>('topic_id'),
            name: row.read<String>('topic_name'),
            disciplineId: row.read<String>('discipline_id'),
            disciplineName: row.read<String>('discipline_name'),
            completed: row.read<int>('completed') == 1,
            linkedToActivity: row.read<int>('linked') == 1,
          ),
        )
        .toList();
    final linked = topics
        .where((topic) => topic.linkedToActivity)
        .map((topic) => topic.disciplineId)
        .toSet();
    final normalizedTitle = _normalize(title);
    final inferred = topics
        .where(
          (topic) => normalizedTitle.contains(_normalize(topic.disciplineName)),
        )
        .map((topic) => topic.disciplineId)
        .toSet();
    final disciplines = topics.map((topic) => topic.disciplineId).toSet();
    return CompletionTopicSelection(
      activityTitle: title,
      topics: topics,
      suggestedDisciplineIds: linked.isNotEmpty
          ? linked
          : inferred.isNotEmpty
          ? inferred
          : disciplines.length == 1
          ? disciplines
          : const {},
    );
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  Future<List<PlannedActivity>> list(int scheduleId, String date) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM activities WHERE schedule_id=? AND local_date=? ORDER BY position,id',
          variables: [Variable(scheduleId), Variable(date)],
        )
        .get();
    final result = <PlannedActivity>[];
    for (final row in rows) {
      final topics = await database
          .customSelect(
            'SELECT topic_id FROM activity_topics WHERE activity_id=? ORDER BY position',
            variables: [Variable(row.read<int>('id'))],
          )
          .get();
      result.add(
        PlannedActivity(
          id: row.read<int>('id'),
          scheduleId: scheduleId,
          date: date,
          title: row.read<String>('title'),
          status: row.read<String>('status'),
          position: row.read<int>('position'),
          plannedMinutes: row.read<int>('planned_minutes'),
          topicIds: topics
              .map((item) => item.read<String>('topic_id'))
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<List<PlannedActivity>> listRange(
    int scheduleId,
    String from,
    String to,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM activities WHERE schedule_id=? AND local_date BETWEEN ? AND ? ORDER BY local_date,position,id',
          variables: [Variable(scheduleId), Variable(from), Variable(to)],
        )
        .get();
    final result = <PlannedActivity>[];
    for (final row in rows) {
      final id = row.read<int>('id');
      final topics = await database
          .customSelect(
            'SELECT topic_id FROM activity_topics WHERE activity_id=? ORDER BY position',
            variables: [Variable(id)],
          )
          .get();
      result.add(
        PlannedActivity(
          id: id,
          scheduleId: scheduleId,
          date: row.read<String>('local_date'),
          title: row.read<String>('title'),
          status: row.read<String>('status'),
          position: row.read<int>('position'),
          plannedMinutes: row.read<int>('planned_minutes'),
          topicIds: topics
              .map((item) => item.read<String>('topic_id'))
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<int> create(
    int scheduleId,
    String date,
    String title, {
    Iterable<String> topicIds = const [],
    int? plannedMinutes,
  }) => database.transaction(() async {
    final schedule = await database
        .customSelect(
          'SELECT daily_minutes FROM schedules WHERE id=?',
          variables: [Variable(scheduleId)],
        )
        .get();
    final siblings = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM activities WHERE schedule_id=? AND local_date=?',
          variables: [Variable(scheduleId), Variable(date)],
        )
        .get();
    final minutes =
        plannedMinutes ??
        ((schedule.single.read<int>('daily_minutes')) ~/
            (topicIds.isEmpty ? 1 : topicIds.length));
    final id = await database.customInsert(
      'INSERT INTO activities(schedule_id,local_date,title,position,planned_minutes,created_at,updated_at) VALUES(?,?,?,?,?,?,?)',
      variables: [
        Variable(scheduleId),
        Variable(date),
        Variable(title.trim()),
        Variable(siblings.single.read<int>('total')),
        Variable(minutes),
        Variable(_now),
        Variable(_now),
      ],
    );
    var position = 0;
    for (final topic in topicIds) {
      await database.customStatement(
        'INSERT INTO activity_topics(activity_id,topic_id,position) VALUES(?,?,?)',
        [id, topic, position++],
      );
    }
    return id;
  });

  Future<void> setStatus(int id, String status) => database.customStatement(
    'UPDATE activities SET status=?,updated_at=? WHERE id=?',
    [status, _now, id],
  );
  Future<void> updateActivity(
    int id, {
    String? title,
    String? date,
    int? plannedMinutes,
    Iterable<String>? topicIds,
  }) => database.transaction(() async {
    final current = await database
        .customSelect(
          'SELECT schedule_id,local_date,title,planned_minutes FROM activities WHERE id=?',
          variables: [Variable(id)],
        )
        .get();
    if (current.isEmpty) throw StateError('Atividade não encontrada.');
    final row = current.single;
    await database.customStatement(
      'UPDATE activities SET title=?,local_date=?,planned_minutes=?,updated_at=? WHERE id=?',
      [
        title?.trim() ?? row.read<String>('title'),
        date ?? row.read<String>('local_date'),
        plannedMinutes ?? row.read<int>('planned_minutes'),
        _now,
        id,
      ],
    );
    if (topicIds != null) {
      await database.customStatement(
        'DELETE FROM activity_topics WHERE activity_id=?',
        [id],
      );
      var position = 0;
      for (final topic in topicIds) {
        await database.customStatement(
          'INSERT INTO activity_topics(activity_id,topic_id,position) VALUES(?,?,?)',
          [id, topic, position++],
        );
      }
    }
  });
  Future<void> reorder(int id, int position) => database.customStatement(
    'UPDATE activities SET position=?,updated_at=? WHERE id=?',
    [position, _now, id],
  );
  Future<int> rescheduleOverdue(int scheduleId, {DateTime? today}) async {
    final current = today ?? DateTime.now();
    final date = current.toIso8601String().substring(0, 10);
    final rows = await database
        .customSelect(
          "SELECT id FROM activities WHERE schedule_id=? AND status!='done' AND local_date<? ORDER BY local_date,position,id",
          variables: [Variable(scheduleId), Variable(date)],
        )
        .get();
    if (rows.isEmpty) return 0;
    final occupied = await database
        .customSelect(
          'SELECT DISTINCT local_date FROM activities WHERE schedule_id=? AND local_date>=?',
          variables: [Variable(scheduleId), Variable(date)],
        )
        .get();
    var destination = current;
    while (occupied.any(
      (r) =>
          r.read<String>('local_date') ==
          destination.toIso8601String().substring(0, 10),
    )) {
      destination = destination.add(const Duration(days: 1));
    }
    final destinationDate = destination.toIso8601String().substring(0, 10);
    return database.transaction(() async {
      var position = 0;
      for (final row in rows) {
        await database.customStatement(
          'UPDATE activities SET local_date=?,original_date=CASE WHEN original_date=\'\' THEN local_date ELSE original_date END,position=?,updated_at=? WHERE id=?',
          [destinationDate, position++, _now, row.read<int>('id')],
        );
      }
      return rows.length;
    });
  }

  Future<void> delete(int id) =>
      database.customStatement('DELETE FROM activities WHERE id=?', [id]);

  Future<void> recoverOpenSessions() => database.customStatement(
    "UPDATE study_sessions SET status='paused',updated_at=? WHERE status='running'",
    [_now],
  );

  Future<List<StudySessionRecord>> sessions(int activityId) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM study_sessions WHERE activity_id=? ORDER BY created_at,id',
          variables: [Variable(activityId)],
        )
        .get();
    return rows
        .map(
          (r) => StudySessionRecord(
            id: r.read<int>('id'),
            activityId: activityId,
            date: r.read<String>('local_study_date'),
            status: r.read<String>('status'),
            seconds: _effectiveSeconds(r),
            accumulatedSeconds: r.read<int>('accumulated_seconds'),
            startedAt: r.readNullable<int>('started_at'),
            questions: r.read<int>('question_count'),
            correct: r.read<int>('correct_count'),
            notes: r.readNullable<String>('notes'),
          ),
        )
        .toList();
  }

  int _effectiveSeconds(QueryRow row) {
    final accumulated = row.read<int>('accumulated_seconds');
    final startedAt = row.readNullable<int>('started_at');
    if (row.read<String>('status') != 'running' || startedAt == null) {
      return row.read<int>('actual_seconds');
    }
    final runningSeconds =
        (DateTime.now().toUtc().millisecondsSinceEpoch - startedAt) ~/ 1000;
    return accumulated + runningSeconds.clamp(0, 86400 * 30);
  }

  Future<int> startSession(int activityId) async {
    await recoverOpenSessions();
    final active = await database
        .customSelect(
          "SELECT id FROM study_sessions WHERE status IN ('running','paused','break') LIMIT 1",
        )
        .get();
    if (active.isNotEmpty) throw StateError('Já existe uma sessão aberta.');
    final activity = await database
        .customSelect(
          'SELECT local_date FROM activities WHERE id=?',
          variables: [Variable(activityId)],
        )
        .get();
    return database.customInsert(
      "INSERT INTO study_sessions(activity_id,local_study_date,status,started_at,created_at,updated_at) VALUES(?,?,'running',?,?,?)",
      variables: [
        Variable(activityId),
        Variable(activity.single.read<String>('local_date')),
        Variable(_now),
        Variable(_now),
        Variable(_now),
      ],
    );
  }

  Future<void> resumeSession(int id) => database.customStatement(
    "UPDATE study_sessions SET status='running',started_at=?,updated_at=? WHERE id=?",
    [_now, _now, id],
  );

  Future<void> startPomodoroBreak(
    int id,
    int focusSeconds,
  ) => database.customStatement(
    "UPDATE study_sessions SET status='break',actual_seconds=?,accumulated_seconds=?,started_at=?,updated_at=? WHERE id=?",
    [focusSeconds, focusSeconds, _now, _now, id],
  );
  Future<void> pauseSession(
    int id,
    int actualSeconds,
  ) => database.customStatement(
    "UPDATE study_sessions SET status='paused',actual_seconds=?,accumulated_seconds=?,started_at=NULL,updated_at=? WHERE id=?",
    [actualSeconds, actualSeconds, _now, id],
  );
  Future<void> finishSession(
    int id,
    int actualSeconds, {
    int? questions,
    int? correct,
    String? notes,
  }) {
    if ((questions == null) != (correct == null) ||
        (questions != null &&
            (questions < 0 || correct! < 0 || correct > questions))) {
      throw ArgumentError(
        'Acertos devem estar entre zero e o total de questões.',
      );
    }
    return database.customStatement(
      "UPDATE study_sessions SET status='finished',actual_seconds=?,accumulated_seconds=?,started_at=NULL,question_count=COALESCE(?,question_count),correct_count=COALESCE(?,correct_count),notes=?,updated_at=? WHERE id=?",
      [actualSeconds, actualSeconds, questions, correct, notes, _now, id],
    );
  }

  Future<List<StudyMaterialRecord>> materials(int activityId) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM study_materials WHERE activity_id=? ORDER BY created_at,id',
          variables: [Variable(activityId)],
        )
        .get();
    return rows
        .map(
          (row) => StudyMaterialRecord(
            id: row.read<int>('id'),
            activityId: activityId,
            kind: row.read<String>('kind'),
            title: row.read<String>('title'),
            location: row.read<String>('location'),
            isUsed: row.read<int>('is_used') == 1,
          ),
        )
        .toList();
  }

  Future<int> addMaterial(
    int activityId, {
    required String kind,
    required String title,
    required String location,
  }) {
    if (!{'pdf', 'link'}.contains(kind) ||
        title.trim().isEmpty ||
        location.trim().isEmpty) {
      throw ArgumentError('Material inválido.');
    }
    return database.customInsert(
      '''INSERT INTO study_materials
         (activity_id,kind,title,location,created_at,updated_at)
         VALUES(?,?,?,?,?,?)''',
      variables: [
        Variable(activityId),
        Variable(kind),
        Variable(title.trim()),
        Variable(location.trim()),
        Variable(_now),
        Variable(_now),
      ],
    );
  }

  Future<void> setMaterialUsed(int id, bool isUsed) => database.customStatement(
    'UPDATE study_materials SET is_used=?,updated_at=? WHERE id=?',
    [isUsed ? 1 : 0, _now, id],
  );

  Future<void> deleteMaterial(int id) =>
      database.customStatement('DELETE FROM study_materials WHERE id=?', [id]);

  Future<String> activityNotes(int activityId) async {
    final rows = await database
        .customSelect(
          'SELECT content FROM activity_notes WHERE activity_id=? LIMIT 1',
          variables: [Variable(activityId)],
        )
        .get();
    return rows.isEmpty ? '' : rows.single.read<String>('content');
  }

  Future<void> saveActivityNotes(int activityId, String content) =>
      database.customStatement(
        '''INSERT INTO activity_notes(activity_id,content,updated_at)
           VALUES(?,?,?)
           ON CONFLICT(activity_id)
           DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at''',
        [activityId, content, _now],
      );

  Future<List<QuestionAttemptRecord>> questionAttempts(int activityId) async {
    final attempts = await database
        .customSelect(
          'SELECT id,created_at FROM question_attempts WHERE activity_id=? ORDER BY created_at DESC,id DESC',
          variables: [Variable(activityId)],
        )
        .get();
    final result = <QuestionAttemptRecord>[];
    for (final attempt in attempts) {
      final id = attempt.read<int>('id');
      final answers = await database
          .customSelect(
            'SELECT question_number,selected_answer,is_correct FROM question_answers WHERE attempt_id=? ORDER BY question_number',
            variables: [Variable(id)],
          )
          .get();
      result.add(
        QuestionAttemptRecord(
          id: id,
          activityId: activityId,
          createdAt: attempt.read<int>('created_at'),
          answers: answers
              .map(
                (row) => QuestionAnswerDraft(
                  number: row.read<int>('question_number'),
                  answer: row.read<String>('selected_answer'),
                  isCorrect: row.read<int>('is_correct') == 1,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<int> saveQuestionAttempt(
    int activityId,
    List<QuestionAnswerDraft> answers, {
    int? studySessionId,
  }) async {
    if (answers.isEmpty ||
        answers.any(
          (answer) =>
              answer.number < 1 ||
              !{'A', 'B', 'C', 'D', 'E'}.contains(answer.answer),
        )) {
      throw ArgumentError('Preencha todas as respostas do gabarito.');
    }
    return database.transaction(() async {
      final attemptId = await database.customInsert(
        '''INSERT INTO question_attempts
           (activity_id,study_session_id,question_count,created_at)
           VALUES(?,?,?,?)''',
        variables: [
          Variable(activityId),
          Variable(studySessionId),
          Variable(answers.length),
          Variable(_now),
        ],
      );
      for (final answer in answers) {
        await database.customStatement(
          '''INSERT INTO question_answers
             (attempt_id,question_number,selected_answer,is_correct)
             VALUES(?,?,?,?)''',
          [attemptId, answer.number, answer.answer, answer.isCorrect ? 1 : 0],
        );
      }
      if (studySessionId != null) {
        final correct = answers.where((answer) => answer.isCorrect).length;
        await database.customStatement(
          '''UPDATE study_sessions
             SET question_count=question_count+?,
                 correct_count=correct_count+?,updated_at=?
             WHERE id=? AND activity_id=?''',
          [answers.length, correct, _now, studySessionId, activityId],
        );
      }
      return attemptId;
    });
  }

  Future<void> deleteQuestionAttempt(int id) async {
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            '''SELECT attempt.study_session_id,attempt.question_count,
                      COALESCE(SUM(answer.is_correct),0) AS correct
               FROM question_attempts attempt
               LEFT JOIN question_answers answer ON answer.attempt_id=attempt.id
               WHERE attempt.id=? GROUP BY attempt.id''',
            variables: [Variable(id)],
          )
          .get();
      if (rows.isEmpty) return;
      final row = rows.single;
      final sessionId = row.readNullable<int>('study_session_id');
      if (sessionId != null) {
        await database.customStatement(
          '''UPDATE study_sessions SET
             question_count=MAX(0,question_count-?),
             correct_count=MAX(0,correct_count-?),updated_at=? WHERE id=?''',
          [
            row.read<int>('question_count'),
            row.read<int>('correct'),
            _now,
            sessionId,
          ],
        );
      }
      await database.customStatement(
        'DELETE FROM question_attempts WHERE id=?',
        [id],
      );
    });
  }

  Future<void> completeActivityWithTopics(
    int activityId,
    Set<String> topicIds, {
    Set<String> reviewTopicIds = const {},
    int? sessionId,
    int? actualSeconds,
  }) async {
    if ((sessionId == null) != (actualSeconds == null) ||
        (actualSeconds != null && actualSeconds < 0)) {
      throw ArgumentError('Dados da sessão inválidos.');
    }
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            '''SELECT activity.schedule_id,syllabus.id AS syllabus_id
           FROM activities activity
           LEFT JOIN vertical_syllabi syllabus ON syllabus.schedule_id=activity.schedule_id
           WHERE activity.id=? LIMIT 1''',
            variables: [Variable(activityId)],
          )
          .get();
      if (rows.isEmpty) throw StateError('Atividade não encontrada.');
      final row = rows.single;
      if (sessionId != null) {
        await database.customStatement(
          '''UPDATE study_sessions SET status='finished',actual_seconds=?,
             accumulated_seconds=?,started_at=NULL,updated_at=?
             WHERE id=? AND activity_id=?''',
          [actualSeconds, actualSeconds, _now, sessionId, activityId],
        );
      }
      await database.customStatement(
        "UPDATE activities SET status='done',updated_at=? WHERE id=?",
        [_now, activityId],
      );
      final syllabusId = row.readNullable<int>('syllabus_id');
      if (syllabusId == null) return;
      var topicPosition = 0;
      for (final topicId in topicIds) {
        final valid = await database
            .customSelect(
              'SELECT 1 FROM syllabus_topics WHERE syllabus_id=? AND topic_id=? LIMIT 1',
              variables: [Variable(syllabusId), Variable(topicId)],
            )
            .get();
        if (valid.isEmpty) continue;
        await database.customStatement(
          '''INSERT INTO activity_topics(activity_id,topic_id,position)
             VALUES(?,?,?)
             ON CONFLICT(activity_id,topic_id) DO NOTHING''',
          [activityId, topicId, topicPosition++],
        );
        await database.customStatement(
          '''INSERT INTO topic_progress(syllabus_id,topic_id,completed,updated_at)
             VALUES(?,?,1,?)
             ON CONFLICT(syllabus_id,topic_id)
             DO UPDATE SET completed=1,updated_at=excluded.updated_at''',
          [syllabusId, topicId, _now],
        );
        if (reviewTopicIds.contains(topicId)) {
          final dueDate = DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String()
              .substring(0, 10);
          await database.customStatement(
            '''INSERT INTO topic_reviews
               (syllabus_id,topic_id,activity_id,due_date,status,created_at)
               SELECT ?,?,?,?,'pending',?
               WHERE NOT EXISTS (
                 SELECT 1 FROM topic_reviews
                 WHERE syllabus_id=? AND topic_id=? AND status='pending'
               )''',
            [
              syllabusId,
              topicId,
              activityId,
              dueDate,
              _now,
              syllabusId,
              topicId,
            ],
          );
        }
      }
    });
  }

  Future<int> createManualSession(
    int activityId,
    String date,
    int seconds, {
    int questions = 0,
    int correct = 0,
    String? notes,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (date.compareTo(today) > 0) {
      throw ArgumentError('A data da sessão não pode estar no futuro.');
    }
    if (seconds <= 0 || correct < 0 || questions < 0 || correct > questions) {
      throw ArgumentError('Dados da sessão inválidos.');
    }
    return database.customInsert(
      "INSERT INTO study_sessions(activity_id,local_study_date,status,actual_seconds,accumulated_seconds,question_count,correct_count,notes,created_at,updated_at) VALUES(?,?,'finished',?,?,?,?,?,?,?)",
      variables: [
        Variable(activityId),
        Variable(date),
        Variable(seconds),
        Variable(seconds),
        Variable(questions),
        Variable(correct),
        Variable(notes),
        Variable(_now),
        Variable(_now),
      ],
    );
  }

  Future<void> deleteSession(int id) =>
      database.customStatement('DELETE FROM study_sessions WHERE id=?', [id]);
  Future<void> updateSession(
    int id, {
    required String date,
    required int seconds,
    required int questions,
    required int correct,
    String? notes,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (date.compareTo(today) > 0 ||
        seconds <= 0 ||
        questions < 0 ||
        correct < 0 ||
        correct > questions) {
      throw ArgumentError('Dados da sessão inválidos.');
    }
    await database.customStatement(
      "UPDATE study_sessions SET local_study_date=?,actual_seconds=?,accumulated_seconds=?,question_count=?,correct_count=?,notes=?,updated_at=? WHERE id=?",
      [date, seconds, seconds, questions, correct, notes, _now, id],
    );
  }

  Future<Map<String, int>> metrics({String? dateFrom, String? dateTo}) async {
    final where = <String>[];
    final args = <Variable>[];
    if (dateFrom != null) {
      where.add('local_study_date>=?');
      args.add(Variable(dateFrom));
    }
    if (dateTo != null) {
      where.add('local_study_date<=?');
      args.add(Variable(dateTo));
    }
    final rows = await database
        .customSelect(
          'SELECT COALESCE(SUM(actual_seconds),0) AS seconds,COALESCE(SUM(question_count),0) AS questions,COALESCE(SUM(correct_count),0) AS correct FROM study_sessions WHERE status=\'finished\'${where.isEmpty ? '' : ' AND ${where.join(' AND ')}'}',
          variables: args,
        )
        .get();
    final row = rows.single;
    return {
      'seconds': row.read<int>('seconds'),
      'questions': row.read<int>('questions'),
      'correct': row.read<int>('correct'),
    };
  }

  Future<PerformanceMetrics> performance() async {
    final sessions = await metrics();
    final rows = await database
        .customSelect(
          "SELECT COALESCE(SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END),0) AS pending,COALESCE(SUM(CASE WHEN status='done' THEN 1 ELSE 0 END),0) AS done FROM activities",
        )
        .get();
    return PerformanceMetrics(
      seconds: sessions['seconds']!,
      questions: sessions['questions']!,
      correct: sessions['correct']!,
      pendingActivities: rows.single.read<int>('pending'),
      completedActivities: rows.single.read<int>('done'),
    );
  }

  Future<Map<String, PerformanceMetrics>> periods() async {
    final today = DateTime.now();
    String key(DateTime value) => value.toIso8601String().substring(0, 10);
    final startWeek = today.subtract(Duration(days: today.weekday - 1));
    final startMonth = DateTime(today.year, today.month);
    Future<PerformanceMetrics> read(String? from, String? to) async {
      final values = await metrics(dateFrom: from, dateTo: to);
      return PerformanceMetrics(
        seconds: values['seconds']!,
        questions: values['questions']!,
        correct: values['correct']!,
        pendingActivities: 0,
        completedActivities: 0,
      );
    }

    return {
      'today': await read(key(today), key(today)),
      'week': await read(key(startWeek), key(today)),
      'month': await read(key(startMonth), key(today)),
      'total': await read(null, null),
    };
  }

  Future<PlannerAnalytics> analytics({
    required DateTime from,
    required DateTime to,
  }) async {
    String key(DateTime value) => value.toIso8601String().substring(0, 10);
    final fromKey = key(from);
    final toKey = key(to);
    final sessionRows = await database
        .customSelect(
          '''SELECT local_study_date,
        COALESCE(SUM(actual_seconds),0) AS seconds,
        COALESCE(SUM(question_count),0) AS questions,
        COALESCE(SUM(correct_count),0) AS correct
        FROM study_sessions
        WHERE status='finished' AND local_study_date BETWEEN ? AND ?
        GROUP BY local_study_date ORDER BY local_study_date''',
          variables: [Variable(fromKey), Variable(toKey)],
        )
        .get();
    final byDate = <String, DailyStudyMetric>{
      for (final row in sessionRows)
        row.read<String>('local_study_date'): DailyStudyMetric(
          date: DateTime.parse(row.read<String>('local_study_date')),
          seconds: row.read<int>('seconds'),
          questions: row.read<int>('questions'),
          correct: row.read<int>('correct'),
        ),
    };
    final daily = <DailyStudyMetric>[];
    for (
      var date = DateTime(from.year, from.month, from.day);
      !date.isAfter(to);
      date = date.add(const Duration(days: 1))
    ) {
      daily.add(
        byDate[key(date)] ??
            DailyStudyMetric(date: date, seconds: 0, questions: 0, correct: 0),
      );
    }

    final taskRows = await database
        .customSelect(
          '''SELECT COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN status='done' THEN 1 ELSE 0 END),0) AS done
        FROM activities WHERE local_date BETWEEN ? AND ?''',
          variables: [Variable(fromKey), Variable(toKey)],
        )
        .get();

    final disciplineRows = await database
        .customSelect(
          '''SELECT COALESCE((
          SELECT d.name FROM activity_topics at
          JOIN subjects sub ON sub.id=at.topic_id
          JOIN disciplines d ON d.id=sub.discipline_id
          WHERE at.activity_id=a.id
          ORDER BY at.position LIMIT 1
        ), 'Sem disciplina') AS discipline,
        COALESCE(SUM(ss.actual_seconds),0) AS seconds,
        COALESCE(SUM(ss.question_count),0) AS questions,
        COALESCE(SUM(ss.correct_count),0) AS correct
        FROM study_sessions ss
        JOIN activities a ON a.id=ss.activity_id
        WHERE ss.status='finished' AND ss.local_study_date BETWEEN ? AND ?
        GROUP BY discipline ORDER BY seconds DESC, discipline LIMIT 8''',
          variables: [Variable(fromKey), Variable(toKey)],
        )
        .get();
    final disciplines = [
      for (final row in disciplineRows)
        DisciplineStudyMetric(
          name: row.read<String>('discipline'),
          seconds: row.read<int>('seconds'),
          questions: row.read<int>('questions'),
          correct: row.read<int>('correct'),
        ),
    ];

    final studiedDates = daily.where((item) => item.seconds > 0).toList();
    var streak = 0;
    var cursor = DateTime(to.year, to.month, to.day);
    final studiedKeys = studiedDates.map((item) => key(item.date)).toSet();
    if (!studiedKeys.contains(key(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (studiedKeys.contains(key(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return PlannerAnalytics(
      daily: daily,
      disciplines: disciplines,
      plannedTasks: taskRows.single.read<int>('total'),
      completedTasks: taskRows.single.read<int>('done'),
      studyDays: studiedDates.length,
      streak: streak,
    );
  }
}
