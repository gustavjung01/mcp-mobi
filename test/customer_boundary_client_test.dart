import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test(
    'customer boundary client uses verification and company contracts',
    () async {
      final seen = <String>[];
      final client = HttpCustomerBoundaryClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          expect(request.headers['authorization'], 'Bearer mobile-token');

          if (request.url.path == '/api/customer-verifications' &&
              request.method == 'GET') {
            return jsonResponse(
              {
                'data': {
                  'items': [
                    {
                      'routeCustomerId': 'route-customer-1',
                      'routeId': 'route-1',
                      'routeName': 'Tuyến 1',
                      'customerName': 'Điểm bán A',
                      'address': '1 Nguyễn Trãi',
                      'status': 'linked_existing',
                      'coreCustomerId': '11111111-1111-4111-8111-111111111111',
                      'coreCustomerAddressId':
                          '22222222-2222-4222-8222-222222222222',
                      'coreCustomerCode': 'KH001',
                    },
                  ],
                },
              },
              200,
            );
          }

          if (request.url.path == '/api/core-customers') {
            return jsonResponse(
              {
                'data': {
                  'customers': [
                    {
                      'id': '11111111-1111-4111-8111-111111111111',
                      'customerCode': 'KH001',
                      'name': 'Điểm bán A',
                      'status': 'active',
                      'defaultAddressId':
                          '22222222-2222-4222-8222-222222222222',
                      'defaultAddressLine1': '1 Nguyễn Trãi',
                    },
                  ],
                },
              },
              200,
            );
          }

          expect(
            request.headers['idempotency-key'],
            startsWith('customer-verification.'),
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['routeCustomerId'], 'route-customer-1');

          return jsonResponse(
            {
              'data': {
                'routeCustomerId': 'route-customer-1',
                'routeId': 'route-1',
                'customerName': 'Điểm bán A',
                'address': '1 Nguyễn Trãi',
                'status': request.url.path.endsWith('/submit')
                    ? 'submitted'
                    : 'linked_existing',
                'coreRequestId': 'request-1',
                if (request.url.path.endsWith('/sync'))
                  'coreCustomerId': '11111111-1111-4111-8111-111111111111',
                if (request.url.path.endsWith('/sync'))
                  'coreCustomerAddressId':
                      '22222222-2222-4222-8222-222222222222',
              },
            },
            200,
          );
        }),
      );

      final verifications = await client.loadVerifications();
      expect(verifications.single.linked, isTrue);
      expect(verifications.single.coreCustomerCode, 'KH001');

      final company = await client.loadCompanyCustomers();
      expect(company.single.customerCode, 'KH001');

      final submitted = await client.submit(
        routeCustomerId: 'route-customer-1',
        idempotencyKey: 'customer-verification.submit-test',
      );
      expect(submitted.status, 'submitted');

      final synced = await client.sync(
        routeCustomerId: 'route-customer-1',
        idempotencyKey: 'customer-verification.sync-test',
      );
      expect(synced.linked, isTrue);

      expect(
        seen,
        [
          'GET /api/customer-verifications',
          'GET /api/core-customers',
          'POST /api/customer-verifications/submit',
          'POST /api/customer-verifications/sync',
        ],
      );
    },
  );
}
