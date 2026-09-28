import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/sync/customer_boundary_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
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

class MemoryMutationQueueStore implements MutationQueueStore {
  final Map<String, QueuedMutation> items = {};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = items.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    items.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    items[mutation.idempotencyKey] = mutation;
  }
}

void main() {
  testWidgets('queued onboarding intent survives and reuses canonical key', (
    WidgetTester tester,
  ) async {
    final client = FakeCustomerBoundaryClient();
    final queue = MemoryMutationQueueStore();
    final service = CustomerBoundarySubmissionService(
      client: client,
      queue: queue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOnboardingPage(
          client: client,
          submissionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.byKey(
      const Key('customer-submit-route-customer-1'),
    );
    expect(submit, findsOneWidget);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Đã lưu thao tác chờ gửi. Ứng dụng sẽ tự đồng bộ lại.'),
      findsOneWidget,
    );
    expect(client.submitKeys, hasLength(1));
    expect(
      client.submitKeys.single,
      matches(RegExp(r'^[A-Za-z0-9._-]+

    final firstKey = client.submitKeys.single;
    final result = await CustomerBoundarySyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(result.sent, 1);
    expect(result.remaining, 0);
    expect(client.submitKeys, [firstKey, firstKey]);
  });
}
)),
    );

    final firstKey = client.submitKeys.single;
    final result = await CustomerBoundarySyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(result.sent, 1);
    expect(result.remaining, 0);
    expect(client.submitKeys, [firstKey, firstKey]);
  });
}
