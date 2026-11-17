import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/planner_repository.dart';
import '../../projects/application/project_providers.dart';
import '../../schedules/data/schedule_repository.dart';

class DashboardData {
  const DashboardData({
    required this.schedule,
    required this.activities,
    required this.todaySeconds,
    required this.weekSeconds,
    required this.weekDays,
    required this.streak,
    required this.reviews,
    required this.syllabusTotal,
    required this.syllabusDone,
    required this.scheduleTotal,
    required this.scheduleDone,
    required this.monthQuestions,
  });
  final StudySchedule? schedule;
  final List<PlannedActivity> activities;
  final int todaySeconds, weekSeconds, streak, reviews;
  final int syllabusTotal, syllabusDone, scheduleTotal, scheduleDone;
  final int monthQuestions;
  final List<int> weekDays;
  PlannedActivity? get next {
    for (final activity in activities) {
      if (activity.status != 'done') return activity;
    }
    return null;
  }

  int get done => activities.where((item) => item.status == 'done').length;
}

String localDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final schedules = await ScheduleRepository(db).listAll();
  final active = schedules.where((s) => !s.archived).toList();
  final schedule = active.isEmpty ? null : active.first;
  final today = DateTime.now();
  final day = localDate(today);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final weekStart = localDate(monday);
  final activities = schedule == null
      ? <PlannedActivity>[]
      : await PlannerRepository(db).list(schedule.id, day);
  final sessions = await db
      .customSelect(
        "SELECT s.local_study_date,COALESCE(SUM(s.actual_seconds),0) AS seconds FROM study_sessions s JOIN activities a ON a.id=s.activity_id WHERE s.status='finished' AND a.schedule_id=? AND s.local_study_date>=? AND s.local_study_date<=? GROUP BY s.local_study_date",
        variables: [
          Variable(schedule?.id ?? -1),
          Variable(weekStart),
          Variable(day),
        ],
      )
      .get();
  final byDay = {
    for (final row in sessions)
      row.read<String>('local_study_date'): row.read<int>('seconds'),
  };
  final days = [
    for (var i = 0; i < 7; i++)
      byDay[localDate(monday.add(Duration(days: i)))] ?? 0,
  ];
  final history = await db
      .customSelect(
        "SELECT DISTINCT s.local_study_date FROM study_sessions s JOIN activities a ON a.id=s.activity_id WHERE s.status='finished' AND s.actual_seconds>0 AND a.schedule_id=? ORDER BY s.local_study_date DESC",
        variables: [Variable(schedule?.id ?? -1)],
      )
      .get();
  final studied = history
      .map((r) => r.read<String>('local_study_date'))
      .toSet();
  var cursor = today;
  if (!studied.contains(day)) cursor = today.subtract(const Duration(days: 1));
  var streak = 0;
  while (studied.contains(localDate(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  final reviewRows = await db
      .customSelect(
        '''SELECT COUNT(*) AS count
           FROM topic_reviews review
           JOIN vertical_syllabi syllabus ON syllabus.id=review.syllabus_id
           WHERE syllabus.schedule_id=?
             AND review.status='pending' AND review.due_date<=?''',
        variables: [Variable(schedule?.id ?? -1), Variable(day)],
      )
      .get();
  final syllabusRows = await db
      .customSelect(
        '''SELECT COUNT(*) AS total,
              COALESCE(SUM(CASE WHEN p.completed=1 THEN 1 ELSE 0 END),0) AS done
       FROM syllabus_topics t
       JOIN vertical_syllabi v ON v.id=t.syllabus_id
       LEFT JOIN topic_progress p ON p.syllabus_id=t.syllabus_id AND p.topic_id=t.topic_id
       WHERE v.schedule_id=?
         AND NOT EXISTS (
           SELECT 1 FROM syllabus_topics child
           WHERE child.syllabus_id=t.syllabus_id
             AND child.parent_topic_id=t.topic_id
         )''',
        variables: [Variable(schedule?.id ?? -1)],
      )
      .getSingle();
  final scheduleRows = await db
      .customSelect(
        '''SELECT COUNT(*) AS total,
              COALESCE(SUM(CASE WHEN status='done' THEN 1 ELSE 0 END),0) AS done
       FROM activities WHERE schedule_id=?''',
        variables: [Variable(schedule?.id ?? -1)],
      )
      .getSingle();
  final monthStart = localDate(DateTime(today.year, today.month));
  final questionRows = await db
      .customSelect(
        '''SELECT COALESCE(SUM(ss.question_count),0) AS questions
       FROM study_sessions ss
       JOIN activities a ON a.id=ss.activity_id
       WHERE a.schedule_id=? AND ss.status='finished'
         AND ss.local_study_date BETWEEN ? AND ?''',
        variables: [
          Variable(schedule?.id ?? -1),
          Variable(monthStart),
          Variable(day),
        ],
      )
      .getSingle();
  return DashboardData(
    schedule: schedule,
    activities: activities,
    todaySeconds: byDay[day] ?? 0,
    weekSeconds: days.fold(0, (a, b) => a + b),
    weekDays: days,
    streak: streak,
    reviews: reviewRows.single.read<int>('count'),
    syllabusTotal: syllabusRows.read<int>('total'),
    syllabusDone: syllabusRows.read<int>('done'),
    scheduleTotal: scheduleRows.read<int>('total'),
    scheduleDone: scheduleRows.read<int>('done'),
    monthQuestions: questionRows.read<int>('questions'),
  );
});
