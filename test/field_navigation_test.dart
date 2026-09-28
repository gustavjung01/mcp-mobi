import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/location/field_location.dart';
import 'package:mcp_field/core/selection/route_selection_store.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/features/outlets/outlet_detail_page.dart';
import 'package:mcp_field/features/routes/routes_page.dart';

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

const routeTwo = FieldRoute(
  id: 'route-2',
  name: 'Tuyến Quận 3',
  area: 'Quận 3',
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
  coreCustomerId: '11111111-1111-4111-8111-111111111111',
  coreCustomerAddressId: '22222222-2222-4222-8222-222222222222',
  coreCustomerCode: 'KH001',
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

const unopenedDay = FieldDayData(
  sessionOpened: false,
  run: FieldDayRun(
    id: '',
    routeId: 'route-1',
    routeName: 'Tuyến Quận 1',
    date: '2026-09-27',
    owner: 'Nguyễn Văn A',
    status: 'cancelled',
    openedAt: '',
  ),
  lines: [],
);

const unopenedWorkspace = FieldRouteWorkspace(
  route: route,
  customers: [customer],
  day: unopenedDay,
);

const doneWorkspace = FieldRouteWorkspace(
  route: route,
  customers: [customer],
  day: FieldDayData(
    sessionOpened: true,
    run: FieldDayRun(
      id: 'session-1',
      routeId: 'route-1',
      routeName: 'Tuyến Quận 1',
      date: '2026-09-27',
      owner: 'Nguyễn Văn A',
      status: 'done',
      openedAt: '08:00',
    ),
    lines: [line],
  ),
);

const skippedLine = FieldDayLine(
  id: 'line-skipped',
  sessionCustomerId: 'line-skipped',
  routeCustomerId: 'customer-skipped',
  sortOrder: 2,
  accountName: 'Cửa hàng Bỏ Qua',
  area: 'Quận 1',
  source: 'planned',
  status: 'skipped',
  statusReason: 'no_demand',
  note: '',
  hasOrder: false,
  hasTest: false,
  hasReport: false,
  followupCount: 0,
  checkedIn: false,
);

const addedLine = FieldDayLine(
  id: 'line-added',
  sessionCustomerId: 'line-added',
  routeCustomerId: 'customer-added',
  sortOrder: 3,
  accountName: 'Cửa hàng Thêm Mới',
  area: 'Quận 1',
  source: 'added',
  status: 'pending',
  note: '',
  hasOrder: false,
  hasTest: false,
  hasReport: false,
  followupCount: 1,
  checkedIn: false,
);

const filterWorkspace = FieldRouteWorkspace(
  route: route,
  customers: [customer],
  day: FieldDayData(
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
    lines: [line, skippedLine, addedLine],
  ),
);

const session = MobileSession(
  token: 'nppusr.test-token',
  employeeId: '11111111-1111-4111-8111-111111111111',
  loginName: 'staff.test',
  displayName: 'Nguyễn Văn A',
  expiresAt: null,
);

class FakeFieldDataClient implements FieldDataClient, FieldActionClient {
  FakeFieldDataClient({
    this.routes = const [route],
    this.workspaceValue = workspace,
  });

  final List<FieldRoute> routes;
  final FieldRouteWorkspace workspaceValue;
  bool checkInCalled = false;
  bool addCustomerCalled = false;
  String? addCustomerKey;
  String? lastLoadedRouteId;
  final List<String> addCustomerKeys = [];
  final List<bool> checkInValues = [];
  final List<String> skipReasons = [];

  @override
  Future<List<FieldRoute>> loadRoutes() async => routes;

  @override
  Future<List<FieldOutlet>> loadOutlets() async => const [outlet];

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) async {
    lastLoadedRouteId = route.id;
    return workspaceValue;
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
    return const FieldAddedCustomer(
      routeCustomerId: 'customer-new',
      sessionCustomerId: 'line-new',
    );
  }

  @override
  Future<void> setSessionCustomerCheckIn({
    required String sessionCustomerId,
    required bool checkedIn,
    double? latitude,
    double? longitude,
    double? accuracy,
    required String idempotencyKey,
  }) async {
    checkInCalled = true;
    checkInValues.add(checkedIn);
    expect(sessionCustomerId, 'line-1');
    if (checkedIn) {
      expect(latitude, 10.75);
      expect(longitude, 106.67);
    } else {
      expect(latitude, isNull);
      expect(longitude, isNull);
    }
  }

  @override
  Future<void> setSessionCustomerStatus({
    required String sessionCustomerId,
    required String visitStatus,
    String? statusReason,
    String? note,
    required String idempotencyKey,
  }) async {
    expect(sessionCustomerId, 'line-1');
    expect(visitStatus, 'skipped');
    skipReasons.add(statusReason ?? '');
  }
}

