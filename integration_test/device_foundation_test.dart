import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/media/outlet_photo_pending_store.dart';
import 'package:mcp_field/core/media/outlet_photo_picker.dart';
import 'package:mcp_field/core/selection/route_selection_store.dart';
import 'package:mcp_field/core/storage/local_data_store.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device foundation persists secure and transactional data', (
    tester,
  ) async {
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final secureKey = 'mcp.l7.device.$suffix';
    const secureStorage = FlutterSecureStorage();
    final scope = LocalDataScope(
      installationKey: 'l7-device-$suffix',
      employeeId: 'employee-$suffix',
    );
    final routeId = 'route-$suffix';
    final uploadId = 'l7photo$suffix';
    final routeCustomerId = 'outlet-$suffix';

    LocalDataStore? database;
    LocalDataStore? reopened;

    try {
      await secureStorage.write(key: secureKey, value: 'persisted');
      expect(await secureStorage.read(key: secureKey), 'persisted');

      database = LocalDataStore();
      final routeStore = LocalRouteSelectionStore(
        database: database,
        scope: scope,
      );
      final queue = LocalMutationQueueStore(
        database: database,
        scope: scope,
      );

      await routeStore.save(routeId);
      final orderStore = LocalOrderOfflineStore(
        database: database,
        scope: scope,
        mutationQueueStore: queue,
      );
      await orderStore.saveDraft(
        OrderDraft(
          outletId: 'draft-$suffix',
          customerId: 'customer-$suffix',
          customerAddressId: 'address-$suffix',
          note: 'Nháp L7',
          lines: const [
            OrderDraftLine(
              product: OrderCatalogItem(
                productId: 'product-l7',
                variantId: 'variant-l7',
                name: 'Sản phẩm L7',
              ),
              quantity: 2,
            ),
          ],
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final idempotencyKey = CanonicalIdempotencyKey.create(
        'l7.device.queue',
      );
      await queue.save(
        QueuedMutation(
          idempotencyKey: idempotencyKey,
          operation: 'l7.device.queue',
          entityType: 'device_gate',
          entityLabel: 'Device gate',
          payload: {'value': 'persisted'},
          createdAt: DateTime.now().toUtc(),
        ),
      );

      const pendingStore = DeviceOutletPhotoPendingStore();
      await pendingStore.save(
        PendingOutletPhoto(
          routeCustomerId: routeCustomerId,
          customerName: 'Điểm bán kiểm thử',
          draft: OutletPhotoDraft(
            clientUploadId: uploadId,
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
            width: 2,
            height: 2,
          ),
        ),
      );

      await database.dispose();
      database = null;

      reopened = LocalDataStore();
      final reopenedRouteStore = LocalRouteSelectionStore(
        database: reopened,
        scope: scope,
      );
      final reopenedQueue = LocalMutationQueueStore(
        database: reopened,
        scope: scope,
      );

      expect(await reopenedRouteStore.load(), routeId);
      final reopenedOrderStore = LocalOrderOfflineStore(
        database: reopened,
        scope: scope,
        mutationQueueStore: reopenedQueue,
      );
      final draft = await reopenedOrderStore.readDraft('draft-$suffix');
      expect(draft, isNotNull);
      expect(draft!.note, 'Nháp L7');
      expect(draft.lines.single.quantity, 2);

      final queued = await reopenedQueue.load(
        operations: const {'l7.device.queue'},
      );
      expect(queued, hasLength(1));
      expect(queued.single.idempotencyKey, idempotencyKey);
      expect(queued.single.payload['value'], 'persisted');

      final pending = await pendingStore.load(
        routeCustomerId: routeCustomerId,
      );
      expect(pending, hasLength(1));
      expect(pending.single.draft.clientUploadId, uploadId);
      expect(pending.single.draft.bytes, isNotEmpty);

      await reopenedRouteStore.clear();
      await reopenedOrderStore.deleteDraft('draft-$suffix');
      await reopenedQueue.remove(idempotencyKey);
      await pendingStore.remove(uploadId);
    } finally {
      await secureStorage.delete(key: secureKey);
      await database?.dispose();
      await reopened?.dispose();
    }
  });
}
