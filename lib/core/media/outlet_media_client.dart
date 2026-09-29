import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/mobile_error_mapper.dart';
import '../installation/installation_profile.dart';

const outletMediaMaxPhotos = 3;
const outletMediaMaxBytes = 5 * 1024 * 1024;

class OutletMediaFailure implements Exception {
  const OutletMediaFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class OutletMediaItem {
  const OutletMediaItem({
    required this.id,
    required this.viewUrl,
    this.capturedAt,
    this.width,
    this.height,
  });

  final String id;
  final String viewUrl;
  final String? capturedAt;
  final int? width;
  final int? height;

  factory OutletMediaItem.fromJson(Map<String, dynamic> json) {
    return OutletMediaItem(
      id: _text(json['id']),
      viewUrl: _text(json['viewUrl']),
      capturedAt: _nullableText(json['capturedAt']),
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
    );
  }
}

class OutletMediaProfile {
  const OutletMediaProfile({
    required this.media,
    required this.mediaLimit,
  });

  final List<OutletMediaItem> media;
  final int mediaLimit;

  factory OutletMediaProfile.fromJson(Map<String, dynamic> json) {
    final requestedLimit = _integer(json['mediaLimit']);
    return OutletMediaProfile(
      media: _objects(json['media'])
          .map(OutletMediaItem.fromJson)
          .where((item) => item.id.isNotEmpty && item.viewUrl.isNotEmpty)
          .take(outletMediaMaxPhotos)
          .toList(growable: false),
      mediaLimit: requestedLimit > 0
          ? requestedLimit.clamp(1, outletMediaMaxPhotos).toInt()
          : outletMediaMaxPhotos,
    );
  }
}

abstract interface class OutletMediaClient {
  Future<OutletMediaProfile> loadProfile({
    required String routeCustomerId,
  });

  Future<void> uploadPhoto({
    required String routeCustomerId,
    String? sessionId,
    required String clientUploadId,
    required Uint8List bytes,
    required String mimeType,
    required int width,
    required int height,
  });

  Future<void> deleteMedia({
    required String mediaId,
  });
}

class HttpOutletMediaClient implements OutletMediaClient {
  HttpOutletMediaClient({
    required this.profile,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.uploadTimeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  final InstallationProfile profile;
  final String token;
  final http.Client _client;
  final Duration timeout;
  final Duration uploadTimeout;

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final base = profile.fieldBaseUrl.toString().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse(base + path);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  String _requestId() =>
      'mobile_media_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _headers({bool hasBody = false}) {
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-Id': _requestId(),
      if (hasBody) 'Content-Type': 'application/json',
    };
  }

  @override
  Future<OutletMediaProfile> loadProfile({
    required String routeCustomerId,
  }) async {
    final data = await _jsonRequest(
      'GET',
      '/api/outlet-media/customer-profile',
      query: {'routeCustomerId': routeCustomerId},
    );
    return OutletMediaProfile.fromJson(data);
  }

