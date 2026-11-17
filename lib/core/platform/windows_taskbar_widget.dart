import 'dart:io';

Future<void> startWindowsTaskbarWidget() async {
  if (!Platform.isWindows) return;
  final executableDirectory = File(Platform.resolvedExecutable).parent;
  final widgetExecutable = File(
    '${executableDirectory.path}${Platform.pathSeparator}taskbar_widget${Platform.pathSeparator}TJSP.Planner.TaskbarWidget.exe',
  );
  if (!await widgetExecutable.exists()) return;
  try {
    await Process.start(
      widgetExecutable.path,
      const [],
      mode: ProcessStartMode.detached,
    );
  } on ProcessException {
    // The Planner remains usable if Windows temporarily rejects the helper.
  }
}
