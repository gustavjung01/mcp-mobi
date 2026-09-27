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
}

abstract interface class FieldLocationProvider {
  Future<FieldLocation> current();
}

class DeviceFieldLocationProvider implements FieldLocationProvider {
  const DeviceFieldLocationProvider();

  @override
  Future<FieldLocation> current() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const FieldLocationFailure(
        'Hãy bật Dịch vụ vị trí trên điện thoại để check-in.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const FieldLocationFailure(
        'Cần cho phép MCP Field dùng vị trí khi đang sử dụng ứng dụng.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const FieldLocationFailure(
        'Quyền vị trí đang bị tắt. Hãy bật lại trong Cài đặt của điện thoại.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
    return FieldLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }
}
