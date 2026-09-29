import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/features/outlets/outlets_page.dart';
import 'package:mcp_field/features/routes/fixed_routes_page.dart';
import 'package:mcp_field/features/routes/routes_page.dart';

void main() {
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

  testWidgets('fixed route controls follow granted permissions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FixedRoutesPage(
          routes: [route],
          canManageRoutes: true,
          canManageCustomers: true,
        ),
      ),
    );

    expect(find.byKey(const Key('fixed-route-create')), findsOneWidget);
    expect(find.byKey(const Key('fixed-route-add-customer')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: FixedRoutesPage(routes: [route]),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fixed-route-create')), findsNothing);
    expect(find.byKey(const Key('fixed-route-add-customer')), findsNothing);
  });

  testWidgets('empty active session exposes cancel and delete actions',
      (tester) async {
    const workspace = FieldRouteWorkspace(
      route: route,
      customers: [],
      day: FieldDayData(
        sessionOpened: true,
        run: FieldDayRun(
          id: 'session-1',
          routeId: 'route-1',
          routeName: 'Tuyến Quận 1',
          date: '2026-09-29',
          owner: 'Nguyễn Văn A',
          status: 'active',
          openedAt: '08:00',
        ),
        lines: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoutesPage(
          routes: const [route],
          selectedRoute: route,
          workspace: workspace,
          onFinishRoute: () async {},
          onCancelRoute: () async {},
          onDeleteEmptySession: () async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('route-session-actions')));
    await tester.pumpAndSettle();

    expect(find.text('Hủy phiên hôm nay'), findsOneWidget);
    expect(find.text('Xóa phiên rỗng'), findsOneWidget);
  });

  testWidgets('company customer card opens customer profile callback',
      (tester) async {
    const customer = CompanyCustomer(
      id: 'company-1',
      name: 'Khách Công Ty A',
      status: 'active',
      customerCode: 'KH001',
      phone: '0909000111',
      defaultAddressId: 'address-1',
      defaultAddressLine1: '123 Nguyễn Văn Cừ',
    );
    CompanyCustomer? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: OutletsPage(
          companyCustomers: const [customer],
          onOpenCompanyCustomer: (value) => opened = value,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('outlet-tab-company')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('company-customer-company-1')));
    await tester.pump();

    expect(opened?.id, 'company-1');
  });
}
