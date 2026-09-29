import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class MobileSession {
  const MobileSession({
    required this.token,
    required this.employeeId,
    required this.loginName,
    required this.displayName,
    required this.expiresAt,
    this.roles = const [],
    this.permissions = const [],
    this.scopes = const [],
  });

  final String token;
  final String employeeId;
  final String loginName;
  final String displayName;
  final DateTime? expiresAt;
  final List<String> roles;
  final List<String> permissions;
  final List<String> scopes;
}

class AuthFailure implements Exception {
  const AuthFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'AuthFailure(code: $code, message: $message, retryable: $retryable)';
}

abstract interface class MobileAuthClient {
  Future<MobileSession> login({
    required InstallationProfile profile,
    required String loginName,
    required String password,
    String ownerCode = '',
  });

  Future<MobileSession> me({
    required InstallationProfile profile,
    required String token,
  });

  Future<void> logout({
    required InstallationProfile profile,
    required String token,
  });
}

class HttpMobileAuthClient implements MobileAuthClient {
  HttpMobileAuthClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Uri _endpoint(InstallationProfile profile, String path) {
    final base = profile.baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  String _requestId() {
    return 'mobile_${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, dynamic> _object(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _scopeStrings(Object? value) {
    if (value is List) return _strings(value);
    final source = _object(value);
    final output = <String>[];
    for (final key in ['branchIds', 'warehouseIds', 'territoryIds']) {
      output.addAll(_strings(source[key]));
    }
    return output.toSet().toList(growable: false);
  }

  AuthFailure _failure(http.Response response, Object? decoded) {
    final payload = _object(decoded);
    final error = _object(payload['error']);
    final status = response.statusCode;
    final code =
        (error['code'] ?? (status == 401 ? 'UNAUTHORIZED' : 'REQUEST_FAILED'))
            .toString()
            .trim();
    final serverMessage = (error['message'] ?? '').toString().trim();

    String message;
    if (code == 'INTERNAL_AUTH_INVALID_CREDENTIALS') {
      message = 'Tên đăng nhập hoặc mật khẩu chưa đúng.';
    } else if (code == 'INTERNAL_AUTH_OWNER_CHALLENGE_REQUIRED') {
      message = 'Nhập mã xác nhận đã gửi để tiếp tục.';
    } else if (code == 'INTERNAL_AUTH_OWNER_CODE_INVALID') {
      message = 'Mã xác nhận chưa đúng hoặc đã hết hạn.';
    } else if (status == 401 || status == 403) {
      message = 'Phiên đăng nhập không còn hiệu lực.';
    } else if (status >= 500) {
      message = 'Hệ thống tạm thời chưa sẵn sàng. Vui lòng thử lại.';
    } else {
      message = serverMessage.isNotEmpty
          ? serverMessage
          : 'Không thể thực hiện yêu cầu. Vui lòng thử lại.';
    }

    return AuthFailure(
      code: code,
      message: message,
      retryable: error['retryable'] == true || status >= 500,
    );
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw const AuthFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const AuthFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không kết nối được hệ thống. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const AuthFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
        retryable: true,
      );
    }
  }

  MobileSession _sessionFromLogin(Object? decoded) {
    final payload = _object(decoded);
    final data = _object(payload['data']);
    final user = _object(data['user']);
    final session = _object(data['session']);
    final token = (data['token'] ?? '').toString().trim();
    final employeeId = (user['employeeId'] ?? '').toString().trim();
    final loginName = (user['loginName'] ?? '').toString().trim();
    final displayName = (user['employeeFullName'] ?? '').toString().trim();
    if (!token.startsWith('nppusr.') ||
        employeeId.isEmpty ||
        loginName.isEmpty ||
        displayName.isEmpty) {
      throw const AuthFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu đăng nhập không hợp lệ.',
        retryable: true,
      );
    }

    return MobileSession(
      token: token,
      employeeId: employeeId,
      loginName: loginName,
      displayName: displayName,
      expiresAt: DateTime.tryParse((session['expiresAt'] ?? '').toString()),
      roles: _strings(user['roles']),
      permissions: _strings(user['permissions']),
      scopes: _scopeStrings(user['scopes']),
    );
  }

  MobileSession _sessionFromMe(Object? decoded, String token) {
    final payload = _object(decoded);
    final data = _object(payload['data']);
    final session = _object(data['session']);
    final employeeId = (data['employeeId'] ?? '').toString().trim();
    final loginName = (session['loginName'] ?? '').toString().trim();
    final displayName = (session['employeeFullName'] ?? '').toString().trim();
    if (employeeId.isEmpty || loginName.isEmpty || displayName.isEmpty) {
      throw const AuthFailure(
        code: 'RESPONSE_INVALID',
        message: 'Không đọc được thông tin phiên đăng nhập.',
        retryable: true,
      );
    }

    return MobileSession(
      token: token,
      employeeId: employeeId,
      loginName: loginName,
      displayName: displayName,
      expiresAt: DateTime.tryParse((session['expiresAt'] ?? '').toString()),
      roles: _strings(data['roles']),
      permissions: _strings(data['permissions']),
      scopes: _scopeStrings(data['scopes']),
    );
  }

  @override
  Future<MobileSession> login({
    required InstallationProfile profile,
    required String loginName,
    required String password,
    String ownerCode = '',
  }) async {
    final response = await _send(
      _client.post(
        _endpoint(profile, '/api/mobile-auth/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Request-Id': _requestId(),
        },
        body: jsonEncode({
          'loginName': loginName.trim(),
          'password': password,
          if (ownerCode.trim().isNotEmpty) 'ownerCode': ownerCode.trim(),
        }),
      ),
    );
    final decoded = _decode(response);
    if (response.statusCode >= 400) throw _failure(response, decoded);
    return _sessionFromLogin(decoded);
  }

  @override
  Future<MobileSession> me({
    required InstallationProfile profile,
    required String token,
  }) async {
    Future<http.Response> sendMe() => _send(
      _client.get(
        _endpoint(profile, '/api/mobile-auth/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Request-Id': _requestId(),
        },
      ),
    );

    http.Response response;
    try {
      response = await sendMe();
    } on AuthFailure catch (error) {
      if (!error.retryable) rethrow;
      response = await sendMe();
    }
    final decoded = _decode(response);
    if (response.statusCode >= 400) throw _failure(response, decoded);
    return _sessionFromMe(decoded, token);
  }

  @override
  Future<void> logout({
    required InstallationProfile profile,
    required String token,
  }) async {
    final response = await _send(
      _client.post(
        _endpoint(profile, '/api/mobile-auth/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Request-Id': _requestId(),
        },
      ),
    );
    if (response.statusCode >= 400) {
      throw _failure(response, _decode(response));
    }
  }
}
