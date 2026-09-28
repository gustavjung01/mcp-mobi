import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class ManagementProposalFailure implements Exception {
  const ManagementProposalFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class ManagementProposal {
  const ManagementProposal({
    required this.id,
    required this.title,
    required this.content,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.impact,
    required this.reason,
    required this.rule,
    required this.evidence,
    required this.priority,
    required this.status,
    required this.requesterName,
    required this.createdAt,
    required this.updatedAt,
    this.decisionNote,
  });

  final String id;
  final String title;
  final String content;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String impact;
  final String reason;
  final String rule;
  final List<String> evidence;
  final String priority;
  final String status;
  final String requesterName;
  final String? decisionNote;
  final String createdAt;
  final String updatedAt;

  factory ManagementProposal.fromJson(Map<String, dynamic> json) {
    return ManagementProposal(
      id: _text(json['id']),
      title: _text(json['title']),
      content: _text(json['content']),
      entityType: _text(json['entityType'], fallback: 'other'),
      entityId: _text(json['entityId']),
      entityLabel: _text(json['entityLabel']),
      impact: _text(json['impact']),
      reason: _text(json['reason']),
      rule: _text(json['rule']),
      evidence: _strings(json['evidence']),
      priority: _proposalPriority(json['priority']),
      status: _proposalStatus(json['status']),
      requesterName: _text(json['requesterName']),
      decisionNote: _nullableText(json['decisionNote']),
      createdAt: _text(json['createdAt']),
      updatedAt: _text(json['updatedAt']),
    );
  }
}

class ManagementProposalDraft {
  const ManagementProposalDraft({
    required this.title,
    required this.content,
    this.entityType = 'other',
    this.entityId = '',
    this.entityLabel = '',
    this.impact = '',
    this.reason = '',
    this.rule = '',
    this.evidence = const [],
    this.priority = 'normal',
  });

  final String title;
  final String content;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String impact;
  final String reason;
  final String rule;
  final List<String> evidence;
  final String priority;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'content': content.trim(),
    'entityType': entityType.trim().isEmpty ? 'other' : entityType.trim(),
    'entityId': entityId.trim(),
    'entityLabel': entityLabel.trim(),
    'impact': impact.trim(),
    'reason': reason.trim(),
    'rule': rule.trim(),
    'evidence': evidence.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false),
    'priority': _proposalPriority(priority),
  };
}

abstract interface class ManagementProposalClient {
  Future<List<ManagementProposal>> load();

  Future<ManagementProposal> create({
    required ManagementProposalDraft draft,
    required String idempotencyKey,
  });

  Future<ManagementProposal> resubmit({
    required String proposalId,
    required String content,
    required String reason,
    required List<String> evidence,
    required String idempotencyKey,
  });
}

class HttpManagementProposalClient implements ManagementProposalClient {
  HttpManagementProposalClient({
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
    final base = profile.fieldBaseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse(base + path).replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  String _requestId() =>
      'mobile_proposal_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _headers({
    bool hasBody = false,
    String? idempotencyKey,
  }) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'X-Request-Id': _requestId(),
    if (hasBody) 'Content-Type': 'application/json',
    if ((idempotencyKey ?? '').trim().isNotEmpty)
      'Idempotency-Key': idempotencyKey!.trim(),
  };

  @override
  Future<List<ManagementProposal>> load() async {
    final data = await _request(
      'GET',
      '/api/management-proposals',
      query: const {'source': 'mcp'},
    );
    return _objects(data['proposals'])
        .map(ManagementProposal.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<ManagementProposal> create({
    required ManagementProposalDraft draft,
    required String idempotencyKey,
  }) async {
    if (draft.title.trim().isEmpty || draft.content.trim().isEmpty) {
      throw const ManagementProposalFailure(
        code: 'PROPOSAL_REQUIRED',
        message: 'Cần nhập tiêu đề và nội dung đề xuất.',
      );
    }
    final data = await _request(
      'POST',
      '/api/management-proposals',
      body: draft.toJson(),
      idempotencyKey: idempotencyKey,
    );
    final proposal = ManagementProposal.fromJson(data);
    if (proposal.id.isEmpty) {
      throw const ManagementProposalFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ thông tin Đề xuất.',
        retryable: true,
      );
    }
    return proposal;
  }

  @override
  Future<ManagementProposal> resubmit({
    required String proposalId,
    required String content,
    required String reason,
    required List<String> evidence,
    required String idempotencyKey,
  }) async {
    final normalizedId = proposalId.trim();
    final normalizedContent = content.trim();
    if (normalizedId.isEmpty || normalizedContent.isEmpty) {
      throw const ManagementProposalFailure(
        code: 'PROPOSAL_REQUIRED',
        message: 'Cần nhập nội dung bổ sung trước khi gửi lại.',
      );
    }
    final data = await _request(
      'POST',
      '/api/management-proposals/${Uri.encodeComponent(normalizedId)}/resubmit',
      body: {
        'content': normalizedContent,
        'reason': reason.trim(),
        'evidence': evidence.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false),
      },
      idempotencyKey: idempotencyKey,
    );
    final proposal = ManagementProposal.fromJson(data);
    if (proposal.id.isEmpty) {
      throw const ManagementProposalFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ thông tin Đề xuất.',
        retryable: true,
      );
    }
    return proposal;
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
        'POST' => await _client
            .post(
              uri,
              headers: _headers(hasBody: true, idempotencyKey: idempotencyKey),
              body: jsonEncode(body ?? const <String, Object?>{}),
            )
            .timeout(timeout),
        _ => await _client.get(uri, headers: _headers()).timeout(timeout),
      };
    } on TimeoutException {
      throw const ManagementProposalFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ManagementProposalFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được Đề xuất. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ManagementProposalFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu Đề xuất không hợp lệ.',
        retryable: true,
      );
    }

    final payload = _object(decoded);
    if (response.statusCode >= 400) {
      final error = _object(payload['error']);
      final code = _text(error['code'], fallback: 'REQUEST_FAILED');
      final serverMessage = _text(error['message']);
      final message = response.statusCode == 403
          ? 'Tài khoản chưa được cấp quyền gửi Đề xuất.'
          : response.statusCode == 401
          ? 'Phiên đăng nhập không còn hiệu lực.'
          : serverMessage.isNotEmpty
          ? serverMessage
          : 'Không xử lý được Đề xuất. Vui lòng thử lại.';
      throw ManagementProposalFailure(
        code: code,
        message: message,
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    final data = _object(payload['data']);
    if (data.isEmpty) {
      throw const ManagementProposalFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống chưa trả đủ dữ liệu Đề xuất.',
        retryable: true,
      );
    }
    return data;
  }
}

String _proposalStatus(Object? value) {
  final status = _text(value).toLowerCase();
  return const {'pending', 'needs-info', 'approved', 'rejected'}.contains(status)
      ? status
      : 'pending';
}

String _proposalPriority(Object? value) {
  final priority = _text(value).toLowerCase();
  return const {'critical', 'high', 'normal'}.contains(priority)
      ? priority
      : 'normal';
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
