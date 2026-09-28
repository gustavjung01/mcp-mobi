import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class OrderDataFailure implements Exception {
  const OrderDataFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class OrderCatalogItem {
  const OrderCatalogItem({
    required this.productId,
    required this.variantId,
    required this.name,
    this.brand,
    this.category,
    this.sku,
    this.variantName,
    this.sizeLabel,
    this.sellUnit,
    this.packUnit,
    this.packQuantity,
    this.price,
  });

  final String productId;
  final String variantId;
  final String name;
  final String? brand;
  final String? category;
  final String? sku;
  final String? variantName;
  final String? sizeLabel;
  final String? sellUnit;
  final String? packUnit;
  final double? packQuantity;
  final double? price;

  factory OrderCatalogItem.fromJson(Map<String, dynamic> json) {
    return OrderCatalogItem(
      productId: _text(json['productId']),
      variantId: _text(json['variantId']),
      name: _text(json['name'], fallback: 'Sản phẩm'),
      brand: _nullableText(json['brand']),
      category: _nullableText(json['category']),
      sku: _nullableText(json['sku']),
      variantName: _nullableText(json['variantName']),
      sizeLabel: _nullableText(json['sizeLabel']),
      sellUnit: _nullableText(json['sellUnit']),
      packUnit: _nullableText(json['packUnit']),
      packQuantity: _optionalDouble(json['packQuantity']),
      price: _optionalDouble(json['price']),
    );
  }

  String get purchaseUnitLabel {
    final unit = (sellUnit ?? '').trim().toLowerCase();
    if (RegExp(r'(^|\\s)(thùng|thung|case|carton)(\\s|$)').hasMatch(unit)) {
      return 'Thùng';
    }
    return 'Lẻ';
  }

  String get purchaseUnitDetail {
    final rawVariant = (variantName ?? '').trim();
    final variant = const {'mặc định', 'mac dinh'}.contains(rawVariant.toLowerCase())
        ? ''
        : rawVariant;
    final pack = (packUnit ?? '').trim().isNotEmpty && packQuantity != null
        ? '${packUnit!.trim()} ${_compactNumber(packQuantity!)}'
        : '';
    final values = <String?>[variant, sizeLabel, sellUnit, pack, sku];
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final text = (value ?? '').trim();
      if (text.isEmpty ||
          text.toLowerCase() == purchaseUnitLabel.toLowerCase() ||
          !seen.add(text.toLowerCase())) {
        continue;
      }
      normalized.add(text);
    }
    return normalized.isEmpty ? 'Quy cách chuẩn' : normalized.join(' · ');
  }

  String get secondaryLabel => '$purchaseUnitLabel · $purchaseUnitDetail';
}

class OrderLineInput {
  const OrderLineInput({
    required this.variantId,
    required this.quantity,
    this.note,
  });

  final String variantId;
  final int quantity;
  final String? note;

  Map<String, Object?> toJson() => {
    'variantId': variantId,
    'quantity': quantity.toString(),
    if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
  };
}

class FieldOrderLine {
  const FieldOrderLine({
    required this.id,
    required this.variantId,
    required this.itemName,
    this.lineNumber = 0,
    this.sku,
    this.unitCode,
    this.unitName,
    this.quantity = 0,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.note,
  });

  final String id;
  final int lineNumber;
  final String variantId;
  final String itemName;
  final String? sku;
  final String? unitCode;
  final String? unitName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final String? note;

  String get unitLabel {
    final name = (unitName ?? '').trim();
    if (name.isNotEmpty) return name;
    return (unitCode ?? '').trim();
  }

  factory FieldOrderLine.fromJson(Map<String, dynamic> json) {
    return FieldOrderLine(
      id: _text(json['id']),
      lineNumber: _integer(json['lineNumber']),
      variantId: _text(json['variantId']),
      itemName: _text(
        json['itemName'],
        fallback: _text(json['productName'], fallback: 'Sản phẩm'),
      ),
      sku: _nullableText(json['sku']),
      unitCode: _nullableText(json['unitCode']),
      unitName: _nullableText(json['unitName']),
      quantity: _optionalDouble(json['quantity']) ?? 0,
      unitPrice: _optionalDouble(json['unitPrice']) ?? 0,
      lineTotal: _optionalDouble(json['lineTotal']) ?? 0,
      note: _nullableText(json['note']),
    );
  }
}