class MemoryMutationQueueStore implements MutationQueueStore {
  final Map<String, QueuedMutation> _items = {};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = _items.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    _items.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    _items[mutation.idempotencyKey] = mutation;
  }
}

class MemoryRouteSelectionStore implements RouteSelectionStore {
  MemoryRouteSelectionStore([this.routeId]);

  String? routeId;

  @override
  Future<void> clear() async {
    routeId = null;
  }

  @override
  Future<String?> load() async => routeId;

  @override
  Future<void> save(String routeId) async {
    this.routeId = routeId;
  }
}

class FakeCustomerBoundaryClient implements CustomerBoundaryClient {
  @override
  Future<List<CustomerVerificationItem>> loadVerifications() async {
    return const [
      CustomerVerificationItem(
        routeCustomerId: 'outlet-1',
        routeId: 'route-2',
        routeName: 'Tuyến Quận 3',
        customerName: 'Đại lý An Phát',
        address: '456 Lê Lợi',
        status: 'linked_existing',
        coreRequestId: 'request-1',
        coreCustomerId: '11111111-1111-4111-8111-111111111111',
        coreCustomerAddressId: '22222222-2222-4222-8222-222222222222',
        coreCustomerCode: 'KH001',
      ),
    ];
  }

  @override
  Future<List<CompanyCustomer>> loadCompanyCustomers() async {
    return const [
      CompanyCustomer(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Đại lý An Phát',
        status: 'active',
        customerCode: 'KH001',
        phone: '0909000111',
        defaultAddressId: '22222222-2222-4222-8222-222222222222',
        defaultAddressLine1: '456 Lê Lợi',
      ),
    ];
  }

  @override
  Future<CustomerVerificationItem> submit({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    return (await loadVerifications()).single;
  }

  @override
  Future<CustomerVerificationItem> sync({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    return (await loadVerifications()).single;
  }
}

class FakeOrderDataClient implements OrderDataClient {
  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async {
    return const [];
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
  }) {
    throw UnimplementedError();
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

Future<void> revealOutletActivityAction(
  WidgetTester tester,
  Key key,
) async {
  final screen = find.byKey(const Key('outlet-detail-screen'));
  final list = find.descendant(
    of: screen,
    matching: find.byType(ListView),
  );
  final target = find.byKey(key);

  for (var attempt = 0; attempt < 6 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -320));
    await tester.pumpAndSettle();
  }

  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> revealRouteLine(WidgetTester tester) async {
  final screen = find.byKey(const Key('routes-screen'));
  final list = find.descendant(
    of: screen,
    matching: find.byType(ListView),
  );
  final target = find.byKey(const Key('route-line-line-1'));

  await tester.ensureVisible(target);
  await tester.drag(list, const Offset(0, -120));
  await tester.pumpAndSettle();
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
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
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
          mutationQueueStore: MemoryMutationQueueStore(),
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
          mutationQueueStore: MemoryMutationQueueStore(),
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

  testWidgets('outlet exposes the three field activity actions', (
    WidgetTester tester,
  ) async {
    var reports = 0;
    var trials = 0;
    var followups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OutletDetailPage(
          routeName: route.name,
          customer: customer,
          line: line,
          onCreateReport: () async {
            reports += 1;
          },
          onCreateProductTrial: () async {
            trials += 1;
          },
          onCreateFollowup: () async {
            followups += 1;
          },
        ),
      ),
    );

    const reportKey = Key('outlet-create-report');
    await revealOutletActivityAction(tester, reportKey);
    await tester.tap(find.byKey(reportKey));

    const trialKey = Key('outlet-create-product-trial');
    await revealOutletActivityAction(tester, trialKey);
    await tester.tap(find.byKey(trialKey));

    const followupKey = Key('outlet-create-followup');
    await revealOutletActivityAction(tester, followupKey);
    await tester.tap(find.byKey(followupKey));
    await tester.pump();

    expect(reports, 1);
    expect(trials, 1);
    expect(followups, 1);
  });

