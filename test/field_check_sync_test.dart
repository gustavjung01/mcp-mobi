import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/field_check_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';

class MemoryMutationQueueStore implements MutationQueueStore {
  final Map<String, QueuedMutation> items = {};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = items.values.toList(growable: false);
    if (operations == null || operations.isEmpty) return values;
    return values
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    items.remove(idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    items[mutation.idempotencyKey] = mutation;
  }
}

class RetryHistoryClient implements FieldHistoryClient {
  bool offline = true;
  final keys = <String>[];

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {
    keys.add(idempotencyKey);
    expect(resultId, 'result-1');
    expect(productName, 'Trà đào');
    expect(status, 'opportunity');
    if (offline) {
      throw const FieldHistoryFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng tạm thời gián đoạn.',
        retryable: true,
      );
    }
  }

  @override
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async => const [];

  @override
  Future<List<FieldTaskItem>> loadTasks() async => const [];

  @override
  Future<List<OutletHistoryItem>> loadOutletHistory(String routeCustomerId) async =>
      const [];

  @override
  Future<List<SessionReportSummary>> loadSessionReports() async => const [];

  @override
  Future<SessionReportDetail> loadSessionReportDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  }) async => const [];
}

void main() {
  test('field-check retry survives restart and reuses the exact key', () async {
    final queue = MemoryMutationQueueStore();
    final client = RetryHistoryClient();
    final submit = FieldCheckSubmissionService(
      client: client,
      queue: queue,
    );

    final result = await submit.update(
      resultId: 'result-1',
      productName: 'Trà đào',
      status: 'opportunity',
      note: 'Khách quan tâm',
    );

    expect(result, FieldCheckSubmitStatus.queued);
    expect(client.keys, hasLength(1));
    final key = client.keys.single;
    expect(CanonicalIdempotencyKey.isValid(key), isTrue);

    final repeated = await submit.update(
      resultId: 'result-1',
      productName: 'Trà đào',
      status: 'opportunity',
      note: 'Khách quan tâm',
    );
    expect(repeated, FieldCheckSubmitStatus.queued);
    expect(client.keys, [key, key]);
    expect(
      await queue.load(operations: const {'field-check.result.update'}),
      hasLength(1),
    );

    client.offline = false;
    final replay = await FieldCheckSyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(replay.sent, 1);
    expect(replay.remaining, 0);
    expect(client.keys, [key, key, key]);
  });
}
