import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

enum FieldActivityKind {
  report,
  productTrial,
  followup,
}

extension FieldActivityKindContract on FieldActivityKind {
  String get operation => switch (this) {
    FieldActivityKind.report => 'session-customer.report.create',
    FieldActivityKind.productTrial => 'session-customer.test.create',
    FieldActivityKind.followup => 'session-customer.followup.create',
  };

  String get path => switch (this) {
    FieldActivityKind.report => '/api/mcp-day/session-customer/report',
    FieldActivityKind.productTrial => '/api/mcp-day/session-customer/test',
    FieldActivityKind.followup => '/api/mcp-day/session-customer/followup',
  };

  String get entityType => switch (this) {
    FieldActivityKind.report => 'report',
    FieldActivityKind.productTrial => 'product_trial',
    FieldActivityKind.followup => 'followup',
  };

  String get businessLabel => switch (this) {
    FieldActivityKind.report => 'Báo cáo',
    FieldActivityKind.productTrial => 'Thử sản phẩm',
    FieldActivityKind.followup => 'Công việc theo dõi',
  };
}

FieldActivityKind? fieldActivityKindFromOperation(String operation) {
  for (final kind in FieldActivityKind.values) {
    if (kind.operation == operation) return kind;
  }
  return null;
}

class FieldActivityFailure implements Exception {
  const FieldActivityFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class FieldActivityResult {
  const FieldActivityResult({
    required this.referenceId,
    required this.data,
  });

  final String referenceId;
  final Map<String, dynamic> data;
}

class FieldReportSettingItem {
  const FieldReportSettingItem({
    required this.id,
    required this.key,
    required this.label,
    required this.value,
    required this.groupKey,
    required this.groupTitle,
    this.category = '',
    this.brandName = '',
    this.productId = '',
    this.status = 'active',
    this.sortOrder = 0,
  });

  final String id;
  final String key;
  final String label;
  final String value;
  final String groupKey;
  final String groupTitle;
  final String category;
  final String brandName;
  final String productId;
  final String status;
  final int sortOrder;

  Map<String, Object?> toSelectionJson() => {
    'id': id,
    'key': key,
    'label': label,
    'value': value,
    'groupKey': groupKey,
    'groupTitle': groupTitle,
    if (category.isNotEmpty) 'category': category,
    if (brandName.isNotEmpty) 'brandName': brandName,
    if (productId.isNotEmpty) 'productId': productId,
  };
}

class FieldReportSettingGroup {
  const FieldReportSettingGroup({
    required this.id,
    required this.key,
    required this.title,
    required this.items,
    this.description = '',
    this.status = 'active',
    this.sortOrder = 0,
  });

  final String id;
  final String key;
  final String title;
  final String description;
  final String status;
  final int sortOrder;
  final List<FieldReportSettingItem> items;

  factory FieldReportSettingGroup.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    final key = _text(json['key']);
    final title = _text(json['title'], fallback: 'Lựa chọn báo cáo');
    return FieldReportSettingGroup(
      id: id,
      key: key,
      title: title,
      description: _text(json['description']),
      status: _text(json['status'], fallback: 'active'),
      sortOrder: _integer(json['sortOrder'] ?? json['sort_order']),
      items: _objects(json['items'])
          .map(
            (item) => FieldReportSettingItem(
              id: _text(item['id']),
              key: _text(item['key'], fallback: _text(item['id'])),
              label: _text(item['label']),
              value: _text(
                item['value'],
                fallback: _text(item['label']),
              ),
              groupKey: key,
              groupTitle: title,
              category: _text(item['category']),
              brandName: _text(item['brandName']),
              productId: _text(item['productId'] ?? item['product_id']),
              status: _text(item['status'], fallback: 'active'),
              sortOrder: _integer(item['sortOrder'] ?? item['sort_order']),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
          .toList(growable: false),
    );
  }
}


class FieldReportTemplate {
  const FieldReportTemplate({
    required this.id,
    required this.title,
    this.reportType = 'general',
    this.content = '',
    this.priceSummary = '',
    this.competitorSummary = '',
    this.displaySummary = '',
    this.stockSummary = '',
    this.demandSummary = '',
    this.opportunitySummary = '',
    this.riskSummary = '',
    this.nextAction = '',
    this.note = '',
  });

  final String id;
  final String title;
  final String reportType;
  final String content;
  final String priceSummary;
  final String competitorSummary;
  final String displaySummary;
  final String stockSummary;
  final String demandSummary;
  final String opportunitySummary;
  final String riskSummary;
  final String nextAction;
  final String note;

