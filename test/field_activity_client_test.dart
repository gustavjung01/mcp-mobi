import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('field activity client uses the three canonical MCP contracts', () async {
    final seen = <String>[];
    final client = HttpFieldActivityClient(
      profile: InstallationProfile(
        name: 'Hưng Phát',
        baseUrl: Uri.parse('https://mcp.example.vn'),
      ),
      token: 'mobile-token',
      client: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer mobile-token');

        if (request.method == 'GET') {
          expect(request.url.queryParameters['groupType'], 'market_report');
          return jsonResponse(
            {
              'data': {
                'groups': [
                  {
                    'id': 'group-1',
                    'key': 'competitor',
                    'title': 'Đối thủ',
                    'items': [
                      {
                        'id': 'item-1',
                        'key': 'brand-a',
                        'label': 'Nhãn A',
                        'value': 'Nhãn A',
                      },
                    ],
                  },
                ],
              },
            },
            200,
          );
        }

        final key = request.headers['idempotency-key'];
        expect(key, startsWith('session-customer.'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sessionCustomerId'], 'session-customer-1');

        if (request.url.path.endsWith('/report')) {
          return jsonResponse(
            {
              'data': {
                'reportId': 'report-1',
                'sessionCustomerId': 'session-customer-1',
              },
            },
            200,
          );
        }
        if (request.url.path.endsWith('/test')) {
          return jsonResponse(
            {
              'data': {
                'testId': 'test-1',
                'sessionCustomerId': 'session-customer-1',
              },
            },
            200,
          );
        }
        return jsonResponse(
          {
            'data': {
              'followupId': 'followup-1',
              'sessionCustomerId': 'session-customer-1',
            },
          },
          200,
        );
      }),
    );

    final groups = await client.loadReportSettings();
    expect(groups.single.title, 'Đối thủ');
    expect(groups.single.items.single.label, 'Nhãn A');

    final report = await client.submit(
      kind: FieldActivityKind.report,
      payload: const {
        'sessionCustomerId': 'session-customer-1',
        'reportType': 'market_report',
        'fields': {'demandSummary': 'Có nhu cầu'},
      },
      idempotencyKey:
          'session-customer.report.create-123e4567-e89b-42d3-a456-426614174000',
    );
    final trial = await client.submit(
      kind: FieldActivityKind.productTrial,
      payload: const {
        'sessionCustomerId': 'session-customer-1',
        'results': [
          {'productName': 'Trà đào', 'status': 'ok'},
        ],
      },
      idempotencyKey:
          'session-customer.test.create-223e4567-e89b-42d3-a456-426614174000',
    );
    final followup = await client.submit(
      kind: FieldActivityKind.followup,
      payload: const {
        'sessionCustomerId': 'session-customer-1',
        'title': 'Gọi lại',
      },
      idempotencyKey: 'session-customer.followup.create-323e4567-e89b-42d3-a456-426614174000',
    );

    expect(report.referenceId, 'report-1');
    expect(trial.referenceId, 'test-1');
    expect(followup.referenceId, 'followup-1');
    expect(
      seen,
      [
        'GET /api/mcp-report-settings',
        'POST /api/mcp-day/session-customer/report',
        'POST /api/mcp-day/session-customer/test',
        'POST /api/mcp-day/session-customer/followup',
      ],
    );
  });

  test(
    'field activity client reads templates/test files and manages settings',
    () async {
      final seen = <String>[];
      final mutationKeys = <String>[];
      final client = HttpFieldActivityClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/mcp-report-templates') {
            return jsonResponse(
              {
                'data': {
                  'templates': [
                    {
                      'id': 'template-1',
                      'title': 'Khảo sát thị trường',
                      'reportType': 'general',
                      'demandSummary': 'Có nhu cầu',
                    },
                  ],
                },
              },
              200,
            );
          }
          if (request.url.path == '/api/mcp-day/test-options') {
            return jsonResponse(
              {
                'data': {
                  'files': [
                    {
                      'id': 'file-1',
                      'title': 'Phiếu trà',
                      'testDate': '2026-09-28',
                      'products': [
                        {
                          'id': 'test-product-1',
                          'productName': 'Trà đào',
                        },
                      ],
                    },
                  ],
                },
              },
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/mcp-report-settings') {
            expect(request.url.queryParameters['includeInactive'], '1');
            return jsonResponse(
              {
                'data': {
                  'groups': [
                    {
                      'id': 'group-1',
                      'key': 'competitor',
                      'title': 'Đối thủ',
                      'status': 'active',
                      'sortOrder': 1,
                      'items': [
                        {
                          'id': 'item-1',
                          'key': 'brand-a',
                          'label': 'Nhãn A',
                          'value': 'Nhãn A',
                          'status': 'inactive',
                          'sortOrder': 2,
                        },
                      ],
                    },
                  ],
                },
              },
              200,
            );
          }

          mutationKeys.add(request.headers['idempotency-key'] ?? '');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path == '/api/mcp-report-setting-groups') {
            expect(body['title'], 'Đối thủ');
            return jsonResponse(
              {
                'data': {'id': body['groupId'] ?? 'group-new'},
              },
              200,
            );
          }
          if (request.url.path == '/api/mcp-report-settings') {
            expect(body['label'], 'Nhãn A');
            return jsonResponse(
              {
                'data': {'id': body['itemId'] ?? 'item-new'},
              },
              200,
            );
          }
          return jsonResponse(
            {
              'error': {'code': 'NOT_FOUND'},
            },
            404,
          );
        }),
      );

      final reference = client as FieldActivityReferenceClient;
      final templates = await reference.loadReportTemplates();
      final files = await reference.loadTestFiles();
      expect(templates.single.demandSummary, 'Có nhu cầu');
      expect(files.single.products.single.productName, 'Trà đào');

      final admin = client as FieldReportSettingsAdminClient;
      final groups = await admin.loadReportSettingGroups();
      expect(groups.single.sortOrder, 1);
      expect(groups.single.items.single.status, 'inactive');

      await admin.saveReportSettingGroup(
        title: 'Đối thủ',
        description: 'Theo dõi đối thủ',
        sortOrder: 1,
        idempotencyKey: 'mcp.report-setting-group.create-test',
      );
      await admin.saveReportSettingGroup(
        groupId: 'group-1',
        title: 'Đối thủ',
        description: 'Theo dõi đối thủ',
        sortOrder: 1,
        status: 'inactive',
        idempotencyKey: 'mcp.report-setting-group.update-test',
      );
      await admin.saveReportSettingItem(
        groupId: 'group-1',
        label: 'Nhãn A',
        value: 'Nhãn A',
        category: 'Trà',
        brandName: 'Nhãn A',
        productId: '',
        sortOrder: 1,
        idempotencyKey: 'mcp.report-setting-item.create-test',
      );
      await admin.saveReportSettingItem(
        itemId: 'item-1',
        groupId: 'group-1',
        label: 'Nhãn A',
        value: 'Nhãn A',
        category: 'Trà',
        brandName: 'Nhãn A',
        productId: '',
        sortOrder: 1,
        status: 'inactive',
        idempotencyKey: 'mcp.report-setting-item.update-test',
      );

      expect(
        seen,
        containsAll([
          'GET /api/mcp-report-templates',
          'GET /api/mcp-day/test-options',
          'GET /api/mcp-report-settings',
          'POST /api/mcp-report-setting-groups',
          'PATCH /api/mcp-report-setting-groups',
          'POST /api/mcp-report-settings',
          'PATCH /api/mcp-report-settings',
        ]),
      );
      for (final key in mutationKeys) {
        expect(key, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
      }
    },
  );

}
