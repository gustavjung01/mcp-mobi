import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SystemEndpointFailure implements Exception {
  const SystemEndpointFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

abstract interface class SystemEndpointProbe {
  Future<void> verify(Uri baseUrl);
}

class HttpSystemEndpointProbe implements SystemEndpointProbe {
  HttpSystemEndpointProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Uri _endpoint(Uri baseUrl, String path) {
    final base = baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, dynamic> _object(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  Future<void> _check(
    Uri baseUrl,
    String path,
    String expectedStatus,
  ) async {
    http.Response response;
    try {
      response = await _client
          .get(
            _endpoint(baseUrl, path),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_TIMEOUT',
        message: 'Kết nối máy chủ quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_UNREACHABLE',
        message: 'Không kết nối được máy chủ hệ thống.',
        retryable: true,
      );
    }

    if (response.statusCode == 404) {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_NOT_MCP',
        message: 'Địa chỉ này không phải máy chủ MCP Field. Không nhập địa chỉ trang web quản lý.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_HTTP_${response.statusCode}',
        message: response.statusCode >= 500
            ? 'Máy chủ hệ thống chưa sẵn sàng. Vui lòng thử lại.'
            : 'Máy chủ hệ thống không chấp nhận kết nối này.',
        retryable: response.statusCode >= 500,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_RESPONSE_INVALID',
        message:
            'Địa chỉ này không trả về thông tin hệ thống MCP Field hợp lệ.',
      );
    }
    final payload = _object(decoded);
    final data = _object(payload['data']);
    if ((data['status'] ?? '').toString().trim() != expectedStatus) {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_RESPONSE_INVALID',
        message:
            'Địa chỉ này không trả về thông tin hệ thống MCP Field hợp lệ.',
      );
    }
  }

  Future<void> _checkMobileApiBoundary(Uri baseUrl) async {
    http.Response response;
    try {
      response = await _client
          .get(
            _endpoint(baseUrl, '/api/mobile-auth/me'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_TIMEOUT',
        message: 'Kết nối máy chủ quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_UNREACHABLE',
        message: 'Không kết nối được máy chủ hệ thống.',
        retryable: true,
      );
    }

    if (response.statusCode == 404) {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_NOT_MCP',
        message:
            'Địa chỉ này không phải máy chủ MCP Field. Không nhập địa chỉ trang web quản lý.',
      );
    }
    if (response.statusCode >= 500) {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_API_UNAVAILABLE',
        message:
            'Máy chủ đang hoạt động nhưng API MCP Field chưa sẵn sàng. Vui lòng thử lại.',
        retryable: true,
      );
    }
    if (response.statusCode != 401) {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_API_INVALID',
        message:
            'Địa chỉ này không trả về API đăng nhập MCP Field hợp lệ.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_API_INVALID',
        message:
            'Địa chỉ này không trả về API đăng nhập MCP Field hợp lệ.',
      );
    }
    final payload = _object(decoded);
    final error = _object(payload['error']);
    final code = (error['code'] ?? '').toString().trim().toLowerCase();
    if (code != 'unauthorized') {
      throw const SystemEndpointFailure(
        code: 'SYSTEM_ENDPOINT_API_INVALID',
        message:
            'Địa chỉ này không trả về API đăng nhập MCP Field hợp lệ.',
      );
    }
  }

  @override
  Future<void> verify(Uri baseUrl) async {
    await _check(baseUrl, '/health/live', 'live');
    await _check(baseUrl, '/health/ready', 'ready');
    await _checkMobileApiBoundary(baseUrl);
  }
}