  factory FieldReportTemplate.fromJson(Map<String, dynamic> json) {
    return FieldReportTemplate(
      id: _text(json['id']),
      title: _text(json['title'], fallback: 'Mẫu báo cáo'),
      reportType: _text(json['reportType'] ?? json['report_type'], fallback: 'general'),
      content: _text(json['content']),
      priceSummary: _text(json['priceSummary'] ?? json['price_summary']),
      competitorSummary: _text(json['competitorSummary'] ?? json['competitor_summary']),
      displaySummary: _text(json['displaySummary'] ?? json['display_summary']),
      stockSummary: _text(json['stockSummary'] ?? json['stock_summary']),
      demandSummary: _text(json['demandSummary'] ?? json['demand_summary']),
      opportunitySummary: _text(json['opportunitySummary'] ?? json['opportunity_summary']),
      riskSummary: _text(json['riskSummary'] ?? json['risk_summary']),
      nextAction: _text(json['nextAction'] ?? json['next_action']),
      note: _text(json['note']),
    );
  }
}

class FieldTestProduct {
  const FieldTestProduct({
    required this.id,
    required this.productName,
  });

  final String id;
  final String productName;

  factory FieldTestProduct.fromJson(Map<String, dynamic> json) {
    return FieldTestProduct(
      id: _text(json['id']),
      productName: _text(json['productName'] ?? json['product_name']),
    );
  }
}

class FieldTestFile {
  const FieldTestFile({
    required this.id,
    required this.title,
    required this.products,
    this.testDate = '',
  });

  final String id;
  final String title;
  final String testDate;
  final List<FieldTestProduct> products;

  factory FieldTestFile.fromJson(Map<String, dynamic> json) {
    return FieldTestFile(
      id: _text(json['id']),
      title: _text(json['title'], fallback: 'Phiếu thử sản phẩm'),
      testDate: _text(json['testDate'] ?? json['test_date']),
      products: _objects(json['products'])
          .map(FieldTestProduct.fromJson)
          .where((item) => item.id.isNotEmpty && item.productName.isNotEmpty)
          .toList(growable: false),
    );
  }
}

abstract interface class FieldActivityReferenceClient {
  Future<List<FieldReportTemplate>> loadReportTemplates();
  Future<List<FieldTestFile>> loadTestFiles();
}

abstract interface class FieldReportSettingsAdminClient {
  Future<List<FieldReportSettingGroup>> loadReportSettingGroups();

  Future<void> saveReportSettingGroup({
    String? groupId,
    required String title,
    required String description,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  });

  Future<void> saveReportSettingItem({
    String? itemId,
    required String groupId,
    required String label,
    required String value,
    required String category,
    required String brandName,
    required String productId,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  });
}

abstract interface class FieldActivityClient {
  Future<List<FieldReportSettingGroup>> loadReportSettings();

  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  });
}

