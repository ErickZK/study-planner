import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/project_providers.dart';
import '../data/syllabus_repository.dart';

final syllabusRepositoryProvider = Provider<SyllabusRepository>(
  (ref) => SyllabusRepository(ref.watch(databaseProvider).requireValue),
);

final syllabusProvider = FutureProvider.family<SyllabusSnapshot, int>((ref, projectId) async {
  await ref.watch(databaseProvider.future);
  return ref.watch(syllabusRepositoryProvider).loadForProject(projectId);
});
