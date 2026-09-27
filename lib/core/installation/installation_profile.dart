class InstallationProfile {
  const InstallationProfile({
    required this.name,
    required this.baseUrl,
  });

  final String name;
  final Uri baseUrl;

  static Uri? parseBaseUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    if (uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }

    return uri.replace(
      path: uri.path.replaceAll(RegExp(r'/+$'), ''),
    );
  }
}
