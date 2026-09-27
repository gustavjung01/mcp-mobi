import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/location/field_location.dart';

const route = FieldRoute(
  id: 'route-1',
  name: 'Tuyến Quận 1',
  area: 'Quận 1',
  salesOwner: 'Nguyễn Văn A',
  plannedCustomers: 1,
  visitedCustomers: 0,
  orderCount: 0,
  status: 'active',
);

const customer = FieldRouteCustomer(
  id: 'customer-1',
  routeId: 'route-1',
  routeName: 'Tuyến Quận 1',
  accountId: 'DP00123',
  accountName: 'Cửa hàng Minh Phát',
  contactName: 'Anh Minh',
  area: 'Quận 1',
  sortOrder: 1,
  status: 'active',
  note: '',
);

const outlet = FieldOutlet(
  id: 'outlet-1',
  routeId: 'route-2',
  routeName: 'Tuyến Quận 3',
  code: 'MCP001',
  name: 'Đại lý An Phát',
  phone: '0909000111',
  area: 'Quận 3',
  address: '456 Lê Lợi',
  status: 'linked_existing',
  note: 'Khách MCP',
);

const line = FieldDayLine(
  id: 'line-1',
  sessionCustomerId: 'line-1',
  routeCustomerId: 'customer-1',
  sortOrder: 1,
  accountName: 'Cửa hàng Minh Phát',
  phone: '0903123456',
  address: '123 Nguyễn Văn Cừ',
  area: 'Quận 1',
  source: 'planned',
  status: 'pending',
  note: '',
  hasOrder: false,
  hasTest: false,
  hasReport: false,
  followupCount: 0,
  checkedIn: false,
);

const day = FieldDayData(
  sessionOpened: true,
  run: FieldDayRun(
    id: 'session-1',
    routeId: 'route-1',
    routeName: 'Tuyến Quận 1',
    date: '2026-09-27',
    owner: 'Nguyễn Văn A',
    status: 'opened',
    openedAt: '08:00',
  ),
  lines: [line],
);

const workspace = FieldRouteWorkspace(
  route: route,
  customers: [customer],
  day: day,
);

const session = MobileSession(
  token: 'nppusr.test-token',
  employeeId: '11111111-1111-4111-8111-111111111111',
  loginName: 'staff.test',
  displayName: 'Nguyễn Văn A',
  expiresAt: null,
);

class FakeFieldDataClient implements FieldDataClient, FieldActionClient {
  bool checkInCalled = false;
  bool addCustomerCalled = false;
  bool failFirstAddCustomer = false;
  String? addCustomerKey;
  final List<String> addCustomerKeys = [];

  @override
  Future<List<FieldRoute>> loadRoutes() async => const [route];

  @override
  Future<List<FieldOutlet>> loadOutlets() async => const [outlet];

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) async {
    return workspace;
  }

  @override
  Future<void> openRouteSession({
    required String routeId,
    required DateTime date,
    required String owner,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> finishRouteSession({
    required String sessionId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<FieldAddedCustomer> addSessionCustomer({
    required String sessionId,
    required String customerName,
    required String phone,
    required String area,
    required String address,
    required String note,
    double? latitude,
    double? longitude,
    double? accuracy,
    required String idempotencyKey,
  }) async {
    addCustomerCalled = true;
    addCustomerKey = idempotencyKey;
    addCustomerKeys.add(idempotencyKey);
    expect(sessionId, 'session-1');
    expect(customerName, 'Cửa hàng Mới');
    if (failFirstAddCustomer && addCustomerKeys.length == 1) {
      throw const FieldDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng tạm thời gián đoạn. Vui lòng thử lại.',
        retryable: true,
      );
    }
    return const FieldAddedCustomer(
      routeCustomerId: 'customer-new',
      sessionCustomerId: 'line-new',
    );
  }

  @override
  Future<void> setSessionCustomerCheckIn({
    required String sessionCustomerId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String idempotencyKey,
  }) async {
    checkInCalled = true;
    expect(sessionCustomerId, 'line-1');
    expect(latitude, 10.75);
    expect(longitude, 106.67);
  }
}

class FakeLocationProvider implements FieldLocationProvider {
  @override
  Future<FieldLocation> current() async {
    return const FieldLocation(
      latitude: 10.75,
      longitude: 106.67,
      accuracy: 8,
    );
  }
}

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> revealAddCustomerSubmit(WidgetTester tester) async {
  final screen = find.byKey(const Key('route-add-customer-screen'));
  final list = find.descendant(
    of: screen,
    matching: find.byType(ListView),
  );
  final submit = find.byKey(const Key('route-add-customer-submit'));

  for (var attempt = 0; attempt < 5 && submit.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }

  expect(submit, findsOneWidget);
}

void main() {
  testWidgets('outlet directory is independent from route today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Điểm bán'));
    await tester.pumpAndSettle();

    expect(find.text('Đại lý An Phát'), findsOneWidget);
    expect(find.text('Cửa hàng Minh Phát'), findsNothing);

    await tester.tap(find.byKey(const Key('outlet-row-outlet-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-detail-screen')), findsOneWidget);
    expect(find.text('0909000111'), findsOneWidget);
    expect(find.text('456 Lê Lợi'), findsOneWidget);
    expect(find.text('Tuyến Quận 3'), findsWidgets);
    expect(find.text('Quận 3'), findsWidgets);
    expect(find.byKey(const Key('outlet-checkin-button')), findsNothing);
  });

  testWidgets('today next outlet keeps active route context', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(),
          fieldLocationProvider: FakeLocationProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextOutlet = find.byKey(const Key('today-next-outlet-button'));
    await tester.ensureVisible(nextOutlet);
    await tester.tap(nextOutlet);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-detail-screen')), findsOneWidget);
    expect(find.byKey(const Key('outlet-checkin-button')), findsOneWidget);
  });

  testWidgets('field staff can add a customer to the active route session', (
    WidgetTester tester,
  ) async {
    final client = FakeFieldDataClient();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: client,
          fieldLocationProvider: FakeLocationProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('route-add-customer-button'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-add-customer-screen')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('route-add-customer-name')),
      'Cửa hàng Mới',
    );
    await revealAddCustomerSubmit(tester);
    final submit = find.byKey(const Key('route-add-customer-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.addCustomerCalled, isTrue);
    expect(client.addCustomerKey, startsWith('session-customer.add-'));
    expect(find.byKey(const Key('routes-screen')), findsOneWidget);
  });

  testWidgets('retrying the same add-customer intent reuses its key', (
    WidgetTester tester,
  ) async {
    final client = FakeFieldDataClient()..failFirstAddCustomer = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: client,
          fieldLocationProvider: FakeLocationProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('route-add-customer-button'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('route-add-customer-name')),
      'Cửa hàng Mới',
    );
    await revealAddCustomerSubmit(tester);
    final submit = find.byKey(const Key('route-add-customer-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Mạng tạm thời gián đoạn. Vui lòng thử lại.'),
      findsOneWidget,
    );
    await revealAddCustomerSubmit(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.addCustomerKeys, hasLength(2));
    expect(client.addCustomerKeys[1], client.addCustomerKeys[0]);
    expect(find.byKey(const Key('routes-screen')), findsOneWidget);
  });

  testWidgets('check-in is only available from active route context', (
    WidgetTester tester,
  ) async {
    final client = FakeFieldDataClient();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: client,
          fieldLocationProvider: FakeLocationProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-line-line-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-checkin-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('outlet-checkin-button')));
    await tester.pumpAndSettle();

    expect(client.checkInCalled, isTrue);
    expect(find.text('Đã check-in'), findsWidgets);
  });
}
