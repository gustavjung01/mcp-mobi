import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class CustomerBoundaryFailure implements Exception {
  const CustomerBoundaryFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class CustomerVerificationItem {
  const CustomerVerificationItem({
    required this.routeCustomerId,
    required this.routeId,
    required this.customerName,
    required this.status,
    this.routeName,
    this.routeSales,
    this.customerId,
    this.phone,
    this.area,
    this.address,
    this.note,
    this.sortOrder = 0,
    this.active = true,
    this.geoLat,
    this.geoLng,
    this.geoAccuracy,
    this.geoCapturedAt,
    this.coreRequestId,
    this.coreCustomerId,
    this.coreCustomerAddressId,
    this.coreCustomerCode,
    this.reviewReason,
    this.submittedAt,
    this.lastSyncedAt,
    this.updatedAt,
  });

  final String routeCustomerId;
  final String routeId;
  final String customerName;
  final String status;
  final String? routeName;
  final String? routeSales;
  final String? customerId;
  final String? phone;
  final String? area;
  final String? address;
  final String? note;
  final int sortOrder;
  final bool active;
  final double? geoLat;
  final double? geoLng;
  final double? geoAccuracy;
  final String? geoCapturedAt;
  final String? coreRequestId;
  final String? coreCustomerId;
  final String? coreCustomerAddressId;
  final String? coreCustomerCode;
  final String? reviewReason;
  final String? submittedAt;
  final String? lastSyncedAt;
  final String? updatedAt;

  bool get linked =>
      const {'approved', 'linked_existing'}.contains(status) &&
      (coreCustomerId ?? '').isNotEmpty &&
      (coreCustomerAddressId ?? '').isNotEmpty;

  factory CustomerVerificationItem.fromJson(Map<String, dynamic> json) {
    return CustomerVerificationItem(
      routeCustomerId: _text(json['routeCustomerId']),
      routeId: _text(json['routeId']),
      customerName: _text(json['customerName'], fallback: 'Điểm bán'),
      status: _text(json['status'], fallback: 'not_submitted'),
      routeName: _nullableText(json['routeName']),
      routeSales: _nullableText(json['routeSales']),
      customerId: _nullableText(json['customerId']),
      phone: _nullableText(json['phone']),
      area: _nullableText(json['area']),
      address: _nullableText(json['address']),
      note: _nullableText(json['note']),
      sortOrder: _integer(json['sortOrder']),
      active: _boolean(json['active'], fallback: true),
      geoLat: _optionalDouble(json['geoLat']),
      geoLng: _optionalDouble(json['geoLng']),
      geoAccuracy: _optionalDouble(json['geoAccuracy']),
      geoCapturedAt: _nullableText(json['geoCapturedAt']),
      coreRequestId: _nullableText(json['coreRequestId']),
      coreCustomerId: _nullableText(json['coreCustomerId']),
      coreCustomerAddressId: _nullableText(json['coreCustomerAddressId']),
      coreCustomerCode: _nullableText(json['coreCustomerCode']),
      reviewReason: _nullableText(json['reviewReason']),
      submittedAt: _nullableText(json['submittedAt']),
      lastSyncedAt: _nullableText(json['lastSyncedAt']),
      updatedAt: _nullableText(json['updatedAt']),
    );
  }
}

class CompanyCustomer {
  const CompanyCustomer({
    required this.id,
    required this.name,
    required this.status,
    this.customerCode,
    this.phone,
    this.email,
    this.responsibleEmployeeId,
    this.defaultAddressId,
    this.defaultAddressLabel,
    this.defaultAddressLine1,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String status;
  final String? customerCode;
  final String? phone;
  final String? email;
  final String? responsibleEmployeeId;
  final String? defaultAddressId;
  final String? defaultAddressLabel;
  final String? defaultAddressLine1;
  final String? updatedAt;

  factory CompanyCustomer.fromJson(Map<String, dynamic> json) {
    return CompanyCustomer(
      id: _text(json['id']),
      name: _text(json['name'], fallback: 'Khách Công Ty'),
      status: _text(json['status'], fallback: 'active'),
      customerCode: _nullableText(json['customerCode']),
      phone: _nullableText(json['phone']),
      email: _nullableText(json['email']),
      responsibleEmployeeId: _nullableText(json['responsibleEmployeeId']),
      defaultAddressId: _nullableText(json['defaultAddressId']),
      defaultAddressLabel: _nullableText(json['defaultAddressLabel']),
      defaultAddressLine1: _nullableText(json['defaultAddressLine1']),
      updatedAt: _nullableText(json['updatedAt']),
    );
  }
}

abstract interface class CustomerBoundaryClient {
  Future<List<CustomerVerificationItem>> loadVerifications();

  Future<List<CompanyCustomer>> loadCompanyCustomers();

  Future<CustomerVerificationItem> submit({
    required String routeCustomerId,
    required String idempotencyKey,
  });

  Future<CustomerVerificationItem> sync({
    required String routeCustomerId,
    required String idempotencyKey,
  });
}

class HttpCustomerBoundaryClient implements CustomerBoundaryClient {
  HttpCustomerBoundaryClient({
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
      'mobile_customer_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _headers({
    bool hasBody = false,
    String? idempotencyKey,
  }) {
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-Id': _requestId(),
      if (hasBody) 'Content-Type': 'application/json',
      if ((idempotencyKey ?? '').isNotEmpty) 'Idempotency-Key': idempotencyKey!,
    };
  }

  @override
  Future<List<CustomerVerificationItem>> loadVerifications() async {
    final data = await _request('GET', '/api/customer-verifications');
    return _objects(data['items'])
        .map(CustomerVerificationItem.fromJson)
        .where((item) => item.routeCustomerId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<CompanyCustomer>> loadCompanyCustomers() async {
    final data = await _request('GET', '/api/core-customers');
    return _objects(data['customers'])
        .map(CompanyCustomer.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<CustomerVerificationItem> submit({
    required String routeCustomerId,
    required String idempotencyKey,
  }) {
    return _mutate(
      '/api/customer-verifications/submit',
      routeCustomerId: routeCustomerId,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<CustomerVerificationItem> sync({
    required String routeCustomerId,
    required String idempotencyKey,
  }) {
    return _mutate(
      '/api/customer-verifications/sync',
      routeCustomerId: routeCustomerId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<CustomerVerificationItem> _mutate(
    String path, {
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {
    final data = await _request(
      'POST',
      path,
      body: {'routeCustomerId': routeCustomerId},
      idempotencyKey: idempotencyKey,
    );
    final item = CustomerVerificationItem.fromJson(data);
    if (item.routeCustomerId.isEmpty) {
      throw const CustomerBoundaryFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ trạng thái điểm bán.',
        retryable: true,
      );
    }
    return item;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    http.Response response;
    try {
      final uri = _endpoint(path);
      response = switch (method) {
        'POST' =>
          await _client
              .post(
                uri,
                headers: _headers(
                  hasBody: true,
                  idempotencyKey: idempotencyKey,
                ),
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(timeout),
        _ => await _client.get(uri, headers: _headers()).timeout(timeout),
      };
    } on TimeoutException {
      throw const CustomerBoundaryFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const CustomerBoundaryFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được dữ liệu khách hàng. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const CustomerBoundaryFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu khách hàng không hợp lệ.',
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
      throw CustomerBoundaryFailure(
        code: code,
        message: _customerBoundaryErrorMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    final data = _object(payload['data']);
    if (data.isEmpty) {
      throw const CustomerBoundaryFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu khách hàng không hợp lệ.',
        retryable: true,
      );
    }
    return data;
  }
}

String _customerBoundaryErrorMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code.toLowerCase()) {
    case 'route_customer_id_required':
      return 'Chưa xác định được điểm bán cần xử lý.';
    case 'route_customer_not_found':
      return 'Điểm bán không còn tồn tại hoặc đã được gỡ khỏi hệ thống.';
    case 'route_customer_not_owned':
      return 'Điểm bán không còn thuộc phạm vi phụ trách của tài khoản.';
    case 'route_sales_unassigned':
      return 'Tuyến của điểm bán chưa được phân công nhân viên phụ trách.';
    case 'route_sales_ambiguous':
      return 'Phân công tuyến đang trùng. Cần kiểm tra lại người phụ trách.';
    case 'customer_name_required':
      return 'Điểm bán chưa có tên.';
    case 'customer_address_required':
      return 'Cần bổ sung địa chỉ điểm bán trước khi gửi mở hoặc liên kết mã.';
    case 'core_onboarding_not_submitted':
      return 'Điểm bán chưa được gửi sang Công Ty để xác minh.';
    case 'field_profile_payload_mismatch':
      return 'Thông tin điểm bán đã thay đổi sau khi gửi. Cần xử lý đề nghị hiện tại trước.';
    case 'trusted_employee_required':
      return 'Cần đăng nhập bằng tài khoản nhân viên MCP.';
    case 'employee_inactive':
      return 'Tài khoản nhân viên không còn hoạt động.';
  }
  if (statusCode == 401) return 'Phiên đăng nhập không còn hiệu lực.';
  if (statusCode == 403) {
    return serverMessage.isNotEmpty
        ? serverMessage
        : 'Tài khoản chưa được cấp quyền xử lý khách hàng.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'Không xử lý được khách hàng. Vui lòng thử lại.';
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

double? _optionalDouble(Object? value) {
  if (value == null || _text(value).isEmpty) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}

bool _boolean(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = _text(value).toLowerCase();
  if (const {'1', 'true', 'yes', 'on', 'active'}.contains(normalized)) {
    return true;
  }
  if (const {'0', 'false', 'no', 'off', 'inactive'}.contains(normalized)) {
    return false;
  }
  return fallback;
}
