import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class FieldLocation {
  const FieldLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
}

class FieldLocationFailure implements Exception {
  const FieldLocationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class FieldLocationProvider {
  Future<FieldLocation> current();
}

class DeviceFieldLocationProvider implements FieldLocationProvider {
  const DeviceFieldLocationProvider();

  static const _timeout = Duration(seconds: 12);

  @override
  Future<FieldLocation> current() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const FieldLocationFailure(
          'Dịch vụ vị trí đang tắt. Hãy bật Vị trí trên điện thoại rồi thử lại.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const FieldLocationFailure(
          'MCP Field chưa được phép dùng vị trí. Hãy chọn Cho phép khi dùng ứng dụng.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const FieldLocationFailure(
          'Quyền vị trí của MCP Field đang bị chặn. Hãy mở Cài đặt ứng dụng và bật lại quyền Vị trí.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(_timeout);

      if (!position.latitude.isFinite || !position.longitude.isFinite) {
        throw const FieldLocationFailure(
          'Thiết bị chưa trả được tọa độ hợp lệ. Hãy cập nhật vị trí rồi thử lại.',
        );
      }

      return FieldLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on FieldLocationFailure {
      rethrow;
    } on TimeoutException {
      throw const FieldLocationFailure(
        'Không lấy được vị trí trong thời gian cho phép. Hãy kiểm tra dịch vụ Vị trí và thử lại.',
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('permission') || message.contains('permission')) {
        throw const FieldLocationFailure(
          'Ứng dụng chưa được cấp quyền vị trí. Hãy kiểm tra quyền Vị trí của MCP Field.',
        );
      }
      if (code.contains('location') || message.contains('location')) {
        throw const FieldLocationFailure(
          'Thiết bị chưa cung cấp được vị trí. Hãy kiểm tra Vị trí/GPS rồi thử lại.',
        );
      }
      throw FieldLocationFailure(
        'Thiết bị trả về lỗi vị trí (${error.code}). Hãy cập nhật vị trí rồi thử lại.',
      );
    } catch (error) {
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('location service')) {
        throw const FieldLocationFailure(
          'Dịch vụ vị trí đang tắt. Hãy bật Vị trí trên điện thoại rồi thử lại.',
        );
      }
      if (normalized.contains('permission')) {
        throw const FieldLocationFailure(
          'Ứng dụng chưa được cấp quyền vị trí. Hãy kiểm tra quyền Vị trí của MCP Field.',
        );
      }
      throw const FieldLocationFailure(
        'Không lấy được vị trí hiện tại. Hãy kiểm tra dịch vụ Vị trí và thử lại.',
      );
    }
  }
}
