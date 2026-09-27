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

  test('field client loads MCP outlet directory by employee scope', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/customer-verifications');
        return http.Response(
          jsonEncode({
            'data': {
              'items': [
                {
                  'routeCustomerId': 'outlet-1',
                  'routeId': 'route-2',
                  'routeName': 'Tuyến Quận 3',
                  'customerId': 'MCP001',
                  'customerName': 'Đại lý An Phát',
                  'phone': '0909000111',
                  'area': 'Quận 3',
                  'address': '456 Lê Lợi',
                  'note': 'Khách MCP',
                  'active': true,
                  'geoLat': 10.78,
                  'geoLng': 106.68,
                  'geoAccuracy': 7.5,
                  'status': 'linked_existing',
                  'coreCustomerId': 'core-customer-1',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final outlets = await client.loadOutlets();

    expect(outlets, hasLength(1));
    expect(outlets.single.id, 'outlet-1');
    expect(outlets.single.routeId, 'route-2');
    expect(outlets.single.routeName, 'Tuyến Quận 3');
    expect(outlets.single.code, 'MCP001');
    expect(outlets.single.name, 'Đại lý An Phát');
    expect(outlets.single.area, 'Quận 3');
    expect(outlets.single.address, '456 Lê Lợi');
    expect(outlets.single.gps?.lat, 10.78);
  });

  test('field client loads route customers and current day data', () async {
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/local-read/mcp-shell') {
          return http.Response(
            jsonEncode(shellPayload()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, '/api/mcp-day/data');
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
    expect(workspace.day.sessionOpened, isTrue);
  });

  test('field actions send canonical mutation contracts', () async {
    final seen = <String>[];
    final client = HttpFieldDataClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        seen.add(request.url.path);
        expect(request.headers['Idempotency-Key'], startsWith('test-key-'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (request.url.path == '/api/mcp-day/open-session') {
          expect(body['routeId'], 'route-1');
        } else if (request.url.path ==
            '/api/mcp-day/session-customer/checkin') {
          expect(body['sessionCustomerId'], 'line-1');
          expect(body['checkedIn'], isTrue);
          expect(body['geoSource'], 'mobile_gps');
        } else if (request.url.path == '/api/mcp-day/session-customer/add') {
          expect(body['sessionId'], 'session-1');
          expect(body['customerName'], 'Cửa hàng Mới');
          expect(body['phone'], '0909555666');
          expect(body['geoLat'], 10.76);
          expect(body['geoLng'], 106.68);
          expect(body['geoSource'], 'mobile_gps');
          return http.Response(
            jsonEncode({
              'data': {
                'routeCustomerId': 'customer-new',
                'sessionCustomerId': 'line-new',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else {
          expect(request.url.path, '/api/mcp-sessions/session-1');
          expect(body['status'], 'done');
        }

        return http.Response(
          jsonEncode({
            'data': {'ok': true},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await client.openRouteSession(
      routeId: 'route-1',
      date: DateTime(2026, 9, 27),
      owner: 'Nguyễn Văn A',
      idempotencyKey: 'test-key-open-12345678',
    );
    await client.setSessionCustomerCheckIn(
      sessionCustomerId: 'line-1',
      latitude: 10.75,
      longitude: 106.67,
      accuracy: 8,
      idempotencyKey: 'test-key-checkin-12345678',
    );
    final added = await client.addSessionCustomer(
      sessionId: 'session-1',
      customerName: 'Cửa hàng Mới',
      phone: '0909555666',
      area: 'Quận 1',
      address: '12 Nguyễn Trãi',
      note: 'Khách mới ngoài tuyến',
      latitude: 10.76,
      longitude: 106.68,
      accuracy: 9,
      idempotencyKey: 'test-key-add-12345678',
    );
    await client.finishRouteSession(
      sessionId: 'session-1',
      idempotencyKey: 'test-key-finish-12345678',
    );

    expect(added.routeCustomerId, 'customer-new');
    expect(added.sessionCustomerId, 'line-new');
    expect(
      seen,
      [
        '/api/mcp-day/open-session',
        '/api/mcp-day/session-customer/checkin',
        '/api/mcp-day/session-customer/add',
        '/api/mcp-sessions/session-1',
      ],
    );
  });
}
