import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/router/app_router.dart';
import 'core/platform/windows_taskbar_widget.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final arg in args) {
    if (arg.startsWith('--open=')) {
      final route = arg.substring(7);
      if (route.startsWith('/')) startupRoute = route;
    }
    if (arg.startsWith('--study=')) {
      final parts = arg.substring(8).split(':');
      if (parts.length == 2 &&
          int.tryParse(parts[0]) != null &&
          int.tryParse(parts[1]) != null) {
        startupRoute = '/study/${parts[0]}/${parts[1]}';
      }
    }
  }
  await startWindowsTaskbarWidget();
  if (args.contains('--background')) return;
  runApp(const ProviderScope(child: StudyPlannerApp()));
}