  @override
  Future<void> uploadPhoto({
    required String routeCustomerId,
    String? sessionId,
    required String clientUploadId,
    required Uint8List bytes,
    required String mimeType,
    required int width,
    required int height,
  }) async {
    if (bytes.isEmpty || bytes.length > outletMediaMaxBytes) {
      throw const OutletMediaFailure(
        code: 'invalid_media_byte_size',
        message: 'Ảnh phải nhỏ hơn hoặc bằng 5MB sau khi xử lý.',
      );
    }

    final init = await _jsonRequest(
      'POST',
      '/api/outlet-media/upload-init',
      body: {
        'routeCustomerId': routeCustomerId,
        if ((sessionId ?? '').trim().isNotEmpty) 'sessionId': sessionId,
        'clientUploadId': clientUploadId,
        'mimeType': mimeType,
        'byteSize': bytes.length,
      },
    );
    final mediaId = _text(init['mediaId']);
    final putUrl = _text(init['putUrl']);
    if (mediaId.isEmpty || putUrl.isEmpty) {
      throw const OutletMediaFailure(
        code: 'UPLOAD_INTENT_INVALID',
        message: 'Hệ thống chưa cấp được phiên gửi ảnh. Vui lòng thử lại.',
        retryable: true,
      );
    }

    try {
      final upload = await _client
          .put(
            Uri.parse(putUrl),
            headers: {'Content-Type': mimeType},
            body: bytes,
          )
          .timeout(uploadTimeout);
      if (upload.statusCode < 200 || upload.statusCode >= 300) {
        throw const OutletMediaFailure(
          code: 'MEDIA_UPLOAD_REJECTED',
          message: 'Không gửi được ảnh lên kho lưu trữ. Vui lòng thử lại.',
          retryable: true,
        );
      }

      await _jsonRequest(
        'POST',
        '/api/outlet-media/upload-finalize',
        body: {
          'mediaId': mediaId,
          'width': width,
          'height': height,
        },
      );
    } on TimeoutException {
      await _discardUploadReservation(mediaId);
      throw const OutletMediaFailure(
        code: 'MEDIA_UPLOAD_TIMEOUT',
        message: 'Gửi ảnh quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      await _discardUploadReservation(mediaId);
      throw const OutletMediaFailure(
        code: 'MEDIA_UPLOAD_NETWORK',
        message: 'Mạng bị gián đoạn khi gửi ảnh. Vui lòng thử lại.',
        retryable: true,
      );
    } catch (_) {
      await _discardUploadReservation(mediaId);
      rethrow;
    }
  }

  @override
  Future<void> deleteMedia({
    required String mediaId,
  }) async {
    await _jsonRequest(
      'POST',
      '/api/outlet-media/delete',
      body: {'mediaId': mediaId},
    );
  }

  Future<void> _discardUploadReservation(String mediaId) async {
    try {
      await deleteMedia(mediaId: mediaId);
    } catch (_) {
      // Giữ nguyên lỗi tải ảnh ban đầu; reservation cũ sẽ tự hết hạn ở backend.
    }
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    http.Response response;
    try {
      final uri = _endpoint(path, query);
      final encoded = body == null ? null : jsonEncode(body);
      response = switch (method) {
        'POST' =>
          await _client
              .post(
                uri,
                headers: _headers(hasBody: true),
                body: encoded,
              )
              .timeout(timeout),
        _ => await _client.get(uri, headers: _headers()).timeout(timeout),
      };
    } on TimeoutException {
      throw const OutletMediaFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const OutletMediaFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được dữ liệu ảnh. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const OutletMediaFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu ảnh không hợp lệ.',
        retryable: true,
      );
    }

    final payload = _object(decoded);
    if (response.statusCode >= 400) {
      final error = _object(payload['error']);
      final code = _text(
        error['code'],
        fallback: _text(payload['error'], fallback: 'REQUEST_FAILED'),
      );
      final serverMessage = _text(error['message']);
      throw OutletMediaFailure(
        code: code,
        message: _mediaErrorMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable: CanonicalApiErrorMapper.isRetryable(
          code: code,
          statusCode: response.statusCode,
          backendRetryable: error['retryable'] == true,
        ),
      );
    }

    final first = _object(payload['data']);
    final nested = _object(first['data']);
    final data = nested.isNotEmpty ? nested : first;
    if (data.isEmpty) {
      throw const OutletMediaFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu ảnh không hợp lệ.',
        retryable: true,
      );
    }
    return data;
  }
}

String _mediaErrorMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code.trim().toLowerCase()) {
    case 'outlet_media_limit_reached':
      return 'Điểm bán chỉ lưu tối đa 3 ảnh.';
    case 'invalid_media_byte_size':
      return 'Ảnh phải nhỏ hơn hoặc bằng 5MB sau khi xử lý.';
    case 'invalid_media_mime_type':
      return 'Định dạng ảnh chưa được hỗ trợ.';
    case 'route_customer_not_found':
      return 'Điểm bán này không còn tồn tại trong hệ thống.';
    case 'linked_customer_not_found':
      return 'Điểm bán chưa liên kết đúng hồ sơ khách hàng. Vui lòng đồng bộ lại.';
    case 'linked_customer_inactive':
      return 'Hồ sơ khách hàng của điểm bán đã ngừng sử dụng.';
    case 'internal_error':
      return 'Hệ thống ảnh đang bận. Vui lòng thử lại sau.';
    case 'r2_not_configured':
      return 'Kho ảnh của hệ thống chưa được cấu hình.';
    case 'r2_object_not_found':
      return 'Ảnh chưa được kho lưu trữ xác nhận. Vui lòng thử lại.';
  }
  return CanonicalApiErrorMapper.message(
    code: code,
    statusCode: statusCode,
    serverMessage: serverMessage,
    fallbackMessage: 'Không xử lý được ảnh điểm bán. Vui lòng thử lại.',
    forbiddenMessage: 'Tài khoản chưa được cấp quyền quản lý ảnh điểm bán.',
    notFoundMessage: 'Ảnh hoặc điểm bán không còn sẵn sàng. Cập nhật lại rồi thử.',
    conflictMessage: 'Thông tin ảnh điểm bán đã thay đổi. Cập nhật lại rồi tiếp tục.',
    unavailableMessage: 'Hệ thống ảnh đang tạm thời chưa sẵn sàng. Vui lòng thử lại.',
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_object)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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

int? _optionalInt(Object? value) {
  if (value == null || _text(value).isEmpty) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}
