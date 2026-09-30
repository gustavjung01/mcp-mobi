import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mcp_field/core/data/local_catalog_order_data_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/storage/local_data_store.dart';

class FakeCatalogClient implements OrderDataClient, CompleteOrderCatalogClient {
  var catalogLoads = 0;
  var remoteSearches = 0;

  @override
  Future<List<OrderCatalogItem>> loadCompleteCatalog() async {
    catalogLoads += 1;
    return const [
      OrderCatalogItem(
        productId: 'product-1',
        variantId: 'variant-1',
        name: 'Trà Đào Peso',
        brand: 'Peso',
        category: 'Trà sữa',
        sku: 'TD01',
        sellUnit: 'Chai',
        price: 340000,
      ),
      OrderCatalogItem(
        productId: 'product-2',
        variantId: 'variant-2',
        name: 'Siro Dâu',
        brand: 'Khác',
        category: 'Trà sữa',
        sku: 'SD02',
        sellUnit: 'Chai',
        price: 120000,
      ),
    ];
  }

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async {
    remoteSearches += 1;
    final rows = await loadCompleteCatalog();
    final term = query.trim().toLowerCase();
    return rows.where((item) {
      if (term.isNotEmpty &&
          !item.name.toLowerCase().contains(term) &&
          !(item.sku ?? '').toLowerCase().contains(term)) {
        return false;
      }
      if ((category ?? '').isNotEmpty && item.category != category) {
        return false;
      }
      if ((brand ?? '').isNotEmpty && item.brand != brand) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Future<List<FieldOrder>> loadOrders() async => const [];

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) async {
    return const FieldOrder(id: 'order-1', status: 'draft');
  }
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDataStore database;
  late LocalDataScope scope;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_catalog_client_');
    database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'mcp.db'),
    );
    scope = const LocalDataScope(
      installationKey: 'https://mcp.example.vn',
      employeeId: 'employee-1',
    );
  });

  tearDown(() async {
    await database.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('first search returns bounded remote results while full catalog warms in background', () async {
    final remote = FakeCatalogClient();
    final client = LocalCatalogOrderDataClient(
      remote: remote,
      database: database,
      scope: scope,
    );

    final results = await client.searchProducts(query: 'TD01');

    expect(results.single.variantId, 'variant-1');
    expect(results.single.price, 340000);
    expect(remote.remoteSearches, 1);

    await client.refreshCatalog();
    final second = await client.searchProducts(query: 'td01');
    expect(second.single.variantId, 'variant-1');
    expect(remote.remoteSearches, 1);
  });

  test('category and brand filters are resolved from the local catalog',
      () async {
    final remote = FakeCatalogClient();
    final client = LocalCatalogOrderDataClient(
      remote: remote,
      database: database,
      scope: scope,
    );

    final results = await client.searchProducts(
      query: '',
      category: 'Trà sữa',
      brand: 'Peso',
    );

    expect(results, hasLength(1));
    expect(results.single.sku, 'TD01');
    expect(remote.remoteSearches, 1);
    await client.refreshCatalog();
  });
}
