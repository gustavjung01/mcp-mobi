import '../storage/local_data_store.dart';

abstract interface class RouteSelectionStore {
  Future<String?> load();

  Future<void> save(String routeId);

  Future<void> clear();
}

class LocalRouteSelectionStore implements RouteSelectionStore {
  const LocalRouteSelectionStore({
    required this.database,
    required this.scope,
  });

  final LocalDataStore database;
  final LocalDataScope scope;

  @override
  Future<String?> load() => database.loadRouteSelection(scope);

  @override
  Future<void> save(String routeId) {
    return database.saveRouteSelection(
      scope: scope,
      routeId: routeId,
    );
  }

  @override
  Future<void> clear() => database.clearRouteSelection(scope);
}
