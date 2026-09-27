import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  final profile = InstallationProfile(
    name: 'Hưng Phát',
    baseUrl: Uri.parse('https://mcp.example.vn'),
  );

  test('field client loads routes with mobile bearer session', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/routes/data');
        expect(
          request.headers['Authorization'],
          'Bearer nppusr.test-token',
        );
        return http.Response(
          jsonEncode({
            'data': {
              'routes': [
                {
                  'id': 'route-1',
                  'name': 'Tuyến Quận 1',
                  'area': 'Quận 1',
                  'salesOwner': 'Nguyễn Văn A',
                  'plannedCustomers': 15,
                  'visitedCustomers': 7,
                  'orderCount': 3,
                  'status': 'active',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final routes = await client.loadRoutes();

    expect(routes, hasLength(1));
    expect(routes.single.name, 'Tuyến Quận 1');
    expect(routes.single.plannedCustomers, 15);
  });

  test('field client loads route customers and current day data', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/routes/customers/data') {
          expect(request.url.queryParameters['routeId'], 'route-1');
          return http.Response(
            jsonEncode({
              'data': {
                'customers': [
                  {
                    'id': 'customer-1',
                    'routeId': 'route-1',
                    'routeName': 'Tuyến Quận 1',
                    'accountId': 'DP00123',
                    'accountName': 'Cửa hàng Minh Phát',
                    'contactName': 'Anh Minh',
                    'area': 'Quận 1',
                    'sortOrder': 1,
                    'status': 'active',
                    'note': '',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, '/api/mcp-day/data');
        expect(request.url.queryParameters['routeId'], 'route-1');
        expect(request.url.queryParameters['date'], '2026-09-27');
        return http.Response(
          jsonEncode({
            'data': {
              'sessionOpened': true,
              'run': {
                'id': 'session-1',
                'routeId': 'route-1',
                'routeName': 'Tuyến Quận 1',
                'date': '2026-09-27',
                'owner': 'Nguyễn Văn A',
                'status': 'opened',
                'openedAt': '08:00',
              },
              'lines': [
                {
                  'id': 'line-1',
                  'sessionCustomerId': 'line-1',
                  'routeCustomerId': 'customer-1',
                  'sortOrder': 1,
                  'accountName': 'Cửa hàng Minh Phát',
                  'phone': '0903123456',
                  'address': '123 Nguyễn Văn Cừ',
                  'area': 'Quận 1',
                  'source': 'planned',
                  'status': 'pending',
                  'note': '',
                  'hasOrder': false,
                  'hasTest': false,
                  'hasReport': false,
                  'followupCount': 0,
                  'checkedIn': false,
                },
              ],
              'results': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    const route = FieldRoute(
      id: 'route-1',
      name: 'Tuyến Quận 1',
      area: 'Quận 1',
      salesOwner: 'Nguyễn Văn A',
      plannedCustomers: 15,
      visitedCustomers: 7,
      orderCount: 3,
      status: 'active',
    );
    final workspace = await client.loadRouteWorkspace(
      route: route,
      date: DateTime(2026, 9, 27),
    );

    expect(workspace.customers.single.accountName, 'Cửa hàng Minh Phát');
    expect(workspace.day.sessionOpened, isTrue);
    expect(workspace.day.lines.single.phone, '0903123456');
  });
}
