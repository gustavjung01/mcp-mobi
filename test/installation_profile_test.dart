import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  test('selected system uses one canonical MCP API origin', () {
    final profile = InstallationProfile.selected(
      name: 'Hưng Phát',
      baseUrl: Uri.parse('https://mcp-api.example.vn'),
    );

    expect(profile.baseUrl.toString(), 'https://mcp-api.example.vn');
    expect(profile.fieldBaseUrl.toString(), 'https://mcp-api.example.vn');
    expect(profile.installationKey, 'https://mcp-api.example.vn');
    expect(profile.toJson().containsKey('businessBaseUrl'), isFalse);
  });

  test(
    'stored split profile migrates the previous business API origin to canonical base',
    () {
      final profile = InstallationProfile.fromJson({
        'name': 'Hưng Phát',
        'baseUrl': 'https://mcp-web.example.vn',
        'businessBaseUrl': 'https://mcp-api.example.vn',
      });

      expect(profile, isNotNull);
      expect(profile!.baseUrl.toString(), 'https://mcp-api.example.vn');
      expect(profile.fieldBaseUrl.toString(), 'https://mcp-api.example.vn');
    },
  );

  test('system origin must not contain a web application path', () {
    expect(
      InstallationProfile.parseBaseUrl(
        'https://mcp.example.vn/api/backend',
      ),
      isNull,
    );
    expect(
      InstallationProfile.parseBaseUrl('https://mcp.example.vn/'),
      Uri.parse('https://mcp.example.vn'),
    );
  });
}