  testWidgets('more opens customer onboarding workflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(),
          customerBoundaryClient: FakeCustomerBoundaryClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Thêm'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mở hoặc liên kết mã khách'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-onboarding-screen')),
      findsOneWidget,
    );
    expect(find.text('Đại lý An Phát'), findsOneWidget);
    expect(find.text('Đã liên kết'), findsOneWidget);
  });

  testWidgets('linked directory outlet can open order creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(),
          customerBoundaryClient: FakeCustomerBoundaryClient(),
          orderDataClient: FakeOrderDataClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Điểm bán'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('outlet-row-outlet-1')));
    await tester.pumpAndSettle();

    const orderKey = Key('outlet-directory-create-order');
    await revealOutletActivityAction(tester, orderKey);
    await tester.tap(find.byKey(orderKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-order-screen')), findsOneWidget);
    expect(find.text('Đại lý An Phát'), findsOneWidget);
  });

  testWidgets('customer directory exposes linked Company customers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(),
          customerBoundaryClient: FakeCustomerBoundaryClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Điểm bán'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outlet-tab-company')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key(
          'company-customer-11111111-1111-4111-8111-111111111111',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('KH001'), findsOneWidget);
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
          mutationQueueStore: MemoryMutationQueueStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();
    await revealRouteLine(tester);
    await tester.tap(find.byKey(const Key('route-line-line-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-checkin-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('outlet-checkin-button')));
    await tester.pumpAndSettle();

    expect(client.checkInCalled, isTrue);
    expect(client.checkInValues, [true]);
    expect(find.text('Đã check-in'), findsWidgets);
    expect(find.text('Hoàn tác check-in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('outlet-checkin-button')));
    await tester.pumpAndSettle();

    expect(client.checkInValues, [true, false]);
    expect(find.text('Check-in điểm bán'), findsOneWidget);
  });

  testWidgets(
    'route outlet records skip reason through original MCP contract',
    (
      WidgetTester tester,
    ) async {
      final client = FakeFieldDataClient();
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            session: session,
            fieldDataClient: client,
            fieldLocationProvider: FakeLocationProvider(),
            mutationQueueStore: MemoryMutationQueueStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(navLabel('Đi tuyến'));
      await tester.pumpAndSettle();
      await revealRouteLine(tester);
      await tester.tap(find.byKey(const Key('route-line-line-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('outlet-skip-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('outlet-skip-reason-no_demand')),
      );
      await tester.tap(find.byKey(const Key('outlet-skip-submit')));
      await tester.pumpAndSettle();

      expect(client.skipReasons, ['no_demand']);
      expect(find.text('Bỏ qua'), findsWidgets);
    },
  );

  testWidgets('fixed route customers are visible before opening the day run', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: FakeFieldDataClient(
            workspaceValue: unopenedWorkspace,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-start-button')), findsOneWidget);
    expect(find.byKey(const Key('route-preview-customer-1')), findsOneWidget);
    expect(find.text('Tuyến cố định'), findsOneWidget);
  });

  testWidgets('fixed route remains available while the day run is active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoutesPage(
          routes: [route],
          selectedRoute: route,
          workspace: workspace,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phiên hôm nay'), findsWidgets);
    expect(find.byKey(const Key('route-preview-customer-1')), findsNothing);

    await tester.tap(find.text('Tuyến cố định').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-preview-customer-1')), findsOneWidget);
    expect(
      find.text('1 điểm bán đã được xếp sẵn cho tuyến này.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'completed route session is read only and can still show fixed route',
    (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoutesPage(
            routes: [route],
            selectedRoute: route,
            workspace: doneWorkspace,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã kết thúc'), findsOneWidget);
      expect(find.byKey(const Key('route-finish-button')), findsNothing);
      expect(find.byKey(const Key('route-add-customer-button')), findsNothing);

      await tester.tap(find.text('Tuyến cố định').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route-preview-customer-1')), findsOneWidget);
    },
  );

  testWidgets('bottom navigation is anchored outside scrollable tab content', (
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

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('app-shell-scaffold')),
    );
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(find.byKey(const Key('app-bottom-navigation')), findsOneWidget);

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const Key('routes-screen')),
      matching: find.byType(ListView),
    );
    await tester.drag(list, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-bottom-navigation')), findsOneWidget);
  });

  testWidgets('selected route is restored after app restart', (
    WidgetTester tester,
  ) async {
    final client = FakeFieldDataClient(routes: const [route, routeTwo]);
    final selection = MemoryRouteSelectionStore(routeTwo.id);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session,
          fieldDataClient: client,
          routeSelectionStore: selection,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.lastLoadedRouteId, routeTwo.id);
  });

  testWidgets('route session filters separate visit states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoutesPage(
          routes: [route],
          selectedRoute: route,
          workspace: filterWorkspace,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('route-filter-skipped')));
    await tester.pumpAndSettle();

    expect(find.text('Cửa hàng Bỏ Qua'), findsOneWidget);
    expect(find.text('Cửa hàng Minh Phát'), findsNothing);

    final addedFilter = find.byKey(const Key('route-filter-added'));
    await tester.ensureVisible(addedFilter);
    await tester.tap(addedFilter);
    await tester.pumpAndSettle();

    expect(find.text('Cửa hàng Thêm Mới'), findsOneWidget);
    expect(find.text('Cửa hàng Bỏ Qua'), findsNothing);

    final followupFilter = find.byKey(const Key('route-filter-followups'));
    await tester.ensureVisible(followupFilter);
    await tester.tap(followupFilter);
    await tester.pumpAndSettle();

    expect(find.text('Cửa hàng Thêm Mới'), findsOneWidget);
    expect(find.text('Cửa hàng Minh Phát'), findsNothing);
  });
}
