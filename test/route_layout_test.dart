import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:study_planner/app/app.dart';
import 'package:study_planner/app/router/app_router.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/projects/application/project_providers.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/schedules/data/schedule_repository.dart';
import 'package:study_planner/features/planner/data/planner_repository.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final destination in destinations) {
      testWidgets('${destination.$1} has no layout exception at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase(NativeDatabase.memory());
        await db.initialize();
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        startupRoute = destination.$1;
        addTearDown(() => startupRoute = '/');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const StudyPlannerApp(),
          ),
        );
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        if (exception is FlutterError) {
          // Keeps failures actionable by reporting the exact overflowing widget.
          // ignore: avoid_print
          print(exception.toStringDeep());
        }
        expect(exception, isNull);
      });
    }

    testWidgets('calendário real não estoura em $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      await ProjectRepository(db).create('TJSP 2026');
      final project = (await ProjectRepository(db).list()).single;
      final schedule = await ScheduleRepository(
        db,
      ).create(project.id, 'Plano TJSP 2026', dailyMinutes: 150);
      final planner = PlannerRepository(db);
      final today = DateTime.now();
      final date =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await planner.create(schedule, date, 'Direito Administrativo');
      await planner.create(schedule, date, 'Língua Portuguesa');
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      startupRoute = '/planner/$schedule';
      addTearDown(() => startupRoute = '/');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const StudyPlannerApp(),
        ),
      );
      await tester.pumpAndSettle();
      final exception = tester.takeException();
      if (exception is FlutterError) {
        // ignore: avoid_print
        print(exception.toStringDeep());
      }
      expect(exception, isNull);
      expect(find.text('Plano TJSP 2026'), findsOneWidget);
    });
  }
}
