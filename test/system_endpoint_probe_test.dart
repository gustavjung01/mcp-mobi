import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/installation/system_endpoint_probe.dart';

void main() {
  test('probe accepts the direct MCP backend health contract', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/health/live') {
        return http.Response(
          jsonEncode({
            'data': {'status': 'live'},
          }),
          200,
        );
      }
      if (request.url.path == '/health/ready') {
        return http.Response(
          jsonEncode({
            'data': {'status': 'ready'},
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    final probe = HttpSystemEndpointProbe(client: client);
    await expectLater(
      probe.verify(Uri.parse('https://mcp-api.example.vn')),
      completes,
    );
  });

  test('probe rejects a web frontend origin returning 404', () async {
    final client = MockClient((request) async => http.Response('<html/>', 404));
    final probe = HttpSystemEndpointProbe(client: client);

    await expectLater(
      probe.verify(Uri.parse('https://mcp-web.example.vn')),
      throwsA(
        isA<SystemEndpointFailure>().having(
          (failure) => failure.code,
          'code',
          'SYSTEM_ENDPOINT_NOT_MCP',
        ),
      ),
    );
  });

  test('probe requires ready after live', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/health/live') {
        return http.Response(
          jsonEncode({
            'data': {'status': 'live'},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'error': {'code': 'PROVIDER_UNAVAILABLE'},
        }),
        503,
      );
    });
    final probe = HttpSystemEndpointProbe(client: client);

    await expectLater(
      probe.verify(Uri.parse('https://mcp-api.example.vn')),
      throwsA(
        isA<SystemEndpointFailure>().having(
          (failure) => failure.code,
          'code',
          'SYSTEM_ENDPOINT_HTTP_503',
        ),
      ),
    );
  });
}
