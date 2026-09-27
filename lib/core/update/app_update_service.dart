import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AppUpdateFailure implements Exception {
  const AppUpdateFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class AppReleaseManifest {
  const AppReleaseManifest({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
    required this.size,
    required this.releaseNotes,
    this.buildNumber,
    this.publishedAt,
  });

  final String version;
  final Uri downloadUrl;
  final String sha256;
  final int size;
  final String releaseNotes;
  final int? buildNumber;
  final String? publishedAt;

  factory AppReleaseManifest.fromJson(
    Map<String, dynamic> json, {
    required Uri baseUri,
  }) {
    final version = _text(json['version']);
    final sha256 = _text(json['sha256']).toLowerCase();
    final apk = _text(json['apk']);
    final rawUrl = _text(json['url']);
    final direct = Uri.tryParse(rawUrl);
    final downloadUrl = direct != null && direct.hasScheme
        ? direct
        : baseUri.resolve(rawUrl.isNotEmpty ? rawUrl : apk);

    if (!_isStrictVersion(version) ||
        downloadUrl.scheme != 'https' ||
        sha256.length != 64 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const AppUpdateFailure(
        code: 'UPDATE_MANIFEST_INVALID',
        message: 'Thông tin bản cập nhật không hợp lệ.',
      );
    }

    return AppReleaseManifest(
      version: version,
      downloadUrl: downloadUrl,
      sha256: sha256,
      size: _integer(json['size']),
      releaseNotes: _text(
        json['releaseNotes'],
        fallback: 'Cập nhật và cải thiện ứng dụng.',
      ),
      buildNumber: _optionalInteger(json['buildNumber']),
      publishedAt: _nullableText(json['publishedAt']),
    );
  }
}

class AppUpdateCheck {
  const AppUpdateCheck({
    required this.currentVersion,
    required this.release,
    required this.updateAvailable,
  });

  final String currentVersion;
  final AppReleaseManifest release;
  final bool updateAvailable;
}

abstract interface class AppUpdatePlatform {
  Future<String> currentVersion();

  Future<bool> canInstallPackages();

  Future<void> openInstallPermissionSettings();

  Future<void> downloadAndInstall({
    required Uri url,
    required String sha256,
  });
}

class MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  const MethodChannelAppUpdatePlatform();

  static const _channel = MethodChannel(
    'com.hungphat.mcpfield/app_update',
  );

  @override
  Future<String> currentVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('currentVersion');
      return (version ?? '').trim();
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  @override
  Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  @override
  Future<void> downloadAndInstall({
    required Uri url,
    required String sha256,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'downloadAndInstall',
        {
          'url': url.toString(),
          'sha256': sha256,
        },
      );
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }
}

class AppUpdateService {
  AppUpdateService({
    String? baseUrl,
    http.Client? client,
    AppUpdatePlatform? platform,
    this.timeout = const Duration(seconds: 12),
  }) : baseUrl =
           (baseUrl ?? const String.fromEnvironment('MCP_UPDATE_BASE_URL'))
               .trim(),
       _client = client ?? http.Client(),
       platform = platform ?? const MethodChannelAppUpdatePlatform();

  final String baseUrl;
  final http.Client _client;
  final AppUpdatePlatform platform;
  final Duration timeout;

  bool get configured => baseUrl.isNotEmpty;

  Future<String> currentVersion() => platform.currentVersion();

  Future<AppUpdateCheck> checkForUpdate() async {
    if (!configured) {
      throw const AppUpdateFailure(
        code: 'UPDATE_NOT_CONFIGURED',
        message: 'Chưa cấu hình nguồn cập nhật cho ứng dụng.',
      );
    }

    final base = Uri.tryParse(
      baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
    );
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const AppUpdateFailure(
        code: 'UPDATE_URL_INVALID',
        message: 'Địa chỉ cập nhật chưa hợp lệ.',
      );
    }

    final current = await currentVersion();
    if (!_isStrictVersion(current)) {
      throw const AppUpdateFailure(
        code: 'CURRENT_VERSION_INVALID',
        message: 'Không đọc được phiên bản hiện tại của ứng dụng.',
      );
    }

    http.Response response;
    try {
      response = await _client
          .get(
            base.resolve('latest.json'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AppUpdateFailure(
        code: 'UPDATE_TIMEOUT',
        message: 'Kiểm tra cập nhật quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const AppUpdateFailure(
        code: 'UPDATE_NETWORK',
        message: 'Không kết nối được máy chủ cập nhật.',
        retryable: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateFailure(
        code: 'UPDATE_HTTP_${response.statusCode}',
        message: response.statusCode == 404
            ? 'Chưa có bản cập nhật được phát hành.'
            : 'Không tải được thông tin cập nhật.',
        retryable: response.statusCode >= 500,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const AppUpdateFailure(
        code: 'UPDATE_MANIFEST_INVALID',
        message: 'Thông tin bản cập nhật không hợp lệ.',
      );
    }
    final json = _object(decoded);
    final release = AppReleaseManifest.fromJson(
      json,
      baseUri: base,
    );

    return AppUpdateCheck(
      currentVersion: current,
      release: release,
      updateAvailable: compareAppVersions(release.version, current) > 0,
    );
  }

  Future<bool> canInstallPackages() => platform.canInstallPackages();

  Future<void> openInstallPermissionSettings() =>
      platform.openInstallPermissionSettings();

  Future<void> install(AppReleaseManifest release) {
    return platform.downloadAndInstall(
      url: release.downloadUrl,
      sha256: release.sha256,
    );
  }
}

int compareAppVersions(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  for (var index = 0; index < 3; index++) {
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

List<int> _versionParts(String value) {
  if (!_isStrictVersion(value)) {
    throw const AppUpdateFailure(
      code: 'VERSION_INVALID',
      message: 'Phiên bản ứng dụng không hợp lệ.',
    );
  }
  return value.split('.').map(int.parse).toList(growable: false);
}

bool _isStrictVersion(String value) =>
    RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value.trim());

AppUpdateFailure _platformFailure(PlatformException error) {
  switch (error.code) {
    case 'INSTALL_PERMISSION_REQUIRED':
      return const AppUpdateFailure(
        code: 'INSTALL_PERMISSION_REQUIRED',
        message: 'Cần cho phép MCP Field cài đặt ứng dụng từ nguồn này.',
      );
    case 'DOWNLOAD_FAILED':
      return const AppUpdateFailure(
        code: 'DOWNLOAD_FAILED',
        message: 'Không tải được file cập nhật.',
        retryable: true,
      );
    case 'HASH_MISMATCH':
      return const AppUpdateFailure(
        code: 'HASH_MISMATCH',
        message: 'File cập nhật không khớp kiểm tra an toàn.',
      );
    case 'UPDATE_URL_INVALID':
      return const AppUpdateFailure(
        code: 'UPDATE_URL_INVALID',
        message: 'Địa chỉ tải bản cập nhật chưa hợp lệ.',
      );
  }
  final message = (error.message ?? '').trim();
  return AppUpdateFailure(
    code: error.code,
    message: message.isNotEmpty
        ? message
        : 'Không xử lý được bản cập nhật. Vui lòng thử lại.',
    retryable: true,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

String _text(Object? value, {String fallback = ''}) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

int? _optionalInteger(Object? value) {
  if (value == null || _text(value).isEmpty) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}
