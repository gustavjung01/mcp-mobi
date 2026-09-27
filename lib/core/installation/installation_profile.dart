class InstallationProfile {
  const InstallationProfile({
    required this.name,
    required this.baseUrl,
  });

  final String name;
  final Uri baseUrl;

  String get installationKey => baseUrl.toString().toLowerCase();

  Map<String, String> toJson() => {
    'name': name,
    'baseUrl': baseUrl.toString(),
  };

  static InstallationProfile? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final name = String(value['name'] ?? '').trim();
    final baseUrl = parseBaseUrl(String(value['baseUrl'] ?? ''));
    if (name.isEmpty || baseUrl == null) return null;
    return InstallationProfile(name: name, baseUrl: baseUrl);
  }

  static Uri? parseBaseUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }

    final loopbackHosts = {
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
      '::1',
    };
    final isDevelopmentHttp =
        uri.scheme == 'http' && loopbackHosts.contains(uri.host.toLowerCase());
    if (uri.scheme != 'https' && !isDevelopmentHttp) return null;

    return uri.replace(
      path: uri.path.replaceAll(RegExp(r'/+$'), ''),
    );
  }
}
