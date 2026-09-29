import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/selection/route_selection_store.dart';
import 'package:mcp_field/core/storage/local_data_store.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String databasePath;
  late LocalDataScope scope;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_local_data_test_');
    databasePath = p.join(tempDir.path, 'mcp.db');
    scope = const LocalDataScope(
      installationKey: 'https://mcp.example.vn',
      employeeId: 'employee-1',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('queue draft and route selection survive database reopen', () async {
    var database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final queue = LocalMutationQueueStore(database: database, scope: scope);
    final orders = LocalOrderOfflineStore(
      database: database,
      scope: scope,
      mutationQueueStore: queue,
    );
    final routes = LocalRouteSelectionStore(database: database, scope: scope);

    const key =
        'mcp.sales-order.create-123e4567-e89b-42d3-a456-426614174000';
    await queue.save(
      QueuedMutation(
        idempotencyKey: key,
        operation: orderMutationOperation,
        entityType: 'order',
        entityLabel: 'Cửa hàng Minh Phát',
        payload: const {
          'outletId': 'outlet-1',
          'customerId': 'customer-1',
          'customerAddressId': 'address-1',
          'note': '',
          'lines': [
            {'variantId': 'variant-1', 'quantity': '2'},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 29, 1),
      ),
    );
    await orders.saveDraft(
      OrderDraft(
        outletId: 'outlet-1',
        customerId: 'customer-1',
        customerAddressId: 'address-1',
        note: 'Giao buổi sáng',
        lines: const [
          OrderDraftLine(
            product: OrderCatalogItem(
              productId: 'product-1',
              variantId: 'variant-1',
              name: 'Trà đào',
              sku: 'TD01',
            ),
            quantity: 2,
          ),
        ],
        updatedAt: DateTime.utc(2026, 9, 29, 1),
      ),
    );
    await routes.save('route-1');
    await database.dispose();

    database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final reopenedQueue =
        LocalMutationQueueStore(database: database, scope: scope);
    final reopenedOrders = LocalOrderOfflineStore(
      database: database,
      scope: scope,
      mutationQueueStore: reopenedQueue,
    );
    final reopenedRoutes =
        LocalRouteSelectionStore(database: database, scope: scope);

    final queued = await reopenedQueue.load(
      operations: const {orderMutationOperation},
    );
    expect(queued.single.idempotencyKey, key);
    expect(queued.single.payload['customerId'], 'customer-1');

    final draft = await reopenedOrders.readDraft('outlet-1');
    expect(draft, isNotNull);
    expect(draft!.lines.single.product.sku, 'TD01');
    expect(draft.lines.single.quantity, 2);
    expect(await reopenedRoutes.load(), 'route-1');

    await database.dispose();
  });

  test('catalog is replaced transactionally and searched locally', () async {
    final database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );

    await database.replaceCatalog(
      scope: scope,
      refreshedAt: DateTime.utc(2026, 9, 29, 2),
      records: const [
        {
          'productId': 'product-1',
          'variantId': 'variant-1',
          'name': 'Trà Đào Peso',
          'brand': 'Peso',
          'category': 'Trà sữa',
          'sku': 'TD01',
          'sellUnit': 'Chai',
          'price': 340000,
        },
        {
          'productId': 'product-2',
          'variantId': 'variant-2',
          'name': 'Siro Dâu',
          'brand': 'Khác',
          'category': 'Trà sữa',
          'sku': 'SD02',
          'sellUnit': 'Chai',
          'price': 120000,
        },
      ],
    );

    final byText = await database.searchCatalog(
      scope: scope,
      query: 'tra dao',
    );
    expect(byText.single['variantId'], 'variant-1');

    final bySku = await database.searchCatalog(
      scope: scope,
      query: 'td01',
      brand: 'peso',
      category: 'tra sua',
    );
    expect(bySku.single['name'], 'Trà Đào Peso');

    final state = await database.catalogState(scope);
    expect(state.count, 2);
    expect(state.refreshedAt, DateTime.utc(2026, 9, 29, 2));
    expect(
      state.isStale(
        const Duration(hours: 12),
        now: DateTime.utc(2026, 9, 29, 3),
      ),
      isFalse,
    );

    await database.replaceCatalog(
      scope: scope,
      refreshedAt: DateTime.utc(2026, 9, 29, 4),
      records: const [
        {
          'productId': 'product-3',
          'variantId': 'variant-3',
          'name': 'Topping mới',
          'category': 'Topping',
          'sku': 'TP03',
        },
      ],
    );
    final replaced = await database.searchCatalog(
      scope: scope,
      query: '',
    );
    expect(replaced.map((item) => item['variantId']), ['variant-3']);

    await database.dispose();
  });

  test('acknowledged queue is compacted without touching outstanding intents',
      () async {
    final database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final queue = LocalMutationQueueStore(database: database, scope: scope);

    for (var index = 0; index < 35; index++) {
      final key =
          'mcp.report.create-123e4567-e89b-42d3-a456-${index.toString().padLeft(12, '0')}';
      await queue.save(
        QueuedMutation(
          idempotencyKey: key,
          operation: 'mcp.report.create',
          entityType: 'report',
          entityLabel: 'Điểm bán',
          payload: const {'reportType': 'market'},
          createdAt: DateTime.utc(2026, 9, 29, 1).add(
            Duration(minutes: index),
          ),
          state: MutationQueueState.acknowledged,
          retryable: false,
          acknowledgedAt: DateTime.utc(2026, 9, 29, 2),
        ),
      );
    }
    await queue.save(
      QueuedMutation(
        idempotencyKey:
            'mcp.report.create-223e4567-e89b-42d3-a456-426614174000',
        operation: 'mcp.report.create',
        entityType: 'report',
        entityLabel: 'Điểm bán',
        payload: const {'reportType': 'market'},
        createdAt: DateTime.utc(2026, 9, 29, 5),
      ),
    );

    final rows = await queue.load();
    expect(
      rows.where((item) => item.state == MutationQueueState.acknowledged),
      hasLength(30),
    );
    expect(
      rows.where((item) => item.state == MutationQueueState.waiting),
      hasLength(1),
    );

    await database.dispose();
  });
}
