import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/application/project_providers.dart';
import '../data/schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(databaseProvider).requireValue),
);
final schedulesProvider = FutureProvider.family<List<StudySchedule>, int>((
  ref,
  projectId,
) async {
  await ref.watch(databaseProvider.future);
  return ref.watch(scheduleRepositoryProvider).list(projectId);
});

final allSchedulesProvider = FutureProvider<List<StudySchedule>>((ref) async {
  await ref.watch(databaseProvider.future);
  return ref.watch(scheduleRepositoryProvider).listAll();
});

final scheduleProvider = FutureProvider.family<StudySchedule, int>((
  ref,
  id,
) async {
  await ref.watch(databaseProvider.future);
  return ref.watch(scheduleRepositoryProvider).get(id);
});
