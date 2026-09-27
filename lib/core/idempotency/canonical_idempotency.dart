import 'package:uuid/uuid.dart';

abstract final class CanonicalIdempotencyKey {
  static const maxLength = 128;
  static final _keyPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String normalizeOperation(String value) {
    final maxOperationLength = maxLength - 36 - 1;
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');

    if (normalized.length > maxOperationLength) {
      normalized = normalized.substring(0, maxOperationLength);
    }
    normalized = normalized.replaceAll(RegExp(r'[._-]+$'), '');
    if (normalized.isEmpty) {
      throw ArgumentError('idempotency_operation_required');
    }
    return normalized;
  }

  static String create(String operation, {String? uuid}) {
    final generatedUuid = (uuid ?? const Uuid().v4()).toLowerCase();
    if (!_uuidPattern.hasMatch(generatedUuid)) {
      throw ArgumentError('idempotency_uuid_invalid');
    }
    final key = '${normalizeOperation(operation)}-$generatedUuid';
    if (!_keyPattern.hasMatch(key)) {
      throw StateError('idempotency_key_generation_failed');
    }
    return key;
  }

  static bool isValid(String value) => _keyPattern.hasMatch(value.trim());
}
