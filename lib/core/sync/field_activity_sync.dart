import '../data/field_activity_client.dart';
import 'mutation_queue.dart';

enum FieldActivitySubmitStatus {
  completed,
  queued,
}

class FieldActivitySubmitResult {
  const FieldActivitySubmitResult({
    required this.status,
    this.referenceId,
  });

  final FieldActivitySubmitStatus status;
  final String? referenceId;
}

class FieldActivitySubmissionService {
  const FieldActivitySubmissionService({
    required this.client,
    required this.queue,
  });

  final FieldActivityClient client;
  final MutationQueueStore queue;

  Future<FieldActivitySubmitResult> submit({
    required FieldActivityKind kind,
    required String idempotencyKey,
    required String entityLabel,
    required Map<String, Object?> payload,
  }) async {
    final mutation = QueuedMutation(
      idempotencyKey: idempotencyKey,
      operation: kind.operation,
      entityType: kind.entityType,
      entityLabel: entityLabel,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await queue.save(mutation);
    } catch (_) {
      throw const FieldActivityFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không lưu được lần gửi trên thiết bị. Vui lòng thử lại.',
      );
    }

    try {
      final result = await client.submit(
        kind: kind,
        payload: payload,
        idempotencyKey: idempotencyKey,
      );
      try {
        await queue.save(mutation.acknowledged(result.referenceId));
      } catch (_) {
        // Server already accepted this canonical intent. A replay remains safe
        // because the same idempotency key is retained locally.
      }
      return FieldActivitySubmitResult(
        status: FieldActivitySubmitStatus.completed,
        referenceId: result.referenceId,
      );
    } on FieldActivityFailure catch (failure) {
      if (failure.retryable) {
        try {
          await queue.save(
            mutation.failed(
              code: failure.code,
              message: failure.message,
              retryable: true,
            ),
          );
        } catch (_) {
          throw const FieldActivityFailure(
            code: 'LOCAL_QUEUE_UNAVAILABLE',
            message: 'Chưa lưu được nội dung chờ gửi. Vui lòng thử lại.',
          );
        }
        return const FieldActivitySubmitResult(
          status: FieldActivitySubmitStatus.queued,
        );
      }

      try {
        await queue.remove(idempotencyKey);
      } catch (_) {
        // Keep the form open. A stale local record cannot authorize a write.
      }
      rethrow;
    }
  }
}

class FieldActivitySyncResult {
  const FieldActivitySyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class FieldActivitySyncService {
  const FieldActivitySyncService({
    required this.client,
    required this.queue,
  });

  final FieldActivityClient client;
  final MutationQueueStore queue;

  static Set<String> get operations => FieldActivityKind.values
      .map((kind) => kind.operation)
      .toSet();

  Future<FieldActivitySyncResult> syncPending({
    String? idempotencyKey,
  }) async {
    final mutations = await queue.load(operations: operations);
    var sent = 0;
    var failed = 0;

    for (final mutation in mutations) {
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

      final kind = fieldActivityKindFromOperation(mutation.operation);
      if (kind == null) continue;

      try {
        final result = await client.submit(
          kind: kind,
          payload: mutation.payload,
          idempotencyKey: mutation.idempotencyKey,
        );
        await queue.save(mutation.acknowledged(result.referenceId));
        sent += 1;
      } on FieldActivityFailure catch (failure) {
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

    final remaining = (await queue.load(operations: operations))
        .where((item) => item.isOutstanding)
        .length;
    return FieldActivitySyncResult(
      sent: sent,
      failed: failed,
      remaining: remaining,
    );
  }
}
