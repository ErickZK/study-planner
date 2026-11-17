import 'dart:io';

import 'package:flutter/services.dart';

const _androidWidgetChannel = MethodChannel('tjsp_planner/android_widget');

Future<void> refreshAndroidHomeWidget() async {
  if (!Platform.isAndroid) return;
  await _androidWidgetChannel.invokeMethod<void>('refresh');
}

Future<bool> requestAndroidHomeWidget() async {
  if (!Platform.isAndroid) return false;
  return await _androidWidgetChannel.invokeMethod<bool>('pin') ?? false;
}
