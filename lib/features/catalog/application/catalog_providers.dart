import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/application/project_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';

final catalogProvider = FutureProvider<Catalog>(retry: (count, error) => null, (
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  return CatalogRepository(database).load();
});

final catalogActionsProvider = Provider((ref) => CatalogActions(ref));

class CatalogActions {
  CatalogActions(this.ref);
  final Ref ref;
  Future<void> run(
    Future<dynamic> Function(CatalogRepository) operation,
  ) async {
    final database = await ref.read(databaseProvider.future);
    await operation(CatalogRepository(database));
    if (ref.mounted) ref.invalidate(catalogProvider);
  }
}
