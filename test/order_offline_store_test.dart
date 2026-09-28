import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

class MemoryMutationQueueStore implements MutationQueueStore {
  final rows = <String, QueuedMutation>{};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = rows.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    rows.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    rows[mutation.idempotencyKey] = mutation;
  }
}

class MemoryOrderOfflineStore implements OrderOfflineStore {
  final drafts = <String, OrderDraft>{};
  final mutations = <String, QueuedOrderMutation>{};

  @override
  Future<void> deleteDraft(String outletId) async {
    drafts.remove(outletId);
  }

  @override
  Future<List<QueuedOrderMutation>> loadMutations() async {
    return mutations.values.toList(growable: false);
  }

  @override
  Future<OrderDraft?> readDraft(String outletId) async => drafts[outletId];

  @override
  Future<void> removeMutation(String idempotencyKey) async {
    mutations.remove(idempotencyKey);
  }

  @override
  Future<void> saveDraft(OrderDraft draft) async {
    drafts[draft.outletId] = draft;
  }

  @override
  Future<void> saveMutation(QueuedOrderMutation mutation) async {
    mutations[mutation.idempotencyKey] = mutation;
  }
}

class RetryOrderClient implements OrderDataClient {
  final keys = <String>[];
  var fail = true;

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) async {
    keys.add(idempotencyKey);
    if (fail) {
      throw const OrderDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mất kết nối.',
        retryable: true,
      );
    }
    return const FieldOrder(
      id: 'order-1',
      number: 'SO-001',
      status: 'draft',
    );
  }

  @override
  Future<List<FieldOrder>> loadOrders() async => const [];

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async => const [];
}

void main() {
  test('draft JSON keeps product data needed for offline restore', () {
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
            sellUnit: 'CHAI',
            price: 125000,
          ),
          quantity: 2,
        ),
      ],
      updatedAt: DateTime.utc(2026, 9, 28, 1),
    );

    final restored = OrderDraft.fromJson(draft.toJson());

    expect(restored, isNotNull);
    expect(restored!.lines.single.product.name, 'Trà đào');
    expect(restored.lines.single.quantity, 2);
    expect(restored.note, 'Giao buổi sáng');
  });

  test(
    'secure order store writes mutations through the shared queue',
    () async {
      final queue = MemoryMutationQueueStore();
      final store = SecureOrderOfflineStore(
        installationKey: 'https://mcp.example.vn',
        employeeId: 'employee-1',
        mutationQueueStore: queue,
      );
      const key = 'mcp.sales-order.create-123e4567-e89b-42d3-a456-426614174000';
      await store.saveMutation(
        QueuedOrderMutation(
          idempotencyKey: key,
          outletId: 'outlet-1',
          outletName: 'Cửa hàng Minh Phát',
          customerId: 'customer-1',
          customerAddressId: 'address-1',
          note: '',
          lines: const [
            OrderLineInput(variantId: 'variant-1', quantity: 1),
          ],
          createdAt: DateTime.utc(2026, 9, 28, 5),
        ),
      );

      expect(queue.rows[key], isNotNull);
      expect(queue.rows[key]!.operation, orderMutationOperation);
      expect(queue.rows[key]!.entityType, 'order');

      final restored = await store.loadMutations();
      expect(restored.single.idempotencyKey, key);
      expect(restored.single.lines.single.variantId, 'variant-1');
    },
  );

  test('sync retry reuses the exact queued idempotency key', () async {
    final store = MemoryOrderOfflineStore();
    final client = RetryOrderClient();
    final key = CanonicalIdempotencyKey.create(
      'mcp.sales-order.create',
      uuid: '123e4567-e89b-42d3-a456-426614174000',
    );
    await store.saveMutation(
      QueuedOrderMutation(
        idempotencyKey: key,
        outletId: 'outlet-1',
        outletName: 'Cửa hàng Minh Phát',
        customerId: 'customer-1',
        customerAddressId: 'address-1',
        note: '',
        lines: const [
          OrderLineInput(variantId: 'variant-1', quantity: 2),
        ],
        createdAt: DateTime.utc(2026, 9, 28, 1),
      ),
    );

    final service = OrderSyncService(client: client, store: store);
    final first = await service.syncPending();
    expect(first.failed, 1);
    expect(store.mutations[key]!.retryCount, 1);

    client.fail = false;
    final second = await service.syncPending();
    expect(second.sent, 1);
    expect(client.keys, [key, key]);

    final acknowledged = store.mutations[key]!;
    expect(acknowledged.state, OrderQueueState.acknowledged);
    expect(acknowledged.serverOrderId, 'order-1');
    expect(acknowledged.serverAcknowledgedAt, isNotNull);
    expect(second.remaining, 0);
  });

  test(
    'blocked failure is not auto-retried without an explicit retry',
    () async {
      final store = MemoryOrderOfflineStore();
      final client = RetryOrderClient()..fail = false;
      final key = CanonicalIdempotencyKey.create(
        'mcp.sales-order.create',
        uuid: '223e4567-e89b-42d3-a456-426614174000',
      );
      await store.saveMutation(
        QueuedOrderMutation(
          idempotencyKey: key,
          outletId: 'outlet-1',
          outletName: 'Cửa hàng Minh Phát',
          customerId: 'customer-1',
          customerAddressId: 'address-1',
          note: '',
          lines: const [
            OrderLineInput(variantId: 'variant-1', quantity: 1),
          ],
          createdAt: DateTime.utc(2026, 9, 28, 2),
          state: OrderQueueState.failed,
          retryable: false,
          retryCount: 1,
          lastErrorCode: 'invalid_order_payload',
          lastErrorMessage: 'Thông tin đơn hàng chưa hợp lệ.',
        ),
      );

      final service = OrderSyncService(client: client, store: store);
      final automatic = await service.syncPending();
      expect(automatic.sent, 0);
      expect(client.keys, isEmpty);

      final manual = await service.syncPending(idempotencyKey: key);
      expect(manual.sent, 1);
      expect(client.keys, [key]);
    },
  );
}
