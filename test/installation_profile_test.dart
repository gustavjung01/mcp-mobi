import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  test('selected system keeps auth and MCP business endpoints separate', () {
    final profile = InstallationProfile.selected(
      name: 'Hưng Phát',
      baseUrl: Uri.parse('https://company.example.vn'),
    );

    expect(profile.baseUrl.toString(), 'https://company.example.vn');
    expect(
      profile.fieldBaseUrl.toString(),
      'https://68.233.111.135',
    );
    expect(
      profile.installationKey,
      'https://company.example.vn',
    );
  });

  test('stored legacy profile receives configured MCP business endpoint', () {
    final profile = InstallationProfile.fromJson({
      'name': 'Hưng Phát',
      'baseUrl': 'https://company.example.vn',
    });

    expect(profile, isNotNull);
    expect(profile!.baseUrl.toString(), 'https://company.example.vn');
    expect(profile.fieldBaseUrl.toString(), 'https://68.233.111.135');
  });

  test('stored explicit MCP business endpoint is preserved', () {
    final profile = InstallationProfile.fromJson({
      'name': 'Khách hàng khác',
      'baseUrl': 'https://company.example.vn',
      'businessBaseUrl': 'https://mcp.customer.example.vn',
    });

    expect(profile, isNotNull);
    expect(
      profile!.fieldBaseUrl.toString(),
      'https://mcp.customer.example.vn',
    );
  });
}
