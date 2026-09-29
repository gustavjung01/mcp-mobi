import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/route_management_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/route_management_sync.dart';

class MemoryMutationQueueStore implements MutationQueueStore {
  final rows = <String, QueuedMutation>{};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = rows.values.where((item) {
      return operations == null || operations.contains(item.operation);
    }).toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return values;
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

class FakeRouteManagementClient implements RouteManagementClient {
  bool failNextCreate = false;
  final createKeys = <String>[];

  @override
  Future<void> createRoute({
    required String routeName,
    required String area,
    int? weekday,
    String note = '',
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    if (failNextCreate) {
      failNextCreate = false;
      throw const FieldDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mất kết nối.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerName,
    String phone = '',
    String area = '',
    String address = '',
    int? sortOrder,
    String note = '',
    bool includeActiveSession = false,
    String? activeSessionId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> archiveRoute({
    required String routeId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> archiveRouteCustomer({
    required String routeCustomerId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> deleteEmptySession({
    required String sessionId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> updateRoute({
    required String routeId,
    String? routeName,
    String? area,
    int? weekday,
    String? note,
    bool? active,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> updateRouteCustomer({
    required String routeCustomerId,
    String? customerName,
    String? phone,
    String? area,
    String? address,
    int? sortOrder,
    String? note,
    bool? active,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> updateSession({
    required String sessionId,
    String? status,
    String? note,
    DateTime? sessionDate,
    required String idempotencyKey,
  }) async {}
}

void main() {
  test('retryable route create survives and reuses exact canonical key', () async {
    final queue = MemoryMutationQueueStore();
    final client = FakeRouteManagementClient()..failNextCreate = true;
    final submission = RouteManagementSubmissionService(
      client: client,
      queue: queue,
    );

    final result = await submission.createRoute(
      routeName: 'Tuyến A',
      area: 'Quận 1',
      weekday: 1,
    );

    expect(result, RouteManagementSubmitStatus.queued);
    final queued = await queue.load(operations: const {'mcp.route.create'});
    expect(queued, hasLength(1));
    final key = queued.single.idempotencyKey;
    expect(CanonicalIdempotencyKey.isValid(key), isTrue);
    expect(client.createKeys, [key]);

    final sent = await RouteManagementSyncService(
      client: client,
      queue: queue,
    ).syncPending();

    expect(sent, 1);
    expect(client.createKeys, [key, key]);
    final after = await queue.load(operations: const {'mcp.route.create'});
    expect(after.single.state, MutationQueueState.acknowledged);
  });

  test('same outstanding route intent reuses key before background sync', () async {
    final queue = MemoryMutationQueueStore();
    final client = FakeRouteManagementClient()..failNextCreate = true;
    final service = RouteManagementSubmissionService(
      client: client,
      queue: queue,
    );

    await service.createRoute(
      routeName: 'Tuyến A',
      area: 'Quận 1',
    );
    final firstKey = client.createKeys.single;

    client.failNextCreate = true;
    await service.createRoute(
      routeName: 'Tuyến A',
      area: 'Quận 1',
    );

    expect(client.createKeys, [firstKey, firstKey]);
    expect(
      await queue.load(operations: const {'mcp.route.create'}),
      hasLength(1),
    );
  });
}
