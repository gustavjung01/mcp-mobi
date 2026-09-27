import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'outlet_media_client.dart';

const outletMediaMaxImageEdge = 1600;
const outletMediaJpegQuality = 82;

enum OutletPhotoStatus {
  pending,
  uploading,
  error,
}

class OutletPhotoDraft {
  const OutletPhotoDraft({
    required this.clientUploadId,
    required this.bytes,
    required this.width,
    required this.height,
    this.status = OutletPhotoStatus.pending,
  });

  final String clientUploadId;
  final Uint8List bytes;
  final int width;
  final int height;
  final OutletPhotoStatus status;

  String get mimeType => 'image/jpeg';

  OutletPhotoDraft copyWith({
    OutletPhotoStatus? status,
  }) {
    return OutletPhotoDraft(
      clientUploadId: clientUploadId,
      bytes: bytes,
      width: width,
      height: height,
      status: status ?? this.status,
    );
  }
}

class OutletPhotoPickerFailure implements Exception {
  const OutletPhotoPickerFailure(this.message);

  final String message;
}

abstract interface class OutletPhotoPicker {
  Future<OutletPhotoDraft?> pickCamera();

  Future<List<OutletPhotoDraft>> pickGallery({
    required int maxCount,
  });
}

class DeviceOutletPhotoPicker implements OutletPhotoPicker {
  DeviceOutletPhotoPicker({
    ImagePicker? picker,
    Uuid? uuid,
  }) : _picker = picker ?? ImagePicker(),
       _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final Uuid _uuid;

  @override
  Future<OutletPhotoDraft?> pickCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return null;
      return prepareOutletPhotoDraft(
        sourceBytes: await file.readAsBytes(),
        clientUploadId: _uuid.v4(),
      );
    } on PlatformException catch (error) {
      throw OutletPhotoPickerFailure(_pickerErrorMessage(error));
    }
  }

  @override
  Future<List<OutletPhotoDraft>> pickGallery({
    required int maxCount,
  }) async {
    if (maxCount <= 0) return const [];
    try {
      final files = await _picker.pickMultiImage();
      final result = <OutletPhotoDraft>[];
      for (final file in files.take(maxCount)) {
        result.add(
          await prepareOutletPhotoDraft(
            sourceBytes: await file.readAsBytes(),
            clientUploadId: _uuid.v4(),
          ),
        );
      }
      return result;
    } on PlatformException catch (error) {
      throw OutletPhotoPickerFailure(_pickerErrorMessage(error));
    }
  }
}

Future<OutletPhotoDraft> prepareOutletPhotoDraft({
  required Uint8List sourceBytes,
  required String clientUploadId,
}) async {
  if (sourceBytes.isEmpty) {
    throw const OutletPhotoPickerFailure('Ảnh đã chọn không có dữ liệu.');
  }

  final decoded = image_lib.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const OutletPhotoPickerFailure(
      'Không đọc được ảnh trên thiết bị này.',
    );
  }

  var image = image_lib.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > outletMediaMaxImageEdge) {
    final scale = outletMediaMaxImageEdge / longest;
    image = image_lib.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  final encoded = Uint8List.fromList(
    image_lib.encodeJpg(image, quality: outletMediaJpegQuality),
  );
  if (encoded.length > outletMediaMaxBytes) {
    throw const OutletPhotoPickerFailure(
      'Ảnh vẫn lớn hơn 5MB sau khi xử lý. Vui lòng chọn ảnh khác.',
    );
  }

  return OutletPhotoDraft(
    clientUploadId: clientUploadId,
    bytes: encoded,
    width: image.width,
    height: image.height,
  );
}

String _pickerErrorMessage(PlatformException error) {
  final code = error.code.toLowerCase();
  if (code.contains('camera_access_denied') ||
      code.contains('cameraaccessdenied')) {
    return 'MCP Field chưa được phép dùng camera. Hãy cấp quyền Camera rồi thử lại.';
  }
  if (code.contains('photo_access_denied') ||
      code.contains('photoaccessdenied')) {
    return 'MCP Field chưa được phép dùng thư viện ảnh. Hãy cấp quyền Ảnh rồi thử lại.';
  }
  if (code.contains('camera') && code.contains('unavailable')) {
    return 'Camera hiện không dùng được. Vui lòng kiểm tra thiết bị rồi thử lại.';
  }
  return 'Không mở được camera hoặc thư viện ảnh. Vui lòng thử lại.';
}
