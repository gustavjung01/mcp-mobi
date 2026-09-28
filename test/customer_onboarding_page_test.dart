import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/features/customers/customer_onboarding_page.dart';

class FakeCustomerBoundaryClient implements CustomerBoundaryClient {
  bool failFirstSubmit = true;
  final List<String> submitKeys = [];
  String status = 'not_submitted';

  CustomerVerificationItem get item => CustomerVerificationItem(
    routeCustomerId: 'route-customer-1',
    routeId: 'route-1',
    routeName: 'Tuyến 1',
    customerName: 'Điểm bán A',
    address: '1 Nguyễn Trãi',
    status: status,
    coreRequestId: status == 'not_submitted' ? null : 'request-1',
  );

  @override
  Future<List<CustomerVerificationItem>> loadVerifications() async => [item];

  @override
  Future<List<CompanyCustomer>> loadCompanyCustomers() async => const [];

  @override
  Future<CustomerVerificationItem> submit({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    submitKeys.add(idempotencyKey);
    if (failFirstSubmit) {
      failFirstSubmit = false;
      throw const CustomerBoundaryFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng đang gián đoạn.',
        retryable: true,
      );
    }
    status = 'submitted';
    return item;
  }

  @override
  Future<CustomerVerificationItem> sync({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    status = 'linked_existing';
    return item;
  }
}

void main() {
  testWidgets('retrying the same onboarding intent reuses canonical key', (
    WidgetTester tester,
  ) async {
    final client = FakeCustomerBoundaryClient();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOnboardingPage(client: client),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.byKey(
      const Key('customer-submit-route-customer-1'),
    );
    expect(submit, findsOneWidget);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Mạng đang gián đoạn.'), findsOneWidget);
    expect(client.submitKeys, hasLength(1));
    expect(
      client.submitKeys.single,
      matches(RegExp(r'^[A-Za-z0-9._-]+$')),
    );

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.submitKeys, hasLength(2));
    expect(client.submitKeys[1], client.submitKeys[0]);
    expect(find.text('Đã gửi Công Ty'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-sync-route-customer-1')),
      findsOneWidget,
    );
  });
}
