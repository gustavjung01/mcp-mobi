import '../data/field_history_client.dart';
import '../idempotency/canonical_idempotency.dart';
import 'mutation_queue.dart';

enum FieldCheckSubmitStatus {
  completed,
  queued,
}

class FieldCheckSubmissionService {
  const FieldCheckSubmissionService({
    required this.client,
    required this.queue,
  });

  final FieldHistoryClient client;
  final MutationQueueStore queue;

  Future<FieldCheckSubmitStatus> update({
    required String resultId,
    required String productName,
    required String status,
    String note = '',
  }) async {
    final normalizedResultId = resultId.trim();
    final normalizedProductName = productName.trim();
    final normalizedStatus = status.trim();
    final normalizedNote = note.trim();
    final existing = await _findOutstanding(
      resultId: normalizedResultId,
      productName: normalizedProductName,
      status: normalizedStatus,
      note: normalizedNote,
    );
    final mutation = existing ??
        QueuedMutation(
          idempotencyKey:
              CanonicalIdempotencyKey.create('field-check.result.update'),
          operation: 'field-check.result.update',
          entityType: 'field_check',
          entityLabel: normalizedProductName.isEmpty
              ? 'Kết quả thử sản phẩm'
              : normalizedProductName,
          payload: {
            'resultId': normalizedResultId,
            'productName': normalizedProductName,
            'status': normalizedStatus,
            'note': normalizedNote,
          },
          createdAt: DateTime.now().toUtc(),
        );

    if (existing == null) {
      try {
        await queue.save(mutation);
      } catch (_) {
        throw const FieldHistoryFailure(
          code: 'LOCAL_QUEUE_UNAVAILABLE',
          message: 'Không lưu được kết quả trên thiết bị. Vui lòng thử lại.',
        );
      }
    }

    try {
      await client.updateFieldCheck(
        resultId: normalizedResultId,
        productName: normalizedProductName,
        status: normalizedStatus,
        note: normalizedNote,
        idempotencyKey: mutation.idempotencyKey,
      );
      try {
        await queue.save(mutation.acknowledged(resultId));
      } catch (_) {
        // Máy chủ đã nhận thao tác; gửi lại cùng mã vẫn an toàn.
      }
      return FieldCheckSubmitStatus.completed;
    } on FieldHistoryFailure catch (failure) {
      if (!failure.retryable) {
        try {
          await queue.remove(mutation.idempotencyKey);
        } catch (_) {
          // Không thay đổi quyết định từ chối của máy chủ.
        }
        rethrow;
      }
      try {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: true,
          ),
        );
      } catch (_) {
        throw const FieldHistoryFailure(
          code: 'LOCAL_QUEUE_UNAVAILABLE',
          message: 'Chưa lưu được kết quả chờ gửi. Vui lòng thử lại.',
        );
      }
      return FieldCheckSubmitStatus.queued;
    }
  }
  Future<QueuedMutation?> _findOutstanding({
    required String resultId,
    required String productName,
    required String status,
    required String note,
  }) async {
    try {
      final rows = await queue.load(
        operations: const {'field-check.result.update'},
      );
      for (final row in rows) {
        if (!row.isOutstanding) continue;
        final payload = row.payload;
        if ((payload['resultId'] ?? '').toString().trim() == resultId &&
            (payload['productName'] ?? '').toString().trim() == productName &&
            (payload['status'] ?? '').toString().trim() == status &&
            (payload['note'] ?? '').toString().trim() == note) {
          return row;
        }
      }
      return null;
    } catch (_) {
      throw const FieldHistoryFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không đọc được kết quả chờ gửi trên thiết bị.',
      );
    }
  }
}

class FieldCheckSyncResult {
  const FieldCheckSyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class FieldCheckSyncService {
  const FieldCheckSyncService({
    required this.client,
    required this.queue,
  });

  final FieldHistoryClient client;
  final MutationQueueStore queue;

  static const operation = 'field-check.result.update';

  Future<FieldCheckSyncResult> syncPending({String? idempotencyKey}) async {
    final rows = await queue.load(operations: const {operation});
    var sent = 0;
    var failed = 0;

    for (final mutation in rows) {
      if (!mutation.isOutstanding) continue;
      if (idempotencyKey != null &&
          mutation.idempotencyKey != idempotencyKey) {
        continue;
      }
      if (idempotencyKey == null &&
          mutation.state == MutationQueueState.failed &&
          !mutation.retryable) {
        continue;
      }
      final payload = mutation.payload;
      try {
        final resultId = _required(payload['resultId']);
        await client.updateFieldCheck(
          resultId: resultId,
          productName: _required(payload['productName']),
          status: _required(payload['status']),
          note: (payload['note'] ?? '').toString().trim(),
          idempotencyKey: mutation.idempotencyKey,
        );
        await queue.save(mutation.acknowledged(resultId));
        sent += 1;
      } on FieldHistoryFailure catch (failure) {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: failure.retryable,
          ),
        );
        failed += 1;
      }
    }

    final remaining = (await queue.load(operations: const {operation}))
        .where((item) => item.isOutstanding)
        .length;
    return FieldCheckSyncResult(
      sent: sent,
      failed: failed,
      remaining: remaining,
    );
  }

  String _required(Object? value) {
    final normalized = (value ?? '').toString().trim();
    if (normalized.isEmpty) {
      throw const FieldHistoryFailure(
        code: 'LOCAL_QUEUE_INVALID',
        message: 'Kết quả chờ gửi chưa đủ thông tin.',
      );
    }
    return normalized;
  }
}
