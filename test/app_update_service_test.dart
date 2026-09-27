import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/update/app_update_service.dart';

class FakeUpdatePlatform implements AppUpdatePlatform {
  FakeUpdatePlatform({
    this.version = '1.0.0',
    this.installAllowed = true,
  });

  String version;
  bool installAllowed;
  bool openedSettings = false;
  Uri? installedUrl;
  String? installedSha256;

  @override
  Future<String> currentVersion() async => version;

  @override
  Future<bool> canInstallPackages() async => installAllowed;

  @override
  Future<void> openInstallPermissionSettings() async {
    openedSettings = true;
  }

  @override
  Future<void> downloadAndInstall({
    required Uri url,
    required String sha256,
  }) async {
    installedUrl = url;
    installedSha256 = sha256;
  }
}

void main() {
  test('update service reads latest.json and resolves a newer APK', () async {
    final platform = FakeUpdatePlatform();
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://updates.example.vn/mcp-filed/latest.json',
      );
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'version': '1.0.1',
            'buildNumber': 1000001,
            'apk': 'MCP-Field-1.0.1.apk',
            'url': 'https://updates.example.vn/mcp-filed/MCP-Field-1.0.1.apk',
            'size': 123456,
            'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'releaseNotes': 'Bổ sung cập nhật trực tiếp.',
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = AppUpdateService(
      baseUrl: 'https://updates.example.vn/mcp-filed',
      client: client,
      platform: platform,
    );

    final check = await service.checkForUpdate();
    expect(check.currentVersion, '1.0.0');
    expect(check.updateAvailable, isTrue);
    expect(check.release.version, '1.0.1');
    expect(check.release.size, 123456);

    await service.install(check.release);
    expect(
      platform.installedUrl.toString(),
      'https://updates.example.vn/mcp-filed/MCP-Field-1.0.1.apk',
    );
    expect(
      platform.installedSha256,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  });

  test('same or older release is not offered as an update', () async {
    final platform = FakeUpdatePlatform(version: '1.2.3');
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'version': '1.2.3',
            'apk': 'MCP-Field-1.2.3.apk',
            'size': 1,
            'sha256': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          }),
        ),
        200,
      );
    });

    final service = AppUpdateService(
      baseUrl: 'https://updates.example.vn/mcp-filed',
      client: client,
      platform: platform,
    );

    final check = await service.checkForUpdate();
    expect(check.updateAvailable, isFalse);
    expect(compareAppVersions('1.2.4', '1.2.3'), greaterThan(0));
    expect(compareAppVersions('2.0.0', '1.99.99'), greaterThan(0));
  });

  test('updater requires a configured public HTTPS base URL', () async {
    final service = AppUpdateService(
      baseUrl: '',
      platform: FakeUpdatePlatform(),
      client: MockClient((request) async => http.Response('', 500)),
    );

    await expectLater(
      service.checkForUpdate(),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.code,
          'code',
          'UPDATE_NOT_CONFIGURED',
        ),
      ),
    );
  });
}