class HttpFieldActivityClient
    implements
        FieldActivityClient,
        FieldActivityReferenceClient,
        FieldReportSettingsAdminClient {
  HttpFieldActivityClient({
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
      'mobile_activity_${DateTime.now().microsecondsSinceEpoch}';

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
  Future<List<FieldReportSettingGroup>> loadReportSettings() async {
    final data = await _request(
      'GET',
      '/api/mcp-report-settings',
      query: const {'groupType': 'market_report'},
    );
    return _objects(data['groups'])
        .map(FieldReportSettingGroup.fromJson)
        .where((group) => group.id.isNotEmpty && group.items.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<FieldReportTemplate>> loadReportTemplates() async {
    final data = await _request('GET', '/api/mcp-report-templates');
    return _objects(data['templates'])
        .map(FieldReportTemplate.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<FieldTestFile>> loadTestFiles() async {
    final data = await _request('GET', '/api/mcp-day/test-options');
    return _objects(data['files'])
        .map(FieldTestFile.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettingGroups() async {
    final data = await _request(
      'GET',
      '/api/mcp-report-settings',
      query: const {
        'groupType': 'market_report',
        'includeInactive': '1',
      },
    );
    return _objects(data['groups'])
        .map(FieldReportSettingGroup.fromJson)
        .where((group) => group.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveReportSettingGroup({
    String? groupId,
    required String title,
    required String description,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  }) async {
    final editing = (groupId ?? '').trim().isNotEmpty;
    await _request(
      editing ? 'PATCH' : 'POST',
      '/api/mcp-report-setting-groups',
      body: {
        if (editing) 'groupId': groupId!.trim(),
        'title': title.trim(),
        'description': description.trim(),
        'sortOrder': sortOrder,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> saveReportSettingItem({
    String? itemId,
    required String groupId,
    required String label,
    required String value,
    required String category,
    required String brandName,
    required String productId,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  }) async {
    final editing = (itemId ?? '').trim().isNotEmpty;
    await _request(
      editing ? 'PATCH' : 'POST',
      '/api/mcp-report-settings',
      body: {
        if (editing) 'itemId': itemId!.trim(),
        if (!editing) 'groupId': groupId.trim(),
        if (!editing || label.trim().isNotEmpty) 'label': label.trim(),
        if (!editing || value.trim().isNotEmpty) 'value': value.trim(),
        'category': category.trim(),
        'brandName': brandName.trim(),
        'productId': productId.trim(),
        'sortOrder': sortOrder,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
      },
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    final data = await _request(
      'POST',
      kind.path,
      body: payload,
      idempotencyKey: idempotencyKey,
    );
    final referenceId = switch (kind) {
      FieldActivityKind.report => _text(data['reportId']),
      FieldActivityKind.productTrial => _text(data['testId']),
      FieldActivityKind.followup => _text(data['followupId']),
    };
    if (referenceId.isEmpty) {
      throw const FieldActivityFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ thông tin vừa lưu.',
        retryable: true,
      );
    }
    return FieldActivityResult(
      referenceId: referenceId,
      data: data,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    http.Response response;
    try {
      final uri = _endpoint(path, query);
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
        'PATCH' =>
          await _client
              .patch(
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
      throw const FieldActivityFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Nội dung có thể lưu chờ gửi.',
        retryable: true,
      );
    } on http.ClientException {
      throw const FieldActivityFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng đang gián đoạn. Nội dung có thể lưu chờ gửi.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FieldActivityFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
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
      throw FieldActivityFailure(
        code: code,
        message: _activityErrorMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    final data = _object(payload['data']);
    if (data.isEmpty) {
      throw const FieldActivityFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
        retryable: true,
      );
    }
    return data;
  }
}

String _activityErrorMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code.toLowerCase()) {
    case 'session_customer_id_required':
    case 'session_customer_not_found':
    case 'session_not_found':
      return 'Điểm bán không còn thuộc phiên đi tuyến đang mở.';
    case 'test_results_required':
      return 'Cần nhập ít nhất một kết quả thử sản phẩm.';
    case 'product_name_required':
      return 'Cần chọn hoặc nhập sản phẩm được thử.';
    case 'test_file_not_found':
      return 'Phiếu thử sản phẩm không còn khả dụng. Cập nhật danh sách rồi chọn lại.';
    case 'test_product_not_found':
      return 'Sản phẩm trong phiếu thử không còn khả dụng. Cập nhật danh sách rồi chọn lại.';
    case 'title_required':
      return 'Cần nhập tên nhóm mẫu báo cáo.';
    case 'label_required':
      return 'Cần nhập tên lựa chọn báo cáo.';
    case 'group_id_required':
      return 'Cần chọn nhóm báo cáo.';
    case 'invalid_sort_order':
      return 'Thứ tự hiển thị chưa hợp lệ.';
    case 'report_setting_patch_required':
      return 'Chưa có thay đổi để lưu.';
    case 'invalid_test_status':
      return 'Kết quả thử sản phẩm chưa hợp lệ.';
    case 'report_content_required':
      return 'Cần nhập ít nhất một nội dung báo cáo.';
    case 'invalid_report_type':
      return 'Loại báo cáo chưa hợp lệ.';
    case 'followup_title_required':
      return 'Cần nhập nội dung công việc cần theo dõi.';
    case 'invalid_priority':
      return 'Mức ưu tiên chưa hợp lệ.';
    case 'idempotency_key_required':
    case 'invalid_idempotency_key':
      return 'Phiên gửi dữ liệu chưa hợp lệ. Vui lòng thử lại.';
  }
  if (statusCode == 401) return 'Phiên đăng nhập không còn hiệu lực.';
  if (statusCode == 403) {
    return serverMessage.isNotEmpty
        ? serverMessage
        : 'Tài khoản chưa được cấp quyền thực hiện thao tác này.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'Không lưu được dữ liệu. Vui lòng thử lại.';
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

int _integer(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse((value ?? '').toString()) ?? fallback;
}
