import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/dashboard/application/dashboard_provider.dart';
import 'package:study_planner/features/planner/data/planner_repository.dart';
import 'package:study_planner/features/projects/application/project_providers.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_repository.dart';

void main() {
  test(
    'dashboard reflects the active schedule and recorded study time',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      await ProjectRepository(db).create('Projeto de teste');
      final project = (await ProjectRepository(db).list()).single;
      final scheduleId = await ScheduleRepository(
        db,
      ).create(project.id, 'Manhã', dailyMinutes: 180);
      final day = localDate(DateTime.now());
      final planner = PlannerRepository(db);
      final completed = await planner.create(
        scheduleId,
        day,
        'Português',
        plannedMinutes: 60,
      );
      await planner.setStatus(completed, 'done');
      await planner.createManualSession(completed, day, 1800);
      final next = await planner.create(
        scheduleId,
        day,
        'Direito Administrativo',
        plannedMinutes: 120,
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(dashboardProvider.future);
      expect(snapshot.schedule?.id, scheduleId);
      expect(snapshot.activities.length, 2);
      expect(snapshot.done, 1);
      expect(snapshot.todaySeconds, 1800);
      expect(snapshot.next?.id, next);
    },
  );
}
