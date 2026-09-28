import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'outlet_photo_picker.dart';

class OutletPhotoPendingFailure implements Exception {
  const OutletPhotoPendingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class PendingOutletPhoto {
  const PendingOutletPhoto({
    required this.routeCustomerId,
    required this.customerName,
    required this.draft,
    this.sessionId,
  });

  final String routeCustomerId;
  final String customerName;
  final String? sessionId;
  final OutletPhotoDraft draft;
}

abstract interface class OutletPhotoPendingStore {
  Future<List<PendingOutletPhoto>> load({String? routeCustomerId});

  Future<void> save(PendingOutletPhoto item);

  Future<void> remove(String clientUploadId);
}

class DeviceOutletPhotoPendingStore implements OutletPhotoPendingStore {
  const DeviceOutletPhotoPendingStore();

  static const _channel = MethodChannel('com.hungphat.mcpfield/storage');
  static final _safeId = RegExp(r'^[A-Za-z0-9._-]+$');

  Future<Directory> _directory() async {
    try {
      final path = (await _channel.invokeMethod<String>(
        'pendingMediaDirectory',
      ))
          ?.trim();
      if ((path ?? '').isEmpty) {
        throw const OutletPhotoPendingFailure(
          'Không chuẩn bị được nơi lưu ảnh chờ gửi.',
        );
      }
      final directory = Directory(path!);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } on OutletPhotoPendingFailure {
      rethrow;
    } on PlatformException {
      throw const OutletPhotoPendingFailure(
        'Không chuẩn bị được nơi lưu ảnh chờ gửi.',
      );
    } on MissingPluginException {
      throw const OutletPhotoPendingFailure(
        'Không chuẩn bị được nơi lưu ảnh chờ gửi.',
      );
    } on FileSystemException {
      throw const OutletPhotoPendingFailure(
        'Không lưu được ảnh chờ gửi trên thiết bị.',
      );
    }
  }

  String _id(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !_safeId.hasMatch(value)) {
      throw const OutletPhotoPendingFailure(
        'Mã ảnh chờ gửi chưa hợp lệ.',
      );
    }
    return value;
  }

  @override
  Future<List<PendingOutletPhoto>> load({String? routeCustomerId}) async {
    final requested = (routeCustomerId ?? '').trim();
    final directory = await _directory();
    final result = <PendingOutletPhoto>[];

    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        Map<String, dynamic> json;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map) continue;
          json = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        } on FormatException {
          continue;
        }

        final clientUploadId = (json['clientUploadId'] ?? '').toString().trim();
        final storedRouteId = (json['routeCustomerId'] ?? '').toString().trim();
        if (clientUploadId.isEmpty ||
            !_safeId.hasMatch(clientUploadId) ||
            storedRouteId.isEmpty ||
            (requested.isNotEmpty && storedRouteId != requested)) {
          continue;
        }

        final width = _integer(json['width']);
        final height = _integer(json['height']);
        if (width <= 0 || height <= 0) continue;

        final photo = File('${directory.path}/$clientUploadId.jpg');
        if (!await photo.exists()) continue;
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty) continue;

        result.add(
          PendingOutletPhoto(
            routeCustomerId: storedRouteId,
            customerName: (json['customerName'] ?? 'Điểm bán')
                .toString()
                .trim(),
            sessionId: _nullableText(json['sessionId']),
            draft: OutletPhotoDraft(
              clientUploadId: clientUploadId,
              bytes: Uint8List.fromList(bytes),
              width: width,
              height: height,
              status: _status(json['status']),
            ),
          ),
        );
      }
    } on FileSystemException {
      throw const OutletPhotoPendingFailure(
        'Không đọc được ảnh chờ gửi trên thiết bị.',
      );
    }

    result.sort(
      (left, right) => left.draft.clientUploadId.compareTo(
        right.draft.clientUploadId,
      ),
    );
    return result;
  }

  @override
  Future<void> save(PendingOutletPhoto item) async {
    final routeCustomerId = item.routeCustomerId.trim();
    if (routeCustomerId.isEmpty) {
      throw const OutletPhotoPendingFailure(
        'Chưa xác định được điểm bán của ảnh chờ gửi.',
      );
    }
    final id = _id(item.draft.clientUploadId);
    final directory = await _directory();
    final photo = File('${directory.path}/$id.jpg');
    final metadata = File('${directory.path}/$id.json');
    final photoTmp = File('${photo.path}.tmp');
    final metadataTmp = File('${metadata.path}.tmp');

    try {
      await photoTmp.writeAsBytes(item.draft.bytes, flush: true);
      if (await photo.exists()) await photo.delete();
      await photoTmp.rename(photo.path);

      await metadataTmp.writeAsString(
        jsonEncode({
          'clientUploadId': id,
          'routeCustomerId': routeCustomerId,
          'customerName': item.customerName.trim(),
          if ((item.sessionId ?? '').trim().isNotEmpty)
            'sessionId': item.sessionId!.trim(),
          'width': item.draft.width,
          'height': item.draft.height,
          'status': item.draft.status.name,
        }),
        flush: true,
      );
      if (await metadata.exists()) await metadata.delete();
      await metadataTmp.rename(metadata.path);
    } on FileSystemException {
      try {
        if (await photoTmp.exists()) await photoTmp.delete();
        if (await metadataTmp.exists()) await metadataTmp.delete();
      } catch (_) {}
      throw const OutletPhotoPendingFailure(
        'Không lưu được ảnh chờ gửi trên thiết bị.',
      );
    }
  }

  @override
  Future<void> remove(String clientUploadId) async {
    final id = _id(clientUploadId);
    final directory = await _directory();
    try {
      final photo = File('${directory.path}/$id.jpg');
      final metadata = File('${directory.path}/$id.json');
      if (await photo.exists()) await photo.delete();
      if (await metadata.exists()) await metadata.delete();
    } on FileSystemException {
      throw const OutletPhotoPendingFailure(
        'Không xóa được ảnh chờ gửi trên thiết bị.',
      );
    }
  }
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

String? _nullableText(Object? value) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}

OutletPhotoStatus _status(Object? value) {
  final name = (value ?? '').toString().trim();
  return OutletPhotoStatus.values.firstWhere(
    (item) => item.name == name,
    orElse: () => OutletPhotoStatus.pending,
  );
}
