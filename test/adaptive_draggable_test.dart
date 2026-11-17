import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:study_planner/app/widgets/planner_ui.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Widget subject() => const MaterialApp(
    home: Scaffold(
      body: AdaptiveDraggable<String>(
        data: 'item',
        feedback: Text('feedback'),
        child: Text('item'),
      ),
    ),
  );

  testWidgets('starts dragging immediately with a mouse', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(subject());
    expect(find.byType(Draggable<String>), findsOneWidget);
    expect(find.byType(LongPressDraggable<String>), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps long press dragging on touch devices', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(subject());
    expect(find.byType(LongPressDraggable<String>), findsOneWidget);
    expect(find.byType(Draggable<String>), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
