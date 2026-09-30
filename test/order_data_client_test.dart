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
      var productSearchCount = 0;
      final client = HttpOrderDataClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          expect(request.headers['authorization'], 'Bearer mobile-token');

          if (request.url.path == '/api/core-sales/products/search') {
            productSearchCount += 1;
            expect(
              request.url.queryParameters['includePrice'],
              productSearchCount == 1 ? 'false' : 'true',
            );
            return jsonResponse(
              {
                'data': [
                  {
                    'productId': 'product-1',
                    'variantId': 'variant-1',
                    'name': 'Trà đào',
                    'sku': 'TD01',
                    'variantName': 'Chai 750 ml',
                    'sizeLabel': '750 ml',
                    'sellUnit': 'CHAI',
                    'packUnit': 'THÙNG',
                    'packQuantity': 12,
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
                    'sourceType': 'MCP',
                    'customerName': 'Cửa hàng Minh Phát',
                    'createdAt': '2026-09-28T08:00:00Z',
                    'currentVersionNumber': '2',
                    'versions': [
                      {
                        'versionNumber': '1',
                        'status': 'superseded',
                        'total': '100000',
                        'lines': [],
                      },
                      {
                        'versionNumber': '2',
                        'status': 'confirmed',
                        'subtotal': '125000',
                        'discountTotal': '0',
                        'taxTotal': '0',
                        'total': '125000',
                        'createdAt': '2026-09-28T08:00:00Z',
                        'lines': [
                          {
                            'id': 'line-1',
                            'lineNumber': 1,
                            'variantId': 'variant-1',
                            'sku': 'TD01',
                            'itemName': 'Trà đào',
                            'unitCode': 'CHAI',
                            'unitName': 'Chai',
                            'quantity': '2',
                            'unitPrice': '62500',
                            'lineTotal': '125000',
                          },
                        ],
                      },
                    ],
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
      final prices = await client.loadFreshPrices(query: 'trà');
      expect(prices['variant-1'], 125000);
      expect(products.single.purchaseUnitLabel, 'Lẻ');
      expect(products.single.purchaseUnitDetail, contains('THÙNG 12'));

      final orders = await client.loadOrders();
      expect(orders.single.number, 'SO-001');
      expect(orders.single.currentVersionNumber, '2');
      expect(orders.single.currentVersion?.total, 125000);
      expect(orders.single.currentVersion?.lines.single.itemName, 'Trà đào');
      expect(orders.single.currentVersion?.lines.single.unitLabel, 'Chai');

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
          'GET /api/core-sales/products/search',
          'GET /api/core-sales/orders',
          'POST /api/core-sales/orders',
        ],
      );
    },
  );

  test(
    'order client turns missing Công Ty price into an actionable message',
    () async {
      final client = HttpOrderDataClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          return jsonResponse(
            {
              'error': {
                'code': 'BASE_PRICE_NOT_FOUND',
                'message': 'No active base price is available',
                'retryable': false,
              },
            },
            409,
          );
        }),
      );

      await expectLater(
        client.createOrder(
          customerId: '11111111-1111-4111-8111-111111111111',
          customerAddressId: '22222222-2222-4222-8222-222222222222',
          lines: const [
            OrderLineInput(
              variantId: '33333333-3333-4333-8333-333333333333',
              quantity: 1,
            ),
          ],
          idempotencyKey: 'mcp.sales-order.create-test-price',
        ),
        throwsA(
          isA<OrderDataFailure>()
              .having(
                (failure) => failure.code,
                'code',
                'BASE_PRICE_NOT_FOUND',
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('chưa có giá bán áp dụng'),
              ),
        ),
      );
    },
  );


  test('generic 409 is replaced by an order recovery message', () async {
    final client = HttpOrderDataClient(
      profile: InstallationProfile(
        name: 'Hưng Phát',
        baseUrl: Uri.parse('https://mcp.example.vn'),
      ),
      token: 'mobile-token',
      client: MockClient((request) async {
        return jsonResponse(
          {
            'error': {
              'code': 'UNKNOWN_ORDER_CONFLICT',
              'message': 'Dữ liệu đang xung đột với trạng thái hiện tại.',
              'retryable': false,
            },
          },
          409,
        );
      }),
    );

    await expectLater(
      client.createOrder(
        customerId: '11111111-1111-4111-8111-111111111111',
        customerAddressId: '22222222-2222-4222-8222-222222222222',
        lines: const [
          OrderLineInput(
            variantId: '33333333-3333-4333-8333-333333333333',
            quantity: 1,
          ),
        ],
        idempotencyKey: 'mcp.sales-order.create-test-conflict',
      ),
      throwsA(
        isA<OrderDataFailure>().having(
          (failure) => failure.message,
          'message',
          contains('Đơn chưa phù hợp với dữ liệu hiện tại'),
        ),
      ),
    );
  });

}
