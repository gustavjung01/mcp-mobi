import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

final profile = InstallationProfile(
  name: 'Hưng Phát',
  baseUrl: Uri.parse('https://mcp.example.vn'),
);

void main() {
  test('login calls the selected MCP backend and parses the session', () async {
    late http.Request captured;
    final client = HttpMobileAuthClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'token':
                  'nppusr.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.tokenvalue',
              'session': {
                'expiresAt': '2026-09-28T00:00:00.000Z',
                'sourceApp': 'mcp-field-mobile',
              },
              'user': {
                'employeeId': '11111111-1111-4111-8111-111111111111',
                'loginName': 'staff.test',
                'employeeFullName': 'Nguyễn Văn A',
                'roles': <String>[],
                'permissions': ['mcp.session.write'],
                'scopes': {
                  'branchIds': <String>[],
                  'warehouseIds': <String>[],
                  'territoryIds': <String>[],
                },
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await client.login(
      profile: profile,
      loginName: 'staff.test',
      password: 'password-value',
    );

    expect(captured.url.toString(), 'https://mcp.example.vn/api/mobile-auth/login');
    expect(captured.headers.containsKey('X-Backend-Token'), isFalse);
    expect(jsonDecode(captured.body)['loginName'], 'staff.test');
    expect(session.displayName, 'Nguyễn Văn A');
    expect(session.permissions, ['mcp.session.write']);
  });

  test('owner challenge is returned as a user-facing auth failure', () async {
    final client = HttpMobileAuthClient(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'INTERNAL_AUTH_OWNER_CHALLENGE_REQUIRED',
              'message': 'Cần mã xác nhận',
              'retryable': false,
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      client.login(
        profile: profile,
        loginName: 'owner.test',
        password: 'password-value',
      ),
      throwsA(
        isA<AuthFailure>()
            .having(
              (failure) => failure.code,
              'code',
              'INTERNAL_AUTH_OWNER_CHALLENGE_REQUIRED',
            )
            .having(
              (failure) => failure.message,
              'message',
              'Nhập mã xác nhận đã gửi để tiếp tục.',
            ),
      ),
    );
  });

  test('me sends only user bearer authorization', () async {
    late http.Request captured;
    const token =
        'nppusr.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.tokenvalue';
    final client = HttpMobileAuthClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'employeeId': '11111111-1111-4111-8111-111111111111',
              'roles': <String>[],
              'permissions': ['mcp.session.write'],
              'scopes': {
                'branchIds': <String>[],
                'warehouseIds': <String>[],
                'territoryIds': <String>[],
              },
              'session': {
                'loginName': 'staff.test',
                'employeeFullName': 'Nguyễn Văn A',
                'expiresAt': '2026-09-28T00:00:00.000Z',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.me(profile: profile, token: token);

    expect(captured.url.toString(), 'https://mcp.example.vn/api/mobile-auth/me');
    expect(captured.headers['Authorization'], 'Bearer $token');
    expect(captured.headers.containsKey('X-Backend-Token'), isFalse);
  });
}
