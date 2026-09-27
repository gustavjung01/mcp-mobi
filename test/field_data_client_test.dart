import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  final profile = InstallationProfile(
    name: 'Hưng Phát',
    baseUrl: Uri.parse('https://company.example.vn'),
    businessBaseUrl: Uri.parse('https://mcp.example.vn'),
  );

  Map<String, dynamic> shellPayload() => {
    'data': {
      'cursor': 'cursor-1',
      'unchanged': false,
      'snapshot': {
        'routes': [
          {
            'id': 'route-1',
            'route_name': 'Tuyến Quận 1',
            'area': 'Quận 1',
            'active': true,
            'sales': 'Nguyễn Văn A',
          },
        ],
        'routeCustomers': [
          {
            'id': 'customer-1',
            'route_id': 'route-1',
            'customer_id': 'DP00123',
            'customer_name': 'Cửa hàng Minh Phát',
            'area': 'Quận 1',
            'sort_order': 1,
            'active': true,
            'note': '',
          },
        ],
        'latestSessions': [
          {
            'route_id': 'route-1',
            'planned_customers': 1,
            'visited_customers': 0,
            'order_count': 0,
          },
        ],
      },
    },
  };

  test('field client loads routes from canonical local read API', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        expect(request.url.host, 'mcp.example.vn');
        expect(request.url.path, '/api/local-read/mcp-shell');
        expect(
          request.headers['Authorization'],
          'Bearer nppusr.test-token',
        );
        return http.Response(
          jsonEncode(shellPayload()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final routes = await client.loadRoutes();

    expect(routes, hasLength(1));
    expect(routes.single.name, 'Tuyến Quận 1');
    expect(routes.single.plannedCustomers, 1);
  });

  test('field client loads route customers and current day data', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        expect(request.url.host, 'mcp.example.vn');
        if (request.url.path == '/api/local-read/mcp-shell') {
          return http.Response(
            jsonEncode(shellPayload()),
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
      plannedCustomers: 1,
      visitedCustomers: 0,
      orderCount: 0,
      status: 'active',
    );
    final workspace = await client.loadRouteWorkspace(
      route: route,
      date: DateTime(2026, 9, 27),
    );

    expect(workspace.customers.single.accountName, 'Cửa hàng Minh Phát');
    expect(workspace.customers.single.accountId, 'DP00123');
    expect(workspace.day.sessionOpened, isTrue);
    expect(workspace.day.lines.single.phone, '0903123456');
  });
}
