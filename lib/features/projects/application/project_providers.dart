import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/open_database.dart';
import '../data/project_repository.dart';

final databaseProvider = FutureProvider<AppDatabase>(
  retry: (count, error) => null,
  (ref) async {
    final db = await openDatabase();
    if (!ref.mounted) {
      await db.close();
      throw StateError('Inicialização cancelada.');
    }
    ref.onDispose(() {
      db.close();
    });
    return db;
  },
);
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider).requireValue),
);
final projectsProvider = FutureProvider<List<Project>>((ref) async {
  await ref.watch(databaseProvider.future);
  return ref.watch(projectRepositoryProvider).list();
});
