import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/app/app.dart';
import 'package:study_planner/app/router/app_router.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/projects/application/project_providers.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('starts with empty dashboard and routes at $size', (
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
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const StudyPlannerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhum projeto por enquanto.'), findsOneWidget);
      final dashboardContext = tester.element(
        find.text('Nenhum projeto por enquanto.'),
      );
      expect(
        Localizations.localeOf(dashboardContext),
        const Locale('pt', 'BR'),
      );
      expect(
        MaterialLocalizations.of(dashboardContext).cancelButtonLabel,
        'Cancelar',
      );
      expect(find.byType(Drawer), findsNothing);
      if (size.width < 840) {
        await tester.tap(find.byTooltip('Abrir navegação'));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);
        Navigator.of(tester.element(find.byType(Drawer))).pop();
        await tester.pumpAndSettle();
      }
      for (final destination in destinations.skip(1)) {
        container.read(routerProvider).go(destination.$1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(destination.$2), findsWidgets);
      }
      container.read(routerProvider).go('/projects');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Projeto real');
      await tester.tap(find.text('Salvar projeto'));
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('Projeto real'), findsOneWidget);
      expect(find.text('Nenhum projeto por enquanto.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('initialization error offers retry and recovers', (tester) async {
    var attempts = 0;
    final db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            if (attempts++ == 0) throw StateError('storage unavailable');
            return db;
          }),
        ],
        child: const StudyPlannerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível abrir os dados locais.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum projeto por enquanto.'), findsOneWidget);
  });
}
