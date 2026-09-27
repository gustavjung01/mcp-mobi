import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';

void main() {
  test('production default uses the canonical MCP API for auth and business', () {
    final profile = InstallationProfile.productionDefault();

    expect(profile, isNotNull);
    expect(profile!.name, 'Hưng Phát');
    expect(profile.baseUrl.toString(), 'https://68.233.111.135');
    expect(profile.fieldBaseUrl.toString(), 'https://68.233.111.135');
    expect(profile.installationKey, 'https://68.233.111.135');
  });

  test('selected system uses the selected gateway for MCP business APIs', () {
    final profile = InstallationProfile.selected(
      name: 'Hưng Phát',
      baseUrl: Uri.parse('https://mcp.example.vn'),
    );

    expect(profile.baseUrl.toString(), 'https://mcp.example.vn');
    expect(profile.fieldBaseUrl.toString(), 'https://mcp.example.vn');
    expect(profile.installationKey, 'https://mcp.example.vn');
  });

  test(
    'stored legacy hard-coded business IP is migrated back to selected gateway',
    () {
      final profile = InstallationProfile.fromJson({
        'name': 'Hưng Phát',
        'baseUrl': 'https://mcp.example.vn',
        'businessBaseUrl': 'https://68.233.111.135',
      });

      expect(profile, isNotNull);
      expect(profile!.baseUrl.toString(), 'https://mcp.example.vn');
      expect(profile.fieldBaseUrl.toString(), 'https://mcp.example.vn');
    },
  );

  test('stored explicit non-legacy business endpoint is preserved', () {
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
