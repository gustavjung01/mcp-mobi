import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/field_activity_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';

class MemoryMutationQueueStore implements MutationQueueStore {
  final rows = <String, QueuedMutation>{};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = rows.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    rows.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    rows[mutation.idempotencyKey] = mutation;
  }
}

class RetryActivityClient implements FieldActivityClient {
  final keys = <String>[];
  bool fail = true;

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettings() async => const [];

  @override
  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (fail) {
      throw const FieldActivityFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Kết nối tạm thời gián đoạn.',
        retryable: true,
      );
    }
    return const FieldActivityResult(
      referenceId: 'report-1',
      data: {'reportId': 'report-1'},
    );
  }
}

void main() {
  test('retryable submission keeps the same canonical key', () async {
    final queue = MemoryMutationQueueStore();
    final client = RetryActivityClient();
    final service = FieldActivitySubmissionService(
      client: client,
      queue: queue,
    );
    final key = CanonicalIdempotencyKey.create(
      FieldActivityKind.report.operation,
      uuid: '123e4567-e89b-42d3-a456-426614174000',
    );
    final payload = <String, Object?>{
      'sessionCustomerId': 'session-customer-1',
      'reportType': 'market_report',
      'fields': const {'demandSummary': 'Có nhu cầu'},
    };

    final submitted = await service.submit(
      kind: FieldActivityKind.report,
      idempotencyKey: key,
      entityLabel: 'Cửa hàng Minh Phát',
      payload: payload,
    );

    expect(submitted.status, FieldActivitySubmitStatus.queued);
    expect(queue.rows[key]!.state, MutationQueueState.failed);
    expect(client.keys, [key]);

    client.fail = false;
    final synced = await FieldActivitySyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(synced.sent, 1);
    expect(client.keys, [key, key]);
    expect(queue.rows[key]!.state, MutationQueueState.acknowledged);
    expect(queue.rows[key]!.serverReference, 'report-1');
  });

  test('blocked queued mutation waits for an explicit retry', () async {
    final queue = MemoryMutationQueueStore();
    final client = RetryActivityClient()..fail = false;
    final key = CanonicalIdempotencyKey.create(
      FieldActivityKind.followup.operation,
      uuid: '223e4567-e89b-42d3-a456-426614174000',
    );
    await queue.save(
      QueuedMutation(
        idempotencyKey: key,
        operation: FieldActivityKind.followup.operation,
        entityType: FieldActivityKind.followup.entityType,
        entityLabel: 'Cửa hàng Minh Phát',
        payload: const {
          'sessionCustomerId': 'session-customer-1',
          'title': 'Gọi lại',
        },
        createdAt: DateTime.utc(2026, 9, 28, 4),
        state: MutationQueueState.failed,
        retryable: false,
        lastErrorCode: 'invalid_priority',
        lastErrorMessage: 'Mức ưu tiên chưa hợp lệ.',
      ),
    );

    final service = FieldActivitySyncService(
      client: client,
      queue: queue,
    );
    final automatic = await service.syncPending();
    expect(automatic.sent, 0);
    expect(client.keys, isEmpty);

    final manual = await service.syncPending(idempotencyKey: key);
    expect(manual.sent, 1);
    expect(client.keys, [key]);
  });
}