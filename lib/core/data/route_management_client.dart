import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';
import 'field_data_client.dart';

abstract interface class RouteManagementClient {
  Future<void> createRoute({
    required String routeName,
    required String area,
    int? weekday,
    String note = '',
    required String idempotencyKey,
  });

  Future<void> updateRoute({
    required String routeId,
    String? routeName,
    String? area,
    int? weekday,
    String? note,
    bool? active,
    required String idempotencyKey,
  });

  Future<void> archiveRoute({
    required String routeId,
    required String idempotencyKey,
  });

  Future<void> addRouteCustomer({
    required String routeId,
    required String customerName,
    String phone = '',
    String area = '',
    String address = '',
    int? sortOrder,
    String note = '',
    bool includeActiveSession = false,
    String? activeSessionId,
    required String idempotencyKey,
  });

  Future<void> updateRouteCustomer({
    required String routeCustomerId,
    String? customerName,
    String? phone,
    String? area,
    String? address,
    int? sortOrder,
    String? note,
    bool? active,
    required String idempotencyKey,
  });

  Future<void> archiveRouteCustomer({
    required String routeCustomerId,
    required String idempotencyKey,
  });

  Future<void> updateSession({
    required String sessionId,
    String? status,
    String? note,
    DateTime? sessionDate,
    required String idempotencyKey,
  });

  Future<void> deleteEmptySession({
    required String sessionId,
    required String idempotencyKey,
  });
}

class HttpRouteManagementClient implements RouteManagementClient {
  HttpRouteManagementClient({
    required this.profile,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final InstallationProfile profile;
  final String token;
  final http.Client _client;
  final Duration timeout;

  Uri _endpoint(String path) {
    final base = profile.fieldBaseUrl.toString().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    return Uri.parse(base + path);
  }

  String _requestId() =>
      'mobile_route_mgmt_${DateTime.now().microsecondsSinceEpoch}';

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    required String idempotencyKey,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-Id': _requestId(),
      'Idempotency-Key': idempotencyKey,
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      response = switch (method) {
        'POST' => await _client
            .post(
              _endpoint(path),
              headers: headers,
              body: encodedBody,
            )
            .timeout(timeout),
        'PATCH' => await _client
            .patch(
              _endpoint(path),
              headers: headers,
              body: encodedBody,
            )
            .timeout(timeout),
        'DELETE' => await _client
            .delete(
              _endpoint(path),
              headers: headers,
              body: encodedBody,
            )
            .timeout(timeout),
        _ => throw ArgumentError.value(method, 'method'),
      };
    } on TimeoutException {
      throw const FieldDataFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const FieldDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không kết nối được hệ thống. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FieldDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
        retryable: true,
      );
    }

    final payload = _object(decoded);
    if (response.statusCode >= 400) {
      final error = _object(payload['error']);
      final code = _text(error['code'], fallback: 'REQUEST_FAILED');
      final serverMessage = _text(error['message']);
      throw FieldDataFailure(
        code: code,
        message: _businessMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable:
            response.statusCode >= 500 ||
            error['retryable'] == true ||
            code == 'NETWORK_TIMEOUT',
      );
    }

    return _object(payload['data']);
  }

  @override
  Future<void> createRoute({
    required String routeName,
    required String area,
    int? weekday,
    String note = '',
    required String idempotencyKey,
  }) async {
    await _request(
      'POST',
      '/api/routes',
      body: {
        'routeName': routeName.trim(),
        if (area.trim().isNotEmpty) 'area': area.trim(),
        if (weekday != null) 'weekday': weekday,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> updateRoute({
    required String routeId,
    String? routeName,
    String? area,
    int? weekday,
    String? note,
    bool? active,
    required String idempotencyKey,
  }) async {
    await _request(
      'PATCH',
      '/api/routes/${Uri.encodeComponent(routeId.trim())}',
      body: {
        if (routeName != null) 'routeName': routeName.trim(),
        if (area != null) 'area': area.trim(),
        if (weekday != null) 'weekday': weekday,
        if (note != null) 'note': note.trim(),
        if (active != null) 'active': active,
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> archiveRoute({
    required String routeId,
    required String idempotencyKey,
  }) async {
    await _request(
      'POST',
      '/api/routes/${Uri.encodeComponent(routeId.trim())}/archive',
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerName,
    String phone = '',
    String area = '',
    String address = '',
    int? sortOrder,
    String note = '',
    bool includeActiveSession = false,
    String? activeSessionId,
    required String idempotencyKey,
  }) async {
    await _request(
      'POST',
      '/api/route-customers',
      body: {
        'routeId': routeId.trim(),
        'customerName': customerName.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (area.trim().isNotEmpty) 'area': area.trim(),
        if (address.trim().isNotEmpty) 'address': address.trim(),
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        'includeActiveSession': includeActiveSession,
        if (includeActiveSession && (activeSessionId ?? '').trim().isNotEmpty)
          'activeSessionId': activeSessionId!.trim(),
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> updateRouteCustomer({
    required String routeCustomerId,
    String? customerName,
    String? phone,
    String? area,
    String? address,
    int? sortOrder,
    String? note,
    bool? active,
    required String idempotencyKey,
  }) async {
    await _request(
      'PATCH',
      '/api/route-customers/${Uri.encodeComponent(routeCustomerId.trim())}',
      body: {
        if (customerName != null) 'customerName': customerName.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (area != null) 'area': area.trim(),
        if (address != null) 'address': address.trim(),
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (note != null) 'note': note.trim(),
        if (active != null) 'active': active,
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> archiveRouteCustomer({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    await _request(
      'POST',
      '/api/route-customers/${Uri.encodeComponent(routeCustomerId.trim())}/archive',
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    String? status,
    String? note,
    DateTime? sessionDate,
    required String idempotencyKey,
  }) async {
    await _request(
      'PATCH',
      '/api/mcp-sessions/${Uri.encodeComponent(sessionId.trim())}',
      body: {
        if (status != null) 'status': status.trim(),
        if (note != null) 'note': note.trim(),
        if (sessionDate != null) 'sessionDate': _dateOnly(sessionDate),
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> deleteEmptySession({
    required String sessionId,
    required String idempotencyKey,
  }) async {
    await _request(
      'DELETE',
      '/api/mcp-sessions/${Uri.encodeComponent(sessionId.trim())}',
      idempotencyKey: idempotencyKey,
    );
  }
}

String _businessMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code) {
    case 'route_active_session_exists':
      return 'Đang có một phiên tuyến khác hoạt động. Kết thúc hoặc hủy phiên đó trước.';
    case 'route_active_session_ambiguous':
      return 'Có nhiều phiên đang hoạt động. Cần xử lý trạng thái phiên trước khi tiếp tục.';
    case 'session_has_activity':
    case 'session_delete_has_activity':
      return 'Phiên đã có tác nghiệp nên không thể xóa. Hãy hủy hoặc kết thúc phiên.';
    case 'session_delete_cancel_instead':
      return 'Phiên này không thể xóa trực tiếp. Hãy hủy phiên.';
    case 'session_closed':
    case 'session_read_only':
      return 'Phiên đã đóng và chỉ còn chế độ xem.';
    case 'route_not_found':
      return 'Tuyến không còn tồn tại hoặc đã ngừng sử dụng.';
    case 'route_customer_not_found':
      return 'Điểm bán không còn trong tuyến.';
    case 'route_name_required':
      return 'Cần nhập tên tuyến.';
    case 'customer_name_required':
      return 'Cần nhập tên điểm bán.';
  }
  if (statusCode == 401) return 'Phiên đăng nhập không còn hiệu lực.';
  if (statusCode == 403) {
    return serverMessage.isNotEmpty
        ? serverMessage
        : 'Tài khoản chưa được cấp quyền thực hiện thao tác này.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'Không xử lý được yêu cầu. Vui lòng thử lại.';
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

String _text(Object? value, {String fallback = ''}) {
  final valueText = (value ?? '').toString().trim();
  return valueText.isEmpty ? fallback : valueText;
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
