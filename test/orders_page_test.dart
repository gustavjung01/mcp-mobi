import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/features/orders/orders_page.dart';

class FakeOrderDataClient implements OrderDataClient {
  FakeOrderDataClient(this.orders);

  final List<FieldOrder> orders;

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<FieldOrder>> loadOrders() async => orders;

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async => const [];
}

const customer = CompanyCustomer(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Đại lý An Phát',
  status: 'active',
  customerCode: 'KH001',
  phone: '0909000111',
  defaultAddressId: '22222222-2222-4222-8222-222222222222',
  defaultAddressLine1: '456 Lê Lợi',
);

FieldOrder detailedOrder({
  String id = 'order-1',
  String status = 'confirmed',
  String createdAt = '2026-09-28T08:00:00Z',
}) {
  return FieldOrder(
    id: id,
    number: 'SO-$id',
    status: status,
    sourceType: 'MCP',
    customerId: customer.id,
    customerCode: customer.customerCode,
    customerName: customer.name,
    createdAt: createdAt,
    currentVersionNumber: '2',
    total: 125000,
    versions: const [
      FieldOrderVersion(
        versionNumber: '1',
        status: 'superseded',
        subtotal: 100000,
        total: 100000,
        createdAt: '2026-09-27T08:00:00Z',
        lines: [
          FieldOrderLine(
            id: 'line-old',
            variantId: 'variant-1',
            itemName: 'Trà đào',
            sku: 'TD01',
            unitCode: 'CHAI',
            unitName: 'Chai',
            quantity: 1,
            unitPrice: 100000,
            lineTotal: 100000,
          ),
        ],
      ),
      FieldOrderVersion(
        versionNumber: '2',
        status: 'confirmed',
        subtotal: 125000,
        total: 125000,
        createdAt: '2026-09-28T08:00:00Z',
        lines: [
          FieldOrderLine(
            id: 'line-1',
            variantId: 'variant-1',
            itemName: 'Trà đào',
            sku: 'TD01',
            unitCode: 'CHAI',
            unitName: 'Chai',
            quantity: 2,
            unitPrice: 62500,
            lineTotal: 125000,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('orders tab creates directly from an eligible Company customer', (
    tester,
  ) async {
    CompanyCustomer? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersPage(
          orderClient: FakeOrderDataClient(const []),
          companyCustomers: const [customer],
          onCreateOrder: (value) async {
            selected = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('orders-create')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khách Công Ty'), findsOneWidget);

    await tester.tap(find.byKey(Key('orders-customer-${customer.id}')));
    await tester.pumpAndSettle();

    expect(selected?.id, customer.id);
  });

  testWidgets('orders tab filters by period and status', (tester) async {
    final orders = [
      detailedOrder(id: 'new', status: 'confirmed'),
      detailedOrder(
        id: 'old',
        status: 'draft',
        createdAt: '2026-06-01T08:00:00Z',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersPage(orderClient: FakeOrderDataClient(orders)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-row-new')), findsOneWidget);
    expect(find.byKey(const Key('order-row-old')), findsNothing);

    await tester.tap(find.byKey(const Key('orders-period-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-row-old')), findsOneWidget);

    await tester.tap(find.byKey(const Key('orders-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nháp').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-row-new')), findsNothing);
    expect(find.byKey(const Key('order-row-old')), findsOneWidget);
  });

  testWidgets('order detail shows current version and real line information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersPage(
          orderClient: FakeOrderDataClient([detailedOrder()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-row-order-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-detail-sheet')), findsOneWidget);
    expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    expect(find.text('Trà đào'), findsOneWidget);
    expect(find.text('2 Chai × 62.500 đ'), findsOneWidget);
    expect(find.text('125.000 đ'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Lịch sử phiên bản'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử phiên bản'), findsOneWidget);
    expect(find.text('Phiên bản 2 · Hiện tại'), findsOneWidget);
    expect(find.text('Phiên bản 1'), findsOneWidget);
  });

  testWidgets('orders tab routes missing customer setup to onboarding', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersPage(
          orderClient: FakeOrderDataClient(const []),
          companyCustomers: const [],
          onCreateOrder: (_) async {},
          onCustomerOnboarding: () async {
            opened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('orders-create')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có khách sẵn sàng ra đơn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orders-open-onboarding')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}
