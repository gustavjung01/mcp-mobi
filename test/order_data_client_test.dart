import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
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
    'order client uses MCP core-sales contract without commercial fields',
    () async {
      final seen = <String>[];
      final client = HttpOrderDataClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://login.example.vn'),
          businessBaseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          expect(request.headers['authorization'], 'Bearer mobile-token');

          if (request.url.path == '/api/core-sales/products/search') {
            expect(request.url.queryParameters['includePrice'], 'true');
            return jsonResponse(
              {
                'data': [
                  {
                    'productId': 'product-1',
                    'variantId': 'variant-1',
                    'name': 'Trà đào',
                    'sku': 'TD01',
                    'sellUnit': 'CHAI',
                    'price': 125000,
                  },
                ],
              },
              200,
            );
          }

          if (request.method == 'GET') {
            return jsonResponse(
              {
                'data': [
                  {
                    'id': 'order-1',
                    'number': 'SO-001',
                    'status': 'confirmed',
                    'customerName': 'Cửa hàng Minh Phát',
                  },
                ],
              },
              200,
            );
          }

          expect(
            request.headers['idempotency-key'],
            'mcp.sales-order.create-test',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            body.keys,
            containsAll(['customerId', 'customerAddressId', 'lines']),
          );
          expect(body.containsKey('price'), isFalse);
          expect(body.containsKey('tax'), isFalse);
          expect(body.containsKey('discount'), isFalse);
          final line = (body['lines'] as List).single as Map<String, dynamic>;
          expect(line['variantId'], 'variant-1');
          expect(line['quantity'], '2');
          expect(line.containsKey('price'), isFalse);

          return jsonResponse(
            {
              'data': {
                'id': 'order-2',
                'number': 'SO-002',
                'status': 'draft',
                'customerName': 'Cửa hàng Minh Phát',
              },
            },
            201,
          );
        }),
      );

      final products = await client.searchProducts(query: 'trà');
      expect(products.single.price, 125000);

      final orders = await client.loadOrders();
      expect(orders.single.number, 'SO-001');

      final created = await client.createOrder(
        customerId: '11111111-1111-4111-8111-111111111111',
        customerAddressId: '22222222-2222-4222-8222-222222222222',
        lines: const [
          OrderLineInput(variantId: 'variant-1', quantity: 2),
        ],
        idempotencyKey: 'mcp.sales-order.create-test',
      );
      expect(created.number, 'SO-002');
      expect(
        seen,
        [
          'GET /api/core-sales/products/search',
          'GET /api/core-sales/orders',
          'POST /api/core-sales/orders',
        ],
      );
    },
  );
}
