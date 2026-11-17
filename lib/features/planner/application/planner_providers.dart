import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/application/project_providers.dart';
import '../data/planner_repository.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>(
  (ref) => PlannerRepository(ref.watch(databaseProvider).requireValue),
);
final activitiesProvider =
    FutureProvider.family<
      List<PlannedActivity>,
      ({int scheduleId, String date})
    >((ref, key) async {
      await ref.watch(databaseProvider.future);
      return ref
          .watch(plannerRepositoryProvider)
          .list(key.scheduleId, key.date);
    });
