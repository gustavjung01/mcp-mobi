import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/location/field_location.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/route_mutation_sync.dart';

const _line = FieldDayLine(
  id: 'line-1',
  sessionCustomerId: 'session-customer-1',
  routeCustomerId: 'route-customer-1',
  sortOrder: 1,
  accountName: 'Cửa hàng Minh Phát',
  area: 'Quận 1',
  source: 'planned',
  status: 'pending',
  note: '',
  hasOrder: false,
  hasTest: false,
  hasReport: false,
  followupCount: 0,
  checkedIn: false,
);

class MemoryMutationQueueStore implements MutationQueueStore {
  final Map<String, QueuedMutation> items = {};

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    final values = items.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

class FakeFieldActionClient implements FieldActionClient {
  bool offline = true;
  final Map<String, List<String>> keys = {
    'session-customer.checkin.set': <String>[],
    'session-customer.status.update': <String>[],
    'session-customer.add': <String>[],
  };

  Future<void> _record(String operation, String key) async {
    keys[operation]!.add(key);
    if (offline) {
      throw const FieldDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng tạm thời gián đoạn.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> openRouteSession({
    required String routeId,
    required DateTime date,
    required String owner,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> finishRouteSession({
    required String sessionId,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> setSessionCustomerCheckIn({
    required String sessionCustomerId,
    required bool checkedIn,
    double? latitude,
    double? longitude,
    double? accuracy,
    required String idempotencyKey,
  }) async {
    expect(sessionCustomerId, 'session-customer-1');
    if (checkedIn) {
      expect(latitude, 10.75);
      expect(longitude, 106.67);
      expect(accuracy, 8);
    }
    await _record('session-customer.checkin.set', idempotencyKey);
  }

  @override
  Future<void> setSessionCustomerStatus({
    required String sessionCustomerId,
    required String visitStatus,
    String? statusReason,
    String? note,
    required String idempotencyKey,
  }) async {
    expect(sessionCustomerId, 'session-customer-1');
    expect(visitStatus, 'skipped');
    expect(statusReason, 'no_demand');
    await _record('session-customer.status.update', idempotencyKey);
  }

  @override
  Future<FieldAddedCustomer> addSessionCustomer({
    required String sessionId,
    required String customerName,
    required String phone,
    required String area,
    required String address,
    required String note,
    double? latitude,
    double? longitude,
    double? accuracy,
    required String idempotencyKey,
  }) async {
    expect(sessionId, 'session-1');
    expect(customerName, 'Cửa hàng Mới');
    await _record('session-customer.add', idempotencyKey);
    return const FieldAddedCustomer(
      routeCustomerId: 'route-customer-new',
      sessionCustomerId: 'session-customer-new',
    );
  }
}

void main() {
  test(
    'route mutations survive restart and replay the same canonical keys',
    () async {
      final queue = MemoryMutationQueueStore();
      final client = FakeFieldActionClient();
      final service = RouteMutationSubmissionService(
        client: client,
        queue: queue,
      );

      final checkin = await service.setCheckIn(
        line: _line,
        checkedIn: true,
        location: const FieldLocation(
          latitude: 10.75,
          longitude: 106.67,
          accuracy: 8,
        ),
      );
      final skipped = await service.skip(
        line: _line,
        reason: 'no_demand',
        note: 'Gọi lại tuần sau',
      );
      final addKey = CanonicalIdempotencyKey.create(
        'session-customer.add',
        uuid: '123e4567-e89b-42d3-a456-426614174000',
      );
      final added = await service.addCustomer(
        sessionId: 'session-1',
        customerName: 'Cửa hàng Mới',
        phone: '0909555666',
        area: 'Quận 1',
        address: '12 Nguyễn Trãi',
        note: 'Khách phát sinh',
        location: const FieldLocation(
          latitude: 10.76,
          longitude: 106.68,
          accuracy: 9,
        ),
        idempotencyKey: addKey,
      );

      expect(checkin.status, RouteMutationSubmitStatus.queued);
      expect(skipped.status, RouteMutationSubmitStatus.queued);
      expect(added.status, RouteMutationSubmitStatus.queued);

      final queued = await queue.load(
        operations: RouteMutationSyncService.operations,
      );
      expect(queued, hasLength(3));
      for (final mutation in queued) {
        expect(
          CanonicalIdempotencyKey.isValid(mutation.idempotencyKey),
          isTrue,
        );
        expect(mutation.state, MutationQueueState.failed);
        expect(mutation.retryable, isTrue);
      }

      final originalKeys = {
        for (final mutation in queued)
          mutation.operation: mutation.idempotencyKey,
      };

      // Mô phỏng mở lại ứng dụng: service mới, cùng kho queue bền vững.
      client.offline = false;
      final result = await RouteMutationSyncService(
        client: client,
        queue: queue,
      ).syncPending();

      expect(result.sent, 3);
      expect(result.failed, 0);
      expect(result.remaining, 0);

      for (final entry in originalKeys.entries) {
        final seen = client.keys[entry.key]!;
        expect(seen, hasLength(2));
        expect(seen[0], entry.value);
        expect(seen[1], entry.value);
      }
    },
  );
}
