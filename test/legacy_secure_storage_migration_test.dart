import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/selection/route_selection_store.dart';
import 'package:mcp_field/core/storage/legacy_secure_storage_migration.dart';
import 'package:mcp_field/core/storage/local_data_store.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

class HangingLegacySecureKeyStore implements LegacySecureKeyStore {
  @override
  Future<void> delete(String key) => Completer<void>().future;

  @override
  Future<String?> read(String key) => Completer<String?>().future;
}

class MemoryLegacySecureKeyStore implements LegacySecureKeyStore {
  final values = <String, String>{};
  final deleted = <String>[];

  @override
  Future<void> delete(String key) async {
    deleted.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDataStore database;
  late LocalDataScope scope;
  late MemoryLegacySecureKeyStore legacy;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_legacy_migration_');
    database = LocalDataStore(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'mcp.db'),
    );
    scope = const LocalDataScope(
      installationKey: 'https://mcp.example.vn',
      employeeId: 'employee-1',
    );
    legacy = MemoryLegacySecureKeyStore();
  });

  tearDown(() async {
    await database.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('legacy secure data migrates once without changing idempotency keys',
      () async {
    const key =
        'mcp.sales-order.create-123e4567-e89b-42d3-a456-426614174000';
    final mutation = QueuedMutation(
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
    );
    final draft = OrderDraft(
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
    );

    legacy.values['mcp.mutation_queue.${scope.key}'] =
        jsonEncode([mutation.toJson()]);
    legacy.values['mcp.orders.drafts.${scope.key}'] =
        jsonEncode({'outlet-1': draft.toJson()});
    legacy.values['mcp.selected_route.${scope.key}'] = 'route-1';

    final migrator = LegacySecureStorageMigrator(
      database: database,
      scope: scope,
      secureStore: legacy,
    );
    await migrator.run();

    final queue = LocalMutationQueueStore(database: database, scope: scope);
    final orders = LocalOrderOfflineStore(
      database: database,
      scope: scope,
      mutationQueueStore: queue,
    );
    final routes = LocalRouteSelectionStore(database: database, scope: scope);

    expect((await queue.load()).single.idempotencyKey, key);
    expect((await orders.readDraft('outlet-1'))!.note, 'Giao buổi sáng');
    expect(await routes.load(), 'route-1');
    expect(
      await database.readMetadata(
        scope: scope,
        key: LegacySecureStorageMigrator.migrationMetadataKey,
      ),
      'done',
    );
    expect(legacy.values, isEmpty);

    await migrator.run();
    expect((await queue.load()).single.idempotencyKey, key);
  });

  test('corrupt legacy queue is preserved and migration is not marked done',
      () async {
    final queueKey = 'mcp.mutation_queue.${scope.key}';
    legacy.values[queueKey] = '[{"broken":true}]';

    final migrator = LegacySecureStorageMigrator(
      database: database,
      scope: scope,
      secureStore: legacy,
    );

    await expectLater(
      migrator.run(),
      throwsA(isA<LegacyStorageMigrationFailure>()),
    );
    expect(legacy.values[queueKey], isNotNull);
    expect(
      await database.readMetadata(
        scope: scope,
        key: LegacySecureStorageMigrator.migrationMetadataKey,
      ),
      isNull,
    );
  });

  test('secure storage timeout never marks legacy migration complete', () async {
    final migrator = LegacySecureStorageMigrator(
      database: database,
      scope: scope,
      secureStore: HangingLegacySecureKeyStore(),
      ioTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      migrator.run(),
      throwsA(isA<LegacyStorageMigrationFailure>()),
    );
    expect(
      await database.readMetadata(
        scope: scope,
        key: LegacySecureStorageMigrator.migrationMetadataKey,
      ),
      isNull,
    );
  });

}
