import '../data/customer_boundary_client.dart';
import '../idempotency/canonical_idempotency.dart';
import 'mutation_queue.dart';

enum CustomerBoundarySubmitStatus {
  completed,
  queued,
}

class CustomerBoundarySubmitResult {
  const CustomerBoundarySubmitResult({
    required this.status,
    this.item,
  });

  final CustomerBoundarySubmitStatus status;
  final CustomerVerificationItem? item;
}

class CustomerBoundarySubmissionService {
  const CustomerBoundarySubmissionService({
    required this.client,
    required this.queue,
  });

  final CustomerBoundaryClient client;
  final MutationQueueStore queue;

  Future<CustomerBoundarySubmitResult> submit({
    required String routeCustomerId,
  }) {
    return _send(
      routeCustomerId: routeCustomerId,
      operation: 'customer-verification.submit',
    );
  }

  Future<CustomerBoundarySubmitResult> sync({
    required String routeCustomerId,
  }) {
    return _send(
      routeCustomerId: routeCustomerId,
      operation: 'customer-verification.sync',
    );
  }

  Future<CustomerBoundarySubmitResult> _send({
    required String routeCustomerId,
    required String operation,
  }) async {
    final normalizedId = routeCustomerId.trim();
    if (normalizedId.isEmpty) {
      throw const CustomerBoundaryFailure(
        code: 'ROUTE_CUSTOMER_REQUIRED',
        message: 'Chưa xác định được điểm bán cần xử lý.',
      );
    }

    final existing = await _findOutstanding(
      operation: operation,
      routeCustomerId: normalizedId,
    );
    final mutation = existing ??
        QueuedMutation(
          idempotencyKey: CanonicalIdempotencyKey.create(operation),
          operation: operation,
          entityType: 'route_customer',
          entityLabel: normalizedId,
          payload: {'routeCustomerId': normalizedId},
          createdAt: DateTime.now().toUtc(),
        );
    if (existing == null) await _saveInitial(mutation);
    final key = mutation.idempotencyKey;

    try {
      final item = operation == 'customer-verification.submit'
          ? await client.submit(
              routeCustomerId: normalizedId,
              idempotencyKey: key,
            )
          : await client.sync(
              routeCustomerId: normalizedId,
              idempotencyKey: key,
            );
      await _acknowledgeBestEffort(mutation, item.routeCustomerId);
      return CustomerBoundarySubmitResult(
        status: CustomerBoundarySubmitStatus.completed,
        item: item,
      );
    } on CustomerBoundaryFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<QueuedMutation?> _findOutstanding({
    required String operation,
    required String routeCustomerId,
  }) async {
    try {
      final rows = await queue.load(operations: {operation});
      for (final row in rows) {
        if (!row.isOutstanding) continue;
        final queuedId = (row.payload['routeCustomerId'] ?? '')
            .toString()
            .trim();
        if (queuedId == routeCustomerId) return row;
      }
      return null;
    } catch (_) {
      throw const CustomerBoundaryFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không đọc được thao tác chờ gửi trên thiết bị.',
      );
    }
  }

  Future<void> _saveInitial(QueuedMutation mutation) async {
    try {
      await queue.save(mutation);
    } catch (_) {
      throw const CustomerBoundaryFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không lưu được thao tác trên thiết bị. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _acknowledgeBestEffort(
    QueuedMutation mutation,
    String reference,
  ) async {
    try {
      await queue.save(mutation.acknowledged(reference));
    } catch (_) {
      // Máy chủ đã nhận thao tác; gửi lại cùng mã vẫn an toàn.
    }
  }

  Future<CustomerBoundarySubmitResult> _handleFailure(
    QueuedMutation mutation,
    CustomerBoundaryFailure failure,
  ) async {
    if (!failure.retryable) {
      try {
        await queue.remove(mutation.idempotencyKey);
      } catch (_) {
        // Không thay đổi quyết định từ chối của máy chủ.
      }
      throw failure;
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
      throw const CustomerBoundaryFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Chưa lưu được thao tác chờ gửi. Vui lòng thử lại.',
      );
    }
    return const CustomerBoundarySubmitResult(
      status: CustomerBoundarySubmitStatus.queued,
    );
  }
}

class CustomerBoundarySyncResult {
  const CustomerBoundarySyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class CustomerBoundarySyncService {
  const CustomerBoundarySyncService({
    required this.client,
    required this.queue,
  });

  final CustomerBoundaryClient client;
  final MutationQueueStore queue;

  static const operations = <String>{
    'customer-verification.submit',
    'customer-verification.sync',
  };

  Future<CustomerBoundarySyncResult> syncPending() async {
    final rows = await queue.load(operations: operations);
    var sent = 0;
    var failed = 0;

    for (final mutation in rows) {
      if (!mutation.isOutstanding) continue;
      if (mutation.state == MutationQueueState.failed && !mutation.retryable) {
        continue;
      }

      try {
        final routeCustomerId = _requiredRouteCustomerId(mutation);
        if (mutation.operation == 'customer-verification.submit') {
          await client.submit(
            routeCustomerId: routeCustomerId,
            idempotencyKey: mutation.idempotencyKey,
          );
        } else if (mutation.operation == 'customer-verification.sync') {
          await client.sync(
            routeCustomerId: routeCustomerId,
            idempotencyKey: mutation.idempotencyKey,
          );
        } else {
          continue;
        }
        await queue.save(mutation.acknowledged(routeCustomerId));
        sent += 1;
      } on CustomerBoundaryFailure catch (failure) {
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
    return CustomerBoundarySyncResult(
      sent: sent,
      failed: failed,
      remaining: remaining,
    );
  }

  String _requiredRouteCustomerId(QueuedMutation mutation) {
    final value = (mutation.payload['routeCustomerId'] ?? '').toString().trim();
    if (value.isEmpty) {
      throw const CustomerBoundaryFailure(
        code: 'LOCAL_QUEUE_INVALID',
        message: 'Thao tác chờ gửi chưa đủ thông tin điểm bán.',
      );
    }
    return value;
  }
}
