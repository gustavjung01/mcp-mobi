import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class FieldHistoryFailure implements Exception {
  const FieldHistoryFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class FieldSessionHistoryItem {
  const FieldSessionHistoryItem({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.status,
    required this.salesOwner,
    this.sessionDate,
    this.note,
    this.planned = 0,
    this.visited = 0,
    this.orders = 0,
    this.tests = 0,
    this.reports = 0,
    this.followups = 0,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String status;
  final String salesOwner;
  final String? sessionDate;
  final String? note;
  final int planned;
  final int visited;
  final int orders;
  final int tests;
  final int reports;
  final int followups;

  factory FieldSessionHistoryItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> aggregate = const {},
  }) {
    return FieldSessionHistoryItem(
      id: _text(json['id']),
      routeId: _text(json['route_id']),
      routeName: _text(json['route_name'], fallback: 'Tuyến làm việc'),
      status: normalizeSessionStatus(json['status']),
      salesOwner: _text(json['sales'], fallback: 'Chưa phân công'),
      sessionDate: _nullableText(json['session_date']),
      note: _nullableText(json['note']),
      planned: _integer(aggregate['planned'] ?? json['planned_customers']),
      visited: _integer(aggregate['visited'] ?? json['visited_customers']),
      orders: _integer(aggregate['orders'] ?? json['order_count']),
      tests: _integer(aggregate['tests'] ?? json['test_count']),
      reports: _integer(aggregate['reports'] ?? json['report_count']),
      followups: _integer(aggregate['followups'] ?? json['followup_count']),
    );
  }
}

class FieldTaskItem {
  const FieldTaskItem({
    required this.id,
    required this.title,
    required this.customerName,
    required this.routeName,
    required this.status,
    required this.priority,
    required this.owner,
    required this.followupType,
    this.sessionId,
    this.sessionDate,
    this.dueDate,
    this.note,
  });

  final String id;
  final String title;
  final String customerName;
  final String routeName;
  final String status;
  final String priority;
  final String owner;
  final String followupType;
  final String? sessionId;
  final String? sessionDate;
  final String? dueDate;
  final String? note;

  factory FieldTaskItem.fromJson(Map<String, dynamic> json) {
    return FieldTaskItem(
      id: _text(json['id']),
      title: _text(json['title'], fallback: 'Công việc theo dõi'),
      customerName: _text(json['customer_name'], fallback: 'Điểm bán'),
      routeName: _text(json['route_name'], fallback: 'Chưa xác định tuyến'),
      status: normalizeTaskStatus(json['status']),
      priority: normalizeTaskPriority(json['priority']),
      owner: _text(json['owner'], fallback: 'Chưa phân công'),
      followupType: _text(json['followup_type'], fallback: 'general'),
      sessionId: _nullableText(json['session_id']),
      sessionDate: _nullableText(json['session_date']),
      dueDate: _nullableText(json['due_date']),
      note: _nullableText(json['note']),
    );
  }

  bool isOverdue(DateTime now) {
    if (status == 'done') return false;
    final due = DateTime.tryParse((dueDate ?? '').trim());
    if (due == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(today);
  }

  bool isDueToday(DateTime now) {
    final due = DateTime.tryParse((dueDate ?? '').trim());
    if (due == null) return false;
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }
}

class FieldCheckItem {
  const FieldCheckItem({
    required this.id,
    required this.accountName,
    required this.productName,
    required this.status,
    this.date,
    this.routeName,
    this.note,
  });

  final String id;
  final String accountName;
  final String productName;
  final String status;
  final String? date;
  final String? routeName;
  final String? note;

  factory FieldCheckItem.fromJson(Map<String, dynamic> json) {
    return FieldCheckItem(
      id: _text(json['id']),
      accountName: _text(json['accountName'], fallback: 'Điểm bán'),
      productName: _text(json['productName'], fallback: 'Sản phẩm thử'),
      status: normalizeFieldCheckStatus(json['status']),
      date: _nullableText(json['date']),
      routeName: _nullableText(json['routeName']),
      note: _nullableText(json['note']),
    );
  }
}

class SessionReportSummary {
  const SessionReportSummary({
    required this.id,
    required this.sessionId,
    required this.routeName,
    required this.status,
    this.sessionDate,
    this.sales,
    this.planned = 0,
    this.visited = 0,
    this.orders = 0,
    this.tests = 0,
    this.reports = 0,
    this.followups = 0,
  });

  final String id;
  final String sessionId;
  final String routeName;
  final String status;
  final String? sessionDate;
  final String? sales;
  final int planned;
  final int visited;
  final int orders;
  final int tests;
  final int reports;
  final int followups;

  factory SessionReportSummary.fromJson(Map<String, dynamic> json) {
    final overview = _object(json['overview']);
    return SessionReportSummary(
      id: _text(json['id'], fallback: _text(json['session_id'])),
      sessionId: _text(json['session_id'], fallback: _text(json['id'])),
      routeName: _text(json['route_name'], fallback: 'Tuyến làm việc'),
      status: _text(
        json['session_status'],
        fallback: _text(json['status'], fallback: 'done'),
      ),
      sessionDate: _nullableText(json['session_date']),
      sales: _nullableText(json['sales']),
      planned: _integer(json['planned_customers'] ?? overview['planned']),
      visited: _integer(json['visited_customers'] ?? overview['visited']),
      orders: _integer(json['order_count'] ?? overview['orders']),
      tests: _integer(json['test_count'] ?? overview['tests']),
      reports: _integer(json['report_count'] ?? overview['reports']),
      followups: _integer(json['followup_count'] ?? overview['followups']),
    );
  }
}

class SessionCustomerFact {
  const SessionCustomerFact({
    required this.id,
    required this.customerName,
    required this.visitStatus,
    this.statusReason,
    this.orderId,
    this.testId,
    this.reportId,
    this.followupCount = 0,
    this.area,
    this.note,
  });

  final String id;
  final String customerName;
  final String visitStatus;
  final String? statusReason;
  final String? orderId;
  final String? testId;
  final String? reportId;
  final int followupCount;
  final String? area;
  final String? note;

  factory SessionCustomerFact.fromJson(Map<String, dynamic> json) {
    return SessionCustomerFact(
      id: _text(json['id']),
      customerName: _text(
        json['customer_name'] ?? json['account_name'],
        fallback: 'Điểm bán',
      ),
      visitStatus: _text(
        json['visit_status'],
        fallback: _text(json['status'], fallback: 'pending'),
      ),
      statusReason: _nullableText(json['status_reason']),
      orderId: _nullableText(json['order_id']),
      testId: _nullableText(json['test_id']),
      reportId: _nullableText(json['report_id']),
      followupCount: _integer(json['followup_count']),
      area: _nullableText(json['area']),
      note: _nullableText(json['note']),
    );
  }
}

class SessionMarketReportFact {
  const SessionMarketReportFact({
    required this.id,
    required this.customerName,
    this.content,
    this.competitorSummary,
    this.opportunitySummary,
    this.riskSummary,
    this.nextAction,
    this.note,
    this.selectedCompetitorIds = const [],
    this.selectedUsedProductIds = const [],
  });

  final String id;
  final String customerName;
  final String? content;
  final String? competitorSummary;
  final String? opportunitySummary;
  final String? riskSummary;
  final String? nextAction;
  final String? note;
  final List<String> selectedCompetitorIds;
  final List<String> selectedUsedProductIds;

  factory SessionMarketReportFact.fromJson(Map<String, dynamic> json) {
    return SessionMarketReportFact(
      id: _text(json['id']),
      customerName: _text(json['customer_name'], fallback: 'Điểm bán'),
      content: _nullableText(json['content']),
      competitorSummary: _nullableText(json['competitor_summary']),
      opportunitySummary: _nullableText(json['opportunity_summary']),
      riskSummary: _nullableText(json['risk_summary']),
      nextAction: _nullableText(json['next_action']),
      note: _nullableText(json['note']),
      selectedCompetitorIds: _strings(json['selected_competitor_ids']),
      selectedUsedProductIds: _strings(json['selected_used_product_ids']),
    );
  }
}

class SessionTestFact {
  const SessionTestFact({
    required this.id,
    required this.customerName,
    required this.productName,
    required this.status,
    this.note,
  });

  final String id;
  final String customerName;
  final String productName;
  final String status;
  final String? note;

  factory SessionTestFact.fromJson(Map<String, dynamic> json) {
    return SessionTestFact(
      id: _text(json['id']),
      customerName: _text(json['customer_name'], fallback: 'Điểm bán'),
      productName: _text(json['product_name'], fallback: 'Sản phẩm thử'),
      status: normalizeFieldCheckStatus(json['status']),
      note: _nullableText(json['note']),
    );
  }
}

class SessionFollowupFact {
  const SessionFollowupFact({
    required this.id,
    required this.customerName,
    required this.status,
    this.title,
    this.dueDate,
    this.priority,
    this.owner,
    this.note,
  });

  final String id;
  final String customerName;
  final String status;
  final String? title;
  final String? dueDate;
  final String? priority;
  final String? owner;
  final String? note;

  factory SessionFollowupFact.fromJson(Map<String, dynamic> json) {
    return SessionFollowupFact(
      id: _text(json['id']),
      customerName: _text(json['customer_name'], fallback: 'Điểm bán'),
      status: _text(json['status'], fallback: 'pending'),
      title: _nullableText(json['title']),
      dueDate: _nullableText(json['due_date']),
      priority: _nullableText(json['priority']),
      owner: _nullableText(json['owner']),
      note: _nullableText(json['note']),
    );
  }
}

class SessionReportDetail {
  const SessionReportDetail({
    required this.session,
    required this.customers,
    required this.marketReports,
    required this.tests,
    required this.followups,
  });

  final SessionReportSummary session;
  final List<SessionCustomerFact> customers;
  final List<SessionMarketReportFact> marketReports;
  final List<SessionTestFact> tests;
  final List<SessionFollowupFact> followups;

  factory SessionReportDetail.fromJson(Map<String, dynamic> json) {
    final sessionJson = _object(json['session']);
    final snapshot = _object(json['snapshot']);
    final mergedSession = <String, dynamic>{
      ...sessionJson,
      if (snapshot.isNotEmpty) 'id': snapshot['id'],
      'session_id': sessionJson['id'],
      if (snapshot['overview'] != null) 'overview': snapshot['overview'],
    };
    return SessionReportDetail(
      session: SessionReportSummary.fromJson(mergedSession),
      customers: _objects(json['customers'])
          .map(SessionCustomerFact.fromJson)
          .toList(growable: false),
      marketReports: _objects(json['marketReports'])
          .map(SessionMarketReportFact.fromJson)
          .toList(growable: false),
      tests: _objects(json['tests'])
          .map(SessionTestFact.fromJson)
          .toList(growable: false),
      followups: _objects(json['followups'])
          .map(SessionFollowupFact.fromJson)
          .toList(growable: false),
    );
  }
}

abstract interface class FieldHistoryClient {
  Future<List<FieldSessionHistoryItem>> loadSessionHistory();

  Future<List<FieldTaskItem>> loadTasks();

  Future<List<SessionReportSummary>> loadSessionReports();

  Future<SessionReportDetail> loadSessionReportDetail(String sessionId);

  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  });

  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  });
}

