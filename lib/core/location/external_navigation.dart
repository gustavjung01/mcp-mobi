import 'package:flutter/services.dart';

class ExternalNavigationFailure implements Exception {
  const ExternalNavigationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ExternalNavigation {
  Future<void> openMap({
    double? latitude,
    double? longitude,
    String? query,
  });
}

class DeviceExternalNavigation implements ExternalNavigation {
  const DeviceExternalNavigation();

  static const _channel = MethodChannel('com.hungphat.mcpfield/navigation');

  @override
  Future<void> openMap({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    final target = latitude != null && longitude != null
        ? '${latitude.toStringAsFixed(7)},${longitude.toStringAsFixed(7)}'
        : (query ?? '').trim();
    if (target.isEmpty) {
      throw const ExternalNavigationFailure(
        'Điểm bán chưa có vị trí hoặc địa chỉ để mở bản đồ.',
      );
    }

    final url = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{'api': '1', 'query': target},
    ).toString();

    try {
      await _channel.invokeMethod<void>('openMap', {'url': url});
    } on PlatformException {
      throw const ExternalNavigationFailure(
        'Không mở được bản đồ trên thiết bị này.',
      );
    } on MissingPluginException {
      throw const ExternalNavigationFailure(
        'Không mở được bản đồ trên thiết bị này.',
      );
    }
  }
}
