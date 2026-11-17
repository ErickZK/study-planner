import '../../../features/catalog/data/catalog_repository.dart';
import '../../../features/planner/data/planner_repository.dart';
import '../../../features/schedules/data/schedule_repository.dart';
import '../../../features/syllabus/data/syllabus_repository.dart';
import '../app_database.dart';
import 'tjsp_2026_material_data.dart';

const _prefix = 'tjsp-2026-material-';
const _scheduleName = 'Cronograma diário TJSP 2026';

class TjspMaterialImportResult {
  const TjspMaterialImportResult({
    required this.scheduleId,
    required this.disciplines,
    required this.topics,
    required this.activities,
    required this.alreadyImported,
  });

  final int scheduleId;
  final int disciplines;
  final int topics;
  final int activities;
  final bool alreadyImported;
}

/// Imports the complete user-supplied TJSP edital and 19-week study schedule.
///
/// Deterministic catalog identities make this safe to repeat. When upgrading an
/// earlier partial import, existing activities are updated in place so their
/// completion state and study sessions remain attached.
class Tjsp2026MaterialSeed {
  Tjsp2026MaterialSeed(this.database);

  final AppDatabase database;

  Future<TjspMaterialImportResult> importIntoProject(
    int projectId, {
    DateTime? startDate,
  }) => database.transaction(() async {
    final catalog = CatalogRepository(database);
    final topicIds = <String>{};
    final disciplineIds = <String>{};
    for (
      var disciplineIndex = 0;
      disciplineIndex < tjspMaterialData.length;
      disciplineIndex++
    ) {
      final discipline = tjspMaterialData[disciplineIndex];
      final disciplineId =
          '$_prefix'
          'discipline-${disciplineIndex + 1}';
      disciplineIds.add(disciplineId);
      await catalog.insertDisciplineWithId(
        disciplineId,
        discipline.name,
        description:
            'Conteúdo integral importado do edital TJSP 2026 fornecido pelo usuário.',
      );
      for (
        var topicIndex = 0;
        topicIndex < discipline.topics.length;
        topicIndex++
      ) {
        final topicId =
            '$_prefix'
            'topic-${disciplineIndex + 1}-${topicIndex + 1}';
        final fullTopic = discipline.topics[topicIndex];
        topicIds.add(topicId);
        await catalog.insertSubjectWithId(
          topicId,
          disciplineId,
          null,
          _topicName(fullTopic),
          description: fullTopic.length > 120 ? fullTopic : null,
          position: topicIndex,
        );
      }
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final placeholders = List.filled(topicIds.length, '?').join(',');
    await database.customStatement(
      'UPDATE subjects SET deleted_at=?,updated_at=? '
      'WHERE id LIKE ? AND id NOT IN ($placeholders)',
      [now, now, '$_prefix%', ...topicIds],
    );
    final schedules = ScheduleRepository(database);
    final existing = (await schedules.list(
      projectId,
    )).where((schedule) => schedule.name == _scheduleName).firstOrNull;
    final scheduleId =
        existing?.id ??
        await schedules.create(
          projectId,
          _scheduleName,
          dailyMinutes: 150,
          breakMinutes: 10,
        );
    if (existing != null) {
      await schedules.update(
        scheduleId,
        dailyMinutes: 150,
        breakMinutes: 10,
        archived: false,
      );
    }
    await SyllabusRepository(
      database,
    ).replaceSelection(scheduleId, disciplineIds, topicIds);

    final planner = PlannerRepository(database);
    final activitiesBefore = await planner.listRange(
      scheduleId,
      '2000-01-01',
      '2100-12-31',
    );
    final importedActivityCount = tjspScheduleWeeks.fold<int>(
      0,
      (weekTotal, week) =>
          weekTotal +
          week.fold<int>(0, (dayTotal, day) => dayTotal + day.length),
    );
    final wasComplete =
        existing != null && activitiesBefore.length >= importedActivityCount;

    final monday = _startMonday(
      startDate ??
          (activitiesBefore.isEmpty
              ? DateTime.now()
              : DateTime.parse(activitiesBefore.first.date)),
    );
    for (var weekIndex = 0; weekIndex < tjspScheduleWeeks.length; weekIndex++) {
      final week = tjspScheduleWeeks[weekIndex];
      for (var dayIndex = 0; dayIndex < week.length; dayIndex++) {
        final date = monday.add(
          Duration(days: (weekIndex * DateTime.daysPerWeek) + dayIndex),
        );
        final dateKey = date.toIso8601String().substring(0, 10);
        final currentDay = await planner.list(scheduleId, dateKey);
        final tasks = week[dayIndex];
        final baseMinutes = 150 ~/ tasks.length;
        for (var taskIndex = 0; taskIndex < tasks.length; taskIndex++) {
          final minutes = taskIndex == tasks.length - 1
              ? 150 - (baseMinutes * (tasks.length - 1))
              : baseMinutes;
          if (taskIndex < currentDay.length) {
            await planner.updateActivity(
              currentDay[taskIndex].id,
              title: tasks[taskIndex],
              date: dateKey,
              plannedMinutes: minutes,
            );
          } else {
            await planner.create(
              scheduleId,
              dateKey,
              tasks[taskIndex],
              plannedMinutes: minutes,
            );
          }
        }
      }
    }

    return TjspMaterialImportResult(
      scheduleId: scheduleId,
      disciplines: tjspMaterialData.length,
      topics: topicIds.length,
      activities: importedActivityCount,
      alreadyImported: wasComplete,
    );
  });

  DateTime _startMonday(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _topicName(String value) {
    if (value.length <= 120) return value;
    const limit = 117;
    var cut = value.lastIndexOf(RegExp(r'[;,.]'), limit);
    if (cut < 80) cut = value.lastIndexOf(' ', limit);
    if (cut < 1) cut = limit;
    return '${value.substring(0, cut).trim()}…';
  }
}