class HttpFieldHistoryClient implements FieldHistoryClient {
  HttpFieldHistoryClient({
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
    return Uri.parse(base + path).replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  String _requestId() =>
      'mobile_history_${DateTime.now().microsecondsSinceEpoch}';

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
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async {
    final data = await _request('GET', '/api/local-read/mcp-shell');
    final snapshot = _object(data['snapshot']);
    if (snapshot.isEmpty) {
      throw const FieldHistoryFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả lịch sử phiên.',
        retryable: true,
      );
    }

    final aggregates = <String, Map<String, dynamic>>{};
    for (final row in _objects(snapshot['recentSessionAggregates'])) {
      final sessionId = _text(row['session_id']);
      if (sessionId.isNotEmpty) aggregates[sessionId] = row;
    }

    return _objects(snapshot['recentSessions'])
        .map(
          (row) => FieldSessionHistoryItem.fromJson(
            row,
            aggregate: aggregates[_text(row['id'])] ?? const {},
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<FieldTaskItem>> loadTasks() async {
    final data = await _request('GET', '/api/local-read/mcp-followups');
    return _objects(data['items'])
        .map(FieldTaskItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<SessionReportSummary>> loadSessionReports() async {
    final data = await _request(
      'GET',
      '/api/local-read/mcp-session-reports',
    );
    return _objects(data['reports'])
        .map(SessionReportSummary.fromJson)
        .where((item) => item.sessionId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<SessionReportDetail> loadSessionReportDetail(String sessionId) async {
    final data = await _request(
      'GET',
      '/api/local-read/mcp-session-report',
      query: {'sessionId': sessionId},
    );
    return SessionReportDetail.fromJson(data);
  }

  @override
  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  }) async {
    final query = <String, String>{
      if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
      if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
    };
    final data = await _request(
      'GET',
      '/api/market-checks/data',
      query: query,
    );
    return _objects(data['checks'])
        .map(FieldCheckItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {
    if (!const {'normal', 'opportunity', 'risk'}.contains(status)) {
      throw const FieldHistoryFailure(
        code: 'INVALID_FIELD_CHECK_STATUS',
        message: 'Trạng thái hậu kiểm không hợp lệ.',
      );
    }
    await _request(
      'POST',
      '/api/field-checks/result',
      body: {
        'resultId': resultId,
        'productName': productName,
        'status': status,
        'note': (note ?? '').trim(),
      },
      idempotencyKey: idempotencyKey,
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
        _ => await _client.get(uri, headers: _headers()).timeout(timeout),
      };
    } on TimeoutException {
      throw const FieldHistoryFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const FieldHistoryFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được dữ liệu. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FieldHistoryFailure(
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
      throw FieldHistoryFailure(
        code: code,
        message: _historyErrorMessage(
          code,
          serverMessage: serverMessage,
          statusCode: response.statusCode,
        ),
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    final data = _object(payload['data']);
    if (data.isEmpty) {
      throw const FieldHistoryFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ dữ liệu.',
        retryable: true,
      );
    }
    return data;
  }
}

String normalizeSessionStatus(Object? value) {
  final status = _text(value).toLowerCase();
  if (status == 'completed' || status == 'closed') return 'done';
  if (status == 'done' || status == 'cancelled') return status;
  return 'active';
}

String normalizeTaskStatus(Object? value) {
  final status = _text(value).toLowerCase();
  if (const {
    'doing',
    'in_progress',
    'in-progress',
    'progress',
  }.contains(status)) {
    return 'doing';
  }
  if (const {'done', 'completed', 'closed', 'cancelled'}.contains(status)) {
    return 'done';
  }
  if (const {'blocked', 'hold', 'on_hold', 'on-hold'}.contains(status)) {
    return 'blocked';
  }
  return 'todo';
}

String normalizeTaskPriority(Object? value) {
  final priority = _text(value).toLowerCase();
  if (priority == 'urgent') return 'urgent';
  if (priority == 'high') return 'high';
  if (priority == 'low') return 'low';
  return 'medium';
}

String normalizeFieldCheckStatus(Object? value) {
  final status = _text(value).toLowerCase();
  if (const {
    'opportunity',
    'ok',
    'interested',
    'sample',
    'good',
    'success',
    'passed',
    'positive',
  }.contains(status)) {
    return 'opportunity';
  }
  if (const {
    'risk',
    'bad',
    'retry',
    'follow',
    'fail',
    'failed',
    'issue',
    'problem',
  }.contains(status)) {
    return 'risk';
  }
  return 'normal';
}

String _historyErrorMessage(
  String code, {
  required String serverMessage,
  required int statusCode,
}) {
  switch (code.toLowerCase()) {
    case 'session_id_required':
      return 'Chưa xác định được phiên cần xem.';
    case 'mcp_session_not_found':
    case 'session_not_found':
      return 'Phiên làm việc không còn tồn tại.';
    case 'field_check_result_not_found':
      return 'Kết quả thử sản phẩm không còn tồn tại.';
    case 'field_check_result_id_required':
      return 'Chưa xác định được kết quả cần cập nhật.';
    case 'field_check_product_name_required':
      return 'Kết quả thử sản phẩm chưa có tên sản phẩm.';
    case 'field_check_status_invalid':
      return 'Trạng thái hậu kiểm không hợp lệ.';
    case 'idempotency_key_required':
    case 'idempotency_key_invalid':
      return 'Lần cập nhật chưa có mã gửi hợp lệ. Vui lòng thử lại.';
  }
  if (statusCode == 401) return 'Phiên đăng nhập không còn hiệu lực.';
  if (statusCode == 403) {
    return serverMessage.isNotEmpty
        ? serverMessage
        : 'Tài khoản chưa được cấp quyền xem hoặc cập nhật dữ liệu này.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'Không xử lý được dữ liệu. Vui lòng thử lại.';
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

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => _text(item))
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
