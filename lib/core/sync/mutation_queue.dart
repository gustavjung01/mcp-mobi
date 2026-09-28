import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../idempotency/canonical_idempotency.dart';

enum MutationQueueState {
  waiting,
  failed,
  acknowledged,
}

class QueuedMutation {
  const QueuedMutation({
    required this.idempotencyKey,
    required this.operation,
    required this.entityType,
    required this.entityLabel,
    required this.payload,
    required this.createdAt,
    this.state = MutationQueueState.waiting,
    this.retryCount = 0,
    this.retryable = true,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.serverReference,
    this.acknowledgedAt,
  });

  final String idempotencyKey;
  final String operation;
  final String entityType;
  final String entityLabel;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final MutationQueueState state;
  final int retryCount;
  final bool retryable;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final String? serverReference;
  final DateTime? acknowledgedAt;

  bool get isOutstanding => state != MutationQueueState.acknowledged;

  QueuedMutation failed({
    required String code,
    required String message,
    required bool retryable,
  }) {
    return QueuedMutation(
      idempotencyKey: idempotencyKey,
      operation: operation,
      entityType: entityType,
      entityLabel: entityLabel,
      payload: payload,
      createdAt: createdAt,
      state: MutationQueueState.failed,
      retryCount: retryCount + 1,
      retryable: retryable,
      lastErrorCode: code,
      lastErrorMessage: message,
    );
  }

  QueuedMutation acknowledged(String? reference) {
    return QueuedMutation(
      idempotencyKey: idempotencyKey,
      operation: operation,
      entityType: entityType,
      entityLabel: entityLabel,
      payload: payload,
      createdAt: createdAt,
      state: MutationQueueState.acknowledged,
      retryCount: retryCount,
      retryable: false,
      serverReference: reference,
      acknowledgedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'idempotencyKey': idempotencyKey,
    'operation': operation,
    'entityType': entityType,
    'entityLabel': entityLabel,
    'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
    'retryCount': retryCount,
    'retryable': retryable,
    if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
    if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
    if (serverReference != null) 'serverReference': serverReference,
    if (acknowledgedAt != null)
      'acknowledgedAt': acknowledgedAt!.toUtc().toIso8601String(),
  };

  static QueuedMutation? fromJson(Object? value) {
    final json = _object(value);
    final key = _text(json['idempotencyKey']);
    final operation = _text(json['operation']);
    final entityType = _text(json['entityType']);
    final entityLabel = _text(json['entityLabel']);
    final createdAt = DateTime.tryParse(_text(json['createdAt']));
    final payload = _object(json['payload']);
    if (!CanonicalIdempotencyKey.isValid(key) ||
        operation.isEmpty ||
        entityType.isEmpty ||
        createdAt == null ||
        payload.isEmpty) {
      return null;
    }

    final stateName = _text(json['state']);
    final state = MutationQueueState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => MutationQueueState.waiting,
    );
    return QueuedMutation(
      idempotencyKey: key,
      operation: operation,
      entityType: entityType,
      entityLabel: entityLabel.isEmpty ? entityType : entityLabel,
      payload: Map<String, Object?>.from(payload),
      createdAt: createdAt,
      state: state,
      retryCount: _integer(json['retryCount']),
      retryable: json['retryable'] != false,
      lastErrorCode: _nullableText(json['lastErrorCode']),
      lastErrorMessage: _nullableText(json['lastErrorMessage']),
      serverReference: _nullableText(json['serverReference']),
      acknowledgedAt: DateTime.tryParse(_text(json['acknowledgedAt'])),
    );
  }
}

abstract interface class MutationQueueStore {
  Future<List<QueuedMutation>> load({Set<String>? operations});

  Future<void> save(QueuedMutation mutation);

  Future<void> remove(String idempotencyKey);
}

class SecureMutationQueueStore implements MutationQueueStore {
  SecureMutationQueueStore({
    required String installationKey,
    required String employeeId,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _scope = base64Url
           .encode(utf8.encode('$installationKey|$employeeId'))
           .replaceAll('=', '');

  final FlutterSecureStorage _storage;
  final String _scope;

  String get _key => 'mcp.mutation_queue.$_scope';

  Future<List<QueuedMutation>> _readAll() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {
      return const [];
    }
    if ((raw ?? '').isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw!);
      if (decoded is! List) return const [];
      final mutations = decoded
          .map(QueuedMutation.fromJson)
          .whereType<QueuedMutation>()
          .toList(growable: true);
      mutations.sort(
        (left, right) => left.createdAt.compareTo(right.createdAt),
      );
      return mutations;
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final mutations = await _readAll();
    if (operations == null || operations.isEmpty) return mutations;
    return mutations
        .where((mutation) => operations.contains(mutation.operation))
        .toList(growable: false);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    final mutations = await _readAll();
    final index = mutations.indexWhere(
      (item) => item.idempotencyKey == mutation.idempotencyKey,
    );
    if (index >= 0) {
      mutations[index] = mutation;
    } else {
      mutations.add(mutation);
    }

    final acknowledged =
        mutations
            .where((item) => item.state == MutationQueueState.acknowledged)
            .toList(growable: false)
          ..sort(
            (left, right) => right.createdAt.compareTo(left.createdAt),
          );
    final keepAcknowledgedKeys = acknowledged
        .take(30)
        .map((item) => item.idempotencyKey)
        .toSet();
    final compact = mutations
        .where(
          (item) =>
              item.isOutstanding ||
              keepAcknowledgedKeys.contains(item.idempotencyKey),
        )
        .map((item) => item.toJson())
        .toList(growable: false);

    await _storage.write(key: _key, value: jsonEncode(compact));
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    final mutations = await _readAll();
    final remaining = mutations
        .where((item) => item.idempotencyKey != idempotencyKey)
        .map((item) => item.toJson())
        .toList(growable: false);
    await _storage.write(key: _key, value: jsonEncode(remaining));
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

String _text(Object? value) => (value ?? '').toString().trim();

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}
