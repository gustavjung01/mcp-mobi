class InstallationProfile {
  const InstallationProfile({
    required this.name,
    required this.baseUrl,
    this.businessBaseUrl,
  });

  static const _configuredBusinessBaseUrl = String.fromEnvironment(
    'MCP_BUSINESS_BASE_URL',
    defaultValue: 'https://68.233.111.135',
  );

  final String name;
  final Uri baseUrl;
  final Uri? businessBaseUrl;

  Uri get fieldBaseUrl => businessBaseUrl ?? baseUrl;

  String get installationKey => baseUrl.toString().toLowerCase();

  factory InstallationProfile.selected({
    required String name,
    required Uri baseUrl,
  }) {
    return InstallationProfile(
      name: name,
      baseUrl: baseUrl,
      businessBaseUrl: configuredBusinessBaseUrl(),
    );
  }

  Map<String, String> toJson() => {
    'name': name,
    'baseUrl': baseUrl.toString(),
    if (businessBaseUrl != null)
      'businessBaseUrl': businessBaseUrl.toString(),
  };

  static InstallationProfile? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final name = (value['name'] ?? '').toString().trim();
    final baseUrl = parseBaseUrl((value['baseUrl'] ?? '').toString());
    final storedBusinessBaseUrl = parseBaseUrl(
      (value['businessBaseUrl'] ?? '').toString(),
    );
    if (name.isEmpty || baseUrl == null) return null;
    return InstallationProfile(
      name: name,
      baseUrl: baseUrl,
      businessBaseUrl:
          storedBusinessBaseUrl ?? configuredBusinessBaseUrl(),
    );
  }

  static Uri? configuredBusinessBaseUrl() {
    return parseBaseUrl(_configuredBusinessBaseUrl);
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
