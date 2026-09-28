import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('field history client uses report and field-check contracts', () async {
    final seen = <String>[];
    final client = HttpFieldHistoryClient(
      profile: InstallationProfile(
        name: 'Hưng Phát',
        baseUrl: Uri.parse('https://mcp.example.vn'),
      ),
      token: 'mobile-token',
      client: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer mobile-token');

        if (request.url.path == '/api/local-read/mcp-session-reports') {
          return jsonResponse(
            {
              'data': {
                'days': 45,
                'reports': [
                  {
                    'id': 'session-report-1',
                    'session_id': 'session-1',
                    'route_name': 'Tuyến 1',
                    'session_date': '2026-09-27',
                    'session_status': 'done',
                    'planned_customers': 4,
                    'visited_customers': 3,
                    'order_count': 1,
                    'test_count': 1,
                    'report_count': 2,
                    'followup_count': 1,
                  },
                ],
              },
            },
            200,
          );
        }

        if (request.url.path == '/api/local-read/mcp-session-report') {
          expect(request.url.queryParameters['sessionId'], 'session-1');
          return jsonResponse(
            {
              'data': {
                'session': {
                  'id': 'session-1',
                  'route_name': 'Tuyến 1',
                  'session_date': '2026-09-27',
                  'status': 'done',
                  'planned_customers': 4,
                  'visited_customers': 3,
                  'order_count': 1,
                  'test_count': 1,
                  'report_count': 2,
                  'followup_count': 1,
                },
                'snapshot': {
                  'id': 'session-report-1',
                  'overview': {'planned': 4, 'visited': 3},
                },
                'customers': [
                  {
                    'id': 'sc-1',
                    'customer_name': 'Điểm bán A',
                    'visit_status': 'skipped',
                    'status_reason': 'closed',
                  },
                ],
                'marketReports': [
                  {
                    'id': 'report-1',
                    'customer_name': 'Điểm bán B',
                    'content': 'Đối thủ: Brand A',
                    'opportunity_summary': 'Có nhu cầu',
                  },
                ],
                'tests': [
                  {
                    'id': 'result-1',
                    'customer_name': 'Điểm bán B',
                    'product_name': 'Trà đào',
                    'status': 'interested',
                  },
                ],
                'followups': [
                  {
                    'id': 'followup-1',
                    'customer_name': 'Điểm bán B',
                    'status': 'pending',
                    'title': 'Gọi lại',
                  },
                ],
              },
            },
            200,
          );
        }

        if (request.url.path == '/api/market-checks/data') {
          return jsonResponse(
            {
              'data': {
                'checks': [
                  {
                    'id': 'result-1',
                    'date': '2026-09-27',
                    'routeName': 'Tuyến 1',
                    'accountName': 'Điểm bán B',
                    'productName': 'Trà đào',
                    'status': 'interested',
                    'note': 'Khách quan tâm',
                  },
                ],
              },
            },
            200,
          );
        }

        if (request.url.path == '/api/field-checks/result') {
          expect(request.method, 'POST');
          expect(
            request.headers['idempotency-key'],
            'field-check.result.update-test',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['resultId'], 'result-1');
          expect(body['productName'], 'Trà đào');
          expect(body['status'], 'opportunity');
          return jsonResponse(
            {
              'data': {'id': 'result-1', 'status': 'opportunity'},
            },
            200,
          );
        }

        return jsonResponse({'error': {'code': 'NOT_FOUND'}}, 404);
      }),
    );

    final reports = await client.loadSessionReports();
    expect(reports.single.sessionId, 'session-1');
    expect(reports.single.reports, 2);

    final detail = await client.loadSessionReportDetail('session-1');
    expect(detail.marketReports.single.customerName, 'Điểm bán B');
    expect(detail.tests.single.status, 'opportunity');
    expect(detail.customers.single.visitStatus, 'skipped');

    final checks = await client.loadFieldChecks();
    expect(checks.single.status, 'opportunity');

    await client.updateFieldCheck(
      resultId: 'result-1',
      productName: 'Trà đào',
      status: 'opportunity',
      note: 'Có khả năng chuyển đổi',
      idempotencyKey: 'field-check.result.update-test',
    );

    expect(
      seen,
      [
        'GET /api/local-read/mcp-session-reports',
        'GET /api/local-read/mcp-session-report',
        'GET /api/market-checks/data',
        'POST /api/field-checks/result',
      ],
    );
  });

  test('field check status follows MCP presentation states', () {
    expect(normalizeFieldCheckStatus('ok'), 'opportunity');
    expect(normalizeFieldCheckStatus('interested'), 'opportunity');
    expect(normalizeFieldCheckStatus('bad'), 'risk');
    expect(normalizeFieldCheckStatus('retry'), 'risk');
    expect(normalizeFieldCheckStatus('tested'), 'normal');
  });
}
