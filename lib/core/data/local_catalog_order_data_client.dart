import 'dart:async';

import 'order_data_client.dart';
import '../storage/local_data_store.dart';

class LocalCatalogOrderDataClient implements OrderDataClient, OrderCatalogPriceClient {
  LocalCatalogOrderDataClient({
    required this.remote,
    required this.database,
    required this.scope,
    this.refreshAfter = const Duration(hours: 12),
  });

  final OrderDataClient remote;
  final LocalDataStore database;
  final LocalDataScope scope;
  final Duration refreshAfter;

  Future<void>? _refreshing;

  Future<void> refreshCatalog() {
    final current = _refreshing;
    if (current != null) return current;

    final source = remote;
    if (source is! CompleteOrderCatalogClient) {
      return Future<void>.value();
    }
    final catalogSource = source as CompleteOrderCatalogClient;

    late Future<void> future;
    future = () async {
      final items = await catalogSource.loadCompleteCatalog();
      await database.replaceCatalog(
        scope: scope,
        records: items.map((item) => item.toJson()).toList(growable: false),
        refreshedAt: DateTime.now().toUtc(),
      );
    }().whenComplete(() {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    });
    _refreshing = future;
    return future;
  }

  Future<CatalogCacheState> catalogState() => database.catalogState(scope);

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async {
    var state = await database.catalogState(scope);
    if (state.count == 0) {
      final source = remote;
      if (source is! CompleteOrderCatalogClient) {
        return remote.searchProducts(
          query: query,
          category: category,
          brand: brand,
        );
      }
      await refreshCatalog();
      state = await database.catalogState(scope);
    } else if (state.isStale(refreshAfter)) {
      unawaited(
        refreshCatalog().catchError((_) {
          // Cached catalog remains usable when background refresh fails.
        }),
      );
    }

    final rows = await database.searchCatalog(
      scope: scope,
      query: query,
      category: category,
      brand: brand,
    );
    return rows
        .map(OrderCatalogItem.fromJson)
        .where(
          (item) =>
              item.productId.isNotEmpty &&
              item.variantId.isNotEmpty &&
              item.name.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, double?>> loadFreshPrices({
    required String query,
    String? category,
    String? brand,
  }) async {
    final source = remote;
    if (source is OrderCatalogPriceClient) {
      final priceSource = source as OrderCatalogPriceClient;
      return priceSource.loadFreshPrices(
        query: query,
        category: category,
        brand: brand,
      );
    }
    final items = await remote.searchProducts(
      query: query,
      category: category,
      brand: brand,
    );
    return {for (final item in items) item.variantId: item.price};
  }

  @override
  Future<List<FieldOrder>> loadOrders() => remote.loadOrders();

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) {
    return remote.createOrder(
      customerId: customerId,
      customerAddressId: customerAddressId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      note: note,
    );
  }
}
