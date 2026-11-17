import 'dart:io';
import 'dart:developer' as developer;

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

Future<AppDatabase> openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final db = AppDatabase(
    NativeDatabase.createInBackground(
      File(p.join(directory.path, 'study_planner.sqlite')),
    ),
  );
  try {
    await db.initialize();
    return db;
  } catch (error, stackTrace) {
    assert(() {
      developer.log(
        'Database initialization failed',
        error: error,
        stackTrace: stackTrace,
        name: 'study_planner.database',
      );
      return true;
    }());
    await db.close();
    rethrow;
  }
}
