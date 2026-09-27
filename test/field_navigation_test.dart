import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';

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

class FakeFieldDataClient implements FieldDataClient {
  @override
  Future<List<FieldRoute>> loadRoutes() async => const [route];

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) async {
    return workspace;
  }
}

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  testWidgets('single route loads today and outlet detail', (
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

    expect(find.text('Tuyến Quận 1'), findsWidgets);

    await tester.tap(navLabel('Điểm bán'));
    await tester.pumpAndSettle();

    expect(find.text('Cửa hàng Minh Phát'), findsOneWidget);
    await tester.tap(find.byKey(const Key('outlet-row-customer-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-detail-screen')), findsOneWidget);
    expect(find.text('0903123456'), findsOneWidget);
    expect(find.text('123 Nguyễn Văn Cừ'), findsOneWidget);
  });
}
