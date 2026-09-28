import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';
import 'package:mcp_field/features/orders/create_order_page.dart';

const testOutlet = FieldOutlet(
  id: 'route-customer-1',
  routeId: 'route-1',
  routeName: 'Tuyến Quận 1',
  code: 'MCP001',
  name: 'Cửa hàng Minh Phát',
  phone: '0903000111',
  area: 'Quận 1',
  address: '123 Nguyễn Văn Cừ',
  status: 'linked_existing',
  note: '',
  coreCustomerId: '11111111-1111-4111-8111-111111111111',
  coreCustomerAddressId: '22222222-2222-4222-8222-222222222222',
  coreCustomerCode: 'DP00123',
);

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

class FakeOrderClient implements OrderDataClient {
  final keys = <String>[];

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async {
    return const [
      OrderCatalogItem(
        productId: 'product-1',
        variantId: 'variant-1',
        name: 'Trà đào',
        sku: 'TD01',
        sellUnit: 'CHAI',
        price: 125000,
      ),
    ];
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
    keys.add(idempotencyKey);
    expect(customerId, testOutlet.coreCustomerId);
    expect(customerAddressId, testOutlet.coreCustomerAddressId);
    expect(lines.single.variantId, 'variant-1');
    expect(lines.single.quantity, 1);
    if (keys.length == 1) {
      throw const OrderDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng tạm thời gián đoạn. Vui lòng thử lại.',
        retryable: true,
      );
    }
    return const FieldOrder(
      id: 'order-1',
      number: 'SO-001',
      status: 'draft',
    );
  }
}

void main() {
  testWidgets('retrying the same order reuses canonical idempotency key', (
    WidgetTester tester,
  ) async {
    final client = FakeOrderClient();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateOrderPage(
          outlet: testOutlet,
          orderClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-add-variant-1')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('order-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-order-screen')), findsOneWidget);
    expect(client.keys, hasLength(1));
    expect(client.keys.single, startsWith('mcp.sales-order.create-'));

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.keys, hasLength(2));
    expect(client.keys[1], client.keys[0]);
    expect(find.byKey(const Key('create-order-screen')), findsNothing);
  });

  testWidgets('retryable order failure is persisted as one pending intent', (
    WidgetTester tester,
  ) async {
    final client = FakeOrderClient();
    final store = MemoryOrderOfflineStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateOrderPage(
          outlet: testOutlet,
          orderClient: client,
          offlineStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-add-variant-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order-submit')));
    await tester.pumpAndSettle();

    expect(client.keys, hasLength(1));
    final queued = store.mutations.values.single;
    expect(queued.idempotencyKey, client.keys.single);
    expect(queued.state, OrderQueueState.failed);
    expect(queued.retryable, isTrue);
    expect(queued.retryCount, 1);
    expect(find.byKey(const Key('create-order-screen')), findsNothing);
  });
}
