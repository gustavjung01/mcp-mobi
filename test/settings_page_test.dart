import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_field/core/update/app_update_service.dart';
import 'package:mcp_field/features/settings/settings_page.dart';

class SettingsFakePlatform implements AppUpdatePlatform {
  SettingsFakePlatform({
    this.directInstallSupported = true,
  });

  bool directInstallSupported;
  bool installAllowed = false;
  bool openedSettings = false;
  int installs = 0;

  @override
  Future<String> currentVersion() async => '1.0.0';

  @override
  Future<bool> supportsDirectInstall() async => directInstallSupported;

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
    installs += 1;
  }
}

void main() {
  testWidgets('settings checks update and asks install permission once', (
    WidgetTester tester,
  ) async {
    final platform = SettingsFakePlatform();
    final service = AppUpdateService(
      baseUrl: 'https://updates.example.vn/mcp-filed',
      platform: platform,
      client: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'version': '1.0.1',
              'apk': 'MCP-Field-1.0.1.apk',
              'url': 'https://updates.example.vn/mcp-filed/MCP-Field-1.0.1.apk',
              'size': 1024,
              'sha256': 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
              'releaseNotes': 'Bản thử cập nhật.',
            }),
          ),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(updateService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.byKey(const Key('update-install-guide')), findsOneWidget);
    expect(find.textContaining('Google Play Protect'), findsOneWidget);
    expect(find.textContaining('Cho phép từ nguồn này'), findsOneWidget);
    expect(find.textContaining('Quay lại MCP Field'), findsOneWidget);
    expect(find.textContaining('SHA-256'), findsNothing);

    await tester.tap(find.byKey(const Key('check-update-button')));
    await tester.pumpAndSettle();

    expect(find.text('Có bản 1.0.1 mới.'), findsOneWidget);
    expect(find.byKey(const Key('install-update-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('install-update-button')));
    await tester.pumpAndSettle();

    expect(platform.openedSettings, isTrue);
    expect(platform.installs, 0);

    platform.installAllowed = true;
    await tester.tap(find.byKey(const Key('install-update-button')));
    await tester.pumpAndSettle();

    expect(platform.installs, 1);
    expect(
      find.text(
        'Đã tải và kiểm tra gói cập nhật. Android đang mở màn hình cài đặt.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('iOS settings hides the Android installer flow', (
    WidgetTester tester,
  ) async {
    final platform = SettingsFakePlatform(
      directInstallSupported: false,
    );
    final service = AppUpdateService(
      baseUrl: 'https://updates.example.vn/mcp-filed',
      platform: platform,
      client: MockClient((request) async => http.Response('', 500)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(updateService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.byKey(const Key('ios-update-guidance')), findsOneWidget);
    expect(
      find.text(
        'Bản iPhone/iPad được cập nhật qua kênh phát hành iOS của Công Ty.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('check-update-button')), findsNothing);
    expect(find.byKey(const Key('install-update-button')), findsNothing);
    expect(find.byKey(const Key('update-install-guide')), findsNothing);
  });
}
