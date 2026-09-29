import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';
import 'package:mcp_field/features/orders/create_order_page.dart';

class FakeOrderWorkflowClient
    implements OrderDataClient, OrderCatalogPriceClient {
  final keys = <String>[];
  bool failRetryable = false;

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
        name: 'Trà đào Peso',
        brand: 'Peso',
        category: 'Trà sữa',
        sku: 'TD01-L',
        variantName: 'Chai 750 ml',
        sellUnit: 'CHAI',
        price: 100000,
      ),
      OrderCatalogItem(
        productId: 'product-1',
        variantId: 'variant-2',
        name: 'Trà đào Peso',
        brand: 'Peso',
        category: 'Trà sữa',
        sku: 'TD01-T',
        variantName: 'Thùng 12 chai',
        sellUnit: 'THÙNG',
        packUnit: 'CHAI',
        packQuantity: 12,
        price: 1200000,
      ),
    ];
  }

  @override
  Future<Map<String, double?>> loadFreshPrices({
    required String query,
    String? category,
    String? brand,
  }) async {
    return const {
      'variant-1': 110000,
      'variant-2': 1250000,
    };
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
    if (failRetryable) {
      throw const OrderDataFailure(
        code: 'CORE_SALES_UNAVAILABLE',
        message:
            'Dịch vụ bán hàng Công Ty đang gián đoạn. Vui lòng thử lại.',
        retryable: true,
      );
    }
    return const FieldOrder(
      id: 'order-1',
      number: 'SO-001',
      status: 'confirmed',
      customerName: 'Đại lý An Phát',
    );
  }
}

class MemoryOrderStore implements OrderOfflineStore {
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

const outlet = FieldOutlet(
  id: 'outlet-1',
  routeId: 'route-1',
  routeName: 'Tuyến 1',
  code: 'KH001',
  name: 'Đại lý An Phát',
  phone: '0909000111',
  area: 'Quận 1',
  address: '123 Nguyễn Văn Cừ',
  status: 'linked_existing',
  note: '',
  coreCustomerId: '11111111-1111-4111-8111-111111111111',
  coreCustomerAddressId: '22222222-2222-4222-8222-222222222222',
  coreCustomerCode: 'KH001',
);

void main() {
  testWidgets(
    'order workflow is product -> cart -> review -> result',
    (tester) async {
      final client = FakeOrderWorkflowClient();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateOrderPage(
            outlet: outlet,
            orderClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-catalog-panel')), findsOneWidget);
      expect(
        find.byKey(const Key('order-product-card-product-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('order-add-variant-1')), findsOneWidget);
      expect(find.byKey(const Key('order-add-variant-2')), findsOneWidget);

      final addProduct = find.byKey(const Key('order-add-variant-1'));
      await tester.ensureVisible(addProduct);
      await tester.drag(
        find.byKey(const Key('order-catalog-panel')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(addProduct);
      await tester.pumpAndSettle();
      expect(find.text('Xem giỏ (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-cart-panel')), findsOneWidget);
      expect(find.byKey(const Key('order-cart-variant-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-review-panel')), findsOneWidget);
      expect(find.text('110.000 đ'), findsWidgets);

      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-result-created')), findsOneWidget);
      expect(find.text('SO-001'), findsOneWidget);
      expect(client.keys, hasLength(1));
      expect(client.keys.single, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
    },
  );

  testWidgets(
    'retryable submit becomes one queued intent and retry reuses its key',
    (tester) async {
      final client = FakeOrderWorkflowClient()..failRetryable = true;
      final store = MemoryOrderStore();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateOrderPage(
            outlet: outlet,
            orderClient: client,
            offlineStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addProduct = find.byKey(const Key('order-add-variant-1'));
      await tester.ensureVisible(addProduct);
      await tester.drag(
        find.byKey(const Key('order-catalog-panel')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(addProduct);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-primary-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-result-queued')), findsOneWidget);
      expect(store.mutations, hasLength(1));
      final key = store.mutations.values.single.idempotencyKey;
      expect(client.keys, [key]);

      client.failRetryable = false;
      final result = await OrderSyncService(
        client: client,
        store: store,
      ).syncPending();

      expect(result.sent, 1);
      expect(client.keys, [key, key]);
      expect(
        store.mutations[key]!.state,
        OrderQueueState.acknowledged,
      );
    },
  );
}