class FieldOrderVersion {
  const FieldOrderVersion({
    required this.versionNumber,
    required this.status,
    this.subtotal = 0,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.total = 0,
    this.note,
    this.createdAt,
    this.lines = const [],
  });

  final String versionNumber;
  final String status;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
  final String? note;
  final String? createdAt;
  final List<FieldOrderLine> lines;

  factory FieldOrderVersion.fromJson(Map<String, dynamic> json) {
    return FieldOrderVersion(
      versionNumber: _text(json['versionNumber'], fallback: '1'),
      status: _text(json['status'], fallback: 'draft'),
      subtotal: _optionalDouble(json['subtotal']) ?? 0,
      discountTotal: _optionalDouble(json['discountTotal']) ?? 0,
      taxTotal: _optionalDouble(json['taxTotal']) ?? 0,
      total: _optionalDouble(json['total']) ?? 0,
      note: _nullableText(json['note']),
      createdAt: _nullableText(json['createdAt']),
      lines: _objects(json['lines'])
          .map(FieldOrderLine.fromJson)
          .toList(growable: false),
    );
  }
}

class FieldOrder {
  const FieldOrder({
    required this.id,
    required this.status,
    this.number,
    this.sourceOutletId,
    this.sourceType,
    this.customerId,
    this.customerCode,
    this.customerName,
    this.createdAt,
    this.updatedAt,
    this.currentVersionNumber,
    this.revision,
    this.note,
    this.total,
    this.versions = const [],
  });

  final String id;
  final String status;
  final String? number;
  final String? sourceOutletId;
  final String? sourceType;
  final String? customerId;
  final String? customerCode;
  final String? customerName;
  final String? createdAt;
  final String? updatedAt;
  final String? currentVersionNumber;
  final String? revision;
  final String? note;
  final double? total;
  final List<FieldOrderVersion> versions;

  FieldOrderVersion? get currentVersion {
    if (versions.isEmpty) return null;
    final wanted = (currentVersionNumber ?? '').trim();
    if (wanted.isNotEmpty) {
      for (final version in versions) {
        if (version.versionNumber == wanted) return version;
      }
    }
    return versions.last;
  }

  factory FieldOrder.fromJson(Map<String, dynamic> json) {
    final versions = _objects(json['versions'])
        .map(FieldOrderVersion.fromJson)
        .toList(growable: true)
      ..sort(
        (left, right) =>
            _integer(left.versionNumber).compareTo(_integer(right.versionNumber)),
      );
    final currentVersionNumber = _nullableText(json['currentVersionNumber']) ??
        (versions.isEmpty ? null : versions.last.versionNumber);
    FieldOrderVersion? current;
    if (currentVersionNumber != null) {
      for (final version in versions) {
        if (version.versionNumber == currentVersionNumber) {
          current = version;
          break;
        }
      }
    }
    current ??= versions.isEmpty ? null : versions.last;

    return FieldOrder(
      id: _text(json['id']),
      status: _text(json['status'], fallback: 'draft'),
      number: _nullableText(json['number']),
      sourceOutletId: _nullableText(json['sourceOutletId']),
      sourceType: _nullableText(json['sourceType']),
      customerId: _nullableText(json['customerId']),
      customerCode: _nullableText(json['customerCode']),
      customerName: _nullableText(json['customerName']),
      createdAt: _nullableText(json['createdAt']) ?? current?.createdAt,
      updatedAt: _nullableText(json['updatedAt']),
      currentVersionNumber: currentVersionNumber,
      revision: _nullableText(json['revision']),
      note: _nullableText(json['note']) ?? current?.note,
      total: _orderTotal(json),
      versions: List<FieldOrderVersion>.unmodifiable(versions),
    );
  }
}

abstract interface class OrderDataClient {
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  });

  Future<List<FieldOrder>> loadOrders();

  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  });
}

