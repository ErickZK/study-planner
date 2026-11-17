import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const _navigationChannel = MethodChannel('tjsp_planner/navigation');

void attachWindowsNavigation(FutureOr<void> Function(String route) onRoute) {
  if (!Platform.isWindows) return;
  _navigationChannel.setMethodCallHandler((call) async {
    if (call.method != 'openRoute') return;
    final route = call.arguments as String?;
    if (route == null || !route.startsWith('/')) return;
    await onRoute(route);
  });
}
