import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:study_planner/app/app.dart';
import 'package:study_planner/app/router/app_router.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/projects/application/project_providers.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('catalog create, edit, tree, search and delete at $size', (
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
      container.read(routerProvider).go('/disciplines');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const StudyPlannerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma disciplina cadastrada.'), findsOneWidget);
      await tester.tap(find.text('Nova disciplina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um nome.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Português');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Português'), findsOneWidget);
      await tester.tap(find.byTooltip('Ações de Português'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo assunto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Gramática');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Gramática'), findsOneWidget);
      await tester.tap(find.byTooltip('Ações de Gramática'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo subassunto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Verbos');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Verbos'), findsOneWidget);
      await tester.tap(find.byTooltip('Recolher assunto'));
      await tester.pumpAndSettle();
      expect(find.text('Verbos'), findsNothing);
      await tester.tap(find.byTooltip('Expandir assunto').first);
      await tester.pumpAndSettle();
      expect(find.text('Verbos'), findsOneWidget);
      await tester.tap(find.byTooltip('Ações de Português'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar disciplina'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Linguagens');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma disciplina encontrada.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações de Linguagens'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir disciplina'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 assunto(s)'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect((await CatalogRepository(db).load()).subjects.length, 2);
      await tester.tap(find.byTooltip('Ações de Linguagens'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir disciplina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma disciplina cadastrada.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
