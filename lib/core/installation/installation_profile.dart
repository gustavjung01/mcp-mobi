class InstallationProfile {
  const InstallationProfile({
    required this.name,
    required this.baseUrl,
  });

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'MCP_API_BASE_URL',
  );

  final String name;
  final Uri baseUrl;

  Uri get fieldBaseUrl => baseUrl;

  String get installationKey => baseUrl.toString().toLowerCase();

  factory InstallationProfile.selected({
    required String name,
    required Uri baseUrl,
  }) {
    return InstallationProfile(
      name: name,
      baseUrl: baseUrl,
    );
  }

  Map<String, String> toJson() => {
    'name': name,
    'baseUrl': baseUrl.toString(),
  };

  static InstallationProfile? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final name = (value['name'] ?? '').toString().trim();
    final storedBaseUrl = parseBaseUrl((value['baseUrl'] ?? '').toString());
    final storedBusinessBaseUrl = parseBaseUrl(
      (value['businessBaseUrl'] ?? '').toString(),
    );
    final baseUrl =
        configuredApiBaseUrl() ?? storedBusinessBaseUrl ?? storedBaseUrl;
    if (name.isEmpty || baseUrl == null) return null;
    return InstallationProfile(
      name: name,
      baseUrl: baseUrl,
    );
  }

  static Uri? configuredApiBaseUrl() {
    return parseBaseUrl(_configuredApiBaseUrl);
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

    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isNotEmpty) return null;

    final loopbackHosts = {
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
      '::1',
    };
    final isDevelopmentHttp =
        uri.scheme == 'http' && loopbackHosts.contains(uri.host.toLowerCase());
    if (uri.scheme != 'https' && !isDevelopmentHttp) return null;

    return uri.replace(path: '');
  }
}
