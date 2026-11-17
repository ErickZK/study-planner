import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/application/project_providers.dart';
import '../data/planner_repository.dart';

final performanceProvider = FutureProvider<PerformanceMetrics>((ref) async {
  await ref.watch(databaseProvider.future);
  return PlannerRepository(
    ref.watch(databaseProvider).requireValue,
  ).performance();
});

final analyticsProvider =
    FutureProvider.family<PlannerAnalytics, ({DateTime from, DateTime to})>((
      ref,
      range,
    ) async {
      await ref.watch(databaseProvider.future);
      return PlannerRepository(
        ref.watch(databaseProvider).requireValue,
      ).analytics(from: range.from, to: range.to);
    });
