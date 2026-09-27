import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';
import 'package:mcp_field/core/media/outlet_media_client.dart';

void main() {
  test(
    'outlet media follows profile init put finalize and delete contract',
    () async {
      final seen = <String>[];
      final client = HttpOutletMediaClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url}');

          if (request.url.host == 'upload.example.vn') {
            expect(request.method, 'PUT');
            expect(request.headers['authorization'], isNull);
            expect(request.headers['content-type'], 'image/jpeg');
            expect(request.bodyBytes, [1, 2, 3, 4]);
            return http.Response('', 200);
          }

          expect(request.headers['authorization'], 'Bearer mobile-token');
          if (request.method == 'GET') {
            expect(
              request.url.path,
              '/api/outlet-media/customer-profile',
            );
            expect(request.url.queryParameters['routeCustomerId'], 'rc-1');
            return http.Response(
              jsonEncode({
                'data': {
                  'mediaLimit': 3,
                  'media': [
                    {
                      'id': 'media-1',
                      'viewUrl': 'https://view.example.vn/media-1',
                      'capturedAt': '2026-09-27T10:00:00.000Z',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path == '/api/outlet-media/upload-init') {
            expect(body['routeCustomerId'], 'rc-1');
            expect(body['sessionId'], 'session-1');
            expect(body['clientUploadId'], 'upload-1');
            expect(body['mimeType'], 'image/jpeg');
            expect(body['byteSize'], 4);
            return http.Response(
              jsonEncode({
                'data': {
                  'mediaId': 'media-2',
                  'putUrl': 'https://upload.example.vn/media-2',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/api/outlet-media/upload-finalize') {
            expect(body['mediaId'], 'media-2');
            expect(body['width'], 1200);
            expect(body['height'], 800);
            return http.Response(
              jsonEncode({
                'data': {'id': 'media-2', 'status': 'ready'},
              }),
              200,
            );
          }

          expect(request.url.path, '/api/outlet-media/delete');
          expect(body['mediaId'], 'media-1');
          return http.Response(
            jsonEncode({
              'data': {'mediaId': 'media-1', 'deleted': true},
            }),
            200,
          );
        }),
      );

      final profile = await client.loadProfile(routeCustomerId: 'rc-1');
      expect(profile.media, hasLength(1));
      expect(profile.media.first.id, 'media-1');

      await client.uploadPhoto(
        routeCustomerId: 'rc-1',
        sessionId: 'session-1',
        clientUploadId: 'upload-1',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'image/jpeg',
        width: 1200,
        height: 800,
      );
      await client.deleteMedia(mediaId: 'media-1');

      expect(
        seen,
        [
          'GET https://mcp.example.vn/api/outlet-media/customer-profile?routeCustomerId=rc-1',
          'POST https://mcp.example.vn/api/outlet-media/upload-init',
          'PUT https://upload.example.vn/media-2',
          'POST https://mcp.example.vn/api/outlet-media/upload-finalize',
          'POST https://mcp.example.vn/api/outlet-media/delete',
        ],
      );
    },
  );

  test(
    'outlet media maps the MCP three-photo limit to office language',
    () async {
      final client = HttpOutletMediaClient(
        profile: InstallationProfile(
          name: 'Hưng Phát',
          baseUrl: Uri.parse('https://mcp.example.vn'),
        ),
        token: 'mobile-token',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'code': 'outlet_media_limit_reached'},
            }),
            409,
          );
        }),
      );

      await expectLater(
        client.uploadPhoto(
          routeCustomerId: 'rc-1',
          clientUploadId: 'upload-1',
          bytes: Uint8List.fromList([1]),
          mimeType: 'image/jpeg',
          width: 1,
          height: 1,
        ),
        throwsA(
          isA<OutletMediaFailure>().having(
            (failure) => failure.message,
            'message',
            'Điểm bán chỉ lưu tối đa 3 ảnh.',
          ),
        ),
      );
    },
  );
}