class HttpOrderDataClient implements OrderDataClient {
  HttpOrderDataClient({
    required this.profile,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final InstallationProfile profile;
  final String token;
  final http.Client _client;
  final Duration timeout;

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
      'mobile_order_${DateTime.now().microsecondsSinceEpoch}';

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
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async {
    final params = <String, String>{
      'q': query.trim(),
      'limit': '50',
      'includePrice': 'true',
      if ((category ?? '').trim().isNotEmpty) 'category': category!.trim(),
      if ((brand ?? '').trim().isNotEmpty) 'brand': brand!.trim(),
    };
    final data = await _request(
      'GET',
      '/api/core-sales/products/search',
      query: params,
    );
    return _objects(data)
        .map(OrderCatalogItem.fromJson)
        .where(
          (item) =>
              item.productId.isNotEmpty &&
              item.variantId.isNotEmpty &&
              item.name.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<List<FieldOrder>> loadOrders() async {
    final data = await _request('GET', '/api/core-sales/orders');
    return _objects(data)
        .map(FieldOrder.fromJson)
        .where((order) => order.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) async {
    final data = await _request(
      'POST',
      '/api/core-sales/orders',
      body: {
        'customerId': customerId,
        'customerAddressId': customerAddressId,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        'lines': lines.map((line) => line.toJson()).toList(growable: false),
      },
      idempotencyKey: idempotencyKey,
    );
    final order = _object(data);
    if (order.isEmpty || _text(order['id']).isEmpty) {
      throw const OrderDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Công Ty chưa trả đủ thông tin đơn vừa tạo.',
        retryable: true,
      );
    }
    return FieldOrder.fromJson(order);
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? idempotencyKey,
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
                headers: _headers(
                  hasBody: true,
                  idempotencyKey: idempotencyKey,
                ),
                body: encoded,
              )
              .timeout(timeout),
        _ => await _client.get(uri, headers: _headers()).timeout(timeout),
      };
    } on TimeoutException {
      throw const OrderDataFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const OrderDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được dữ liệu đơn hàng. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const OrderDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu đơn hàng không hợp lệ.',
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
      throw OrderDataFailure(
        code: code,
        message: _orderErrorMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    if (!payload.containsKey('data')) {
      throw const OrderDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu đơn hàng không hợp lệ.',
        retryable: true,
      );
    }
    return payload['data'];
  }
}

String _orderErrorMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code) {
    case 'core_customer_reference_required':
      return 'Điểm bán chưa liên kết đủ thông tin khách Công Ty để ra đơn.';
    case 'core_customer_not_owned':
      return 'Khách hàng không còn thuộc phạm vi phụ trách của nhân viên.';
    case 'core_customer_address_not_available':
      return 'Khách hàng chưa có địa chỉ giao hàng đang hoạt động.';
    case 'order_lines_required':
      return 'Chọn ít nhất một sản phẩm.';
    case 'invalid_order_quantity':
      return 'Số lượng sản phẩm không hợp lệ.';
    case 'invalid_order_payload':
      return 'Thông tin đơn hàng chưa hợp lệ.';
    case 'browser_commercial_authority_forbidden':
      return 'Giá và chính sách thương mại do Công Ty xác định.';
    case 'idempotency_key_required':
    case 'invalid_idempotency_key':
      return 'Phiên gửi đơn chưa hợp lệ. Vui lòng thử lại.';
  }
  if (statusCode == 401) return 'Phiên đăng nhập không còn hiệu lực.';
  if (statusCode == 403) {
    return serverMessage.isNotEmpty
        ? serverMessage
        : 'Tài khoản chưa được cấp quyền tạo đơn hàng.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'Không xử lý được đơn hàng. Vui lòng thử lại.';
}

double? _orderTotal(Map<String, dynamic> json) {
  final direct = _optionalDouble(json['total']);
  if (direct != null) return direct;
  final versions = _objects(json['versions']);
  if (versions.isEmpty) return null;
  versions.sort(
    (left, right) => _integer(
      left['versionNumber'],
    ).compareTo(_integer(right['versionNumber'])),
  );
  return _optionalDouble(versions.last['total']);
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
      .toList(growable: true);
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

String _compactNumber(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString();
}
