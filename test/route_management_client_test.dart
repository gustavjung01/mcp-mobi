import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/route_management_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  final profile = InstallationProfile(
    name: 'Hưng Phát',
    baseUrl: Uri.parse('https://mcp.example.vn'),
  );

  test('route management client uses canonical MCP endpoints and keys', () async {
    final seen = <Map<String, Object?>>[];
    final client = HttpRouteManagementClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        seen.add({
          'method': request.method,
          'path': request.url.path,
          'key': request.headers['Idempotency-Key'],
          'body': request.body.isEmpty
              ? const <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>,
        });
        expect(request.headers['Authorization'], 'Bearer nppusr.test-token');
        return http.Response(
          jsonEncode({'data': <String, dynamic>{}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await client.createRoute(
      routeName: 'Tuyến A',
      area: 'Quận 1',
      weekday: 1,
      note: 'Thứ Hai',
      idempotencyKey: 'mcp.route.create-test-1',
    );
    await client.updateRoute(
      routeId: 'route-1',
      routeName: 'Tuyến A mới',
      area: 'Quận 3',
      weekday: 3,
      note: 'Thứ Tư',
      idempotencyKey: 'mcp.route.update-test-1',
    );
    await client.archiveRoute(
      routeId: 'route-1',
      idempotencyKey: 'mcp.route.archive-test-1',
    );
    await client.addRouteCustomer(
      routeId: 'route-1',
      customerName: 'Cửa hàng Minh Phát',
      phone: '0909000111',
      area: 'Quận 1',
      address: '123 Nguyễn Văn Cừ',
      sortOrder: 2,
      note: 'Khách tuyến',
      includeActiveSession: true,
      activeSessionId: 'session-1',
      idempotencyKey: 'mcp.route-customer.create-test-1',
    );
    await client.updateRouteCustomer(
      routeCustomerId: 'route-customer-1',
      customerName: 'Cửa hàng Minh Phát mới',
      phone: '0909000222',
      area: 'Quận 3',
      address: '456 Lê Lợi',
      sortOrder: 4,
      note: 'Đã cập nhật',
      idempotencyKey: 'mcp.route-customer.update-test-1',
    );
    await client.archiveRouteCustomer(
      routeCustomerId: 'route-customer-1',
      idempotencyKey: 'mcp.route-customer.archive-test-1',
    );
    await client.updateSession(
      sessionId: 'session-1',
      status: 'cancelled',
      note: 'Hủy theo kế hoạch',
      idempotencyKey: 'mcp.session.update-test-1',
    );
    await client.deleteEmptySession(
      sessionId: 'session-2',
      idempotencyKey: 'mcp.session.delete-empty-test-1',
    );

    expect(
      seen.map((item) => '${item['method']} ${item['path']}'),
      [
        'POST /api/routes',
        'PATCH /api/routes/route-1',
        'POST /api/routes/route-1/archive',
        'POST /api/route-customers',
        'PATCH /api/route-customers/route-customer-1',
        'POST /api/route-customers/route-customer-1/archive',
        'PATCH /api/mcp-sessions/session-1',
        'DELETE /api/mcp-sessions/session-2',
      ],
    );
    expect((seen[0]['body'] as Map)['routeName'], 'Tuyến A');
    expect((seen[3]['body'] as Map)['includeActiveSession'], isTrue);
    expect((seen[3]['body'] as Map)['activeSessionId'], 'session-1');
    expect((seen[6]['body'] as Map)['status'], 'cancelled');
    for (final item in seen) {
      expect((item['key'] as String?)?.isNotEmpty, isTrue);
    }
  });

  test('route management maps session conflict to office language', () async {
    final client = HttpRouteManagementClient(
      profile: profile,
      token: 'nppusr.test-token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'route_active_session_exists',
              'message': 'Dữ liệu đang xung đột với trạng thái hiện tại.',
              'retryable': false,
            },
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.updateSession(
        sessionId: 'session-1',
        status: 'cancelled',
        idempotencyKey: 'mcp.session.update-test-2',
      ),
      throwsA(
        isA<FieldDataFailure>()
            .having((error) => error.code, 'code', 'route_active_session_exists')
            .having(
              (error) => error.message,
              'message',
              contains('phiên tuyến khác hoạt động'),
            ),
      ),
    );
  });
}
