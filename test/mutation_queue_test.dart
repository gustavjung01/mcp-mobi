import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';

void main() {
  test('queued mutation JSON preserves canonical retry identity', () {
    final key = CanonicalIdempotencyKey.create(
      'session-customer.report.create',
      uuid: '123e4567-e89b-42d3-a456-426614174000',
    );
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: 'session-customer.report.create',
      entityType: 'report',
      entityLabel: 'Cửa hàng Minh Phát',
      payload: const {
        'sessionCustomerId': 'session-customer-1',
        'reportType': 'market_report',
        'fields': {'demandSummary': 'Cần thêm trà đào'},
      },
      createdAt: DateTime.utc(2026, 9, 28, 2),
    );

    final restored = QueuedMutation.fromJson(mutation.toJson());

    expect(restored, isNotNull);
    expect(restored!.idempotencyKey, key);
    expect(restored.operation, 'session-customer.report.create');
    expect(restored.entityLabel, 'Cửa hàng Minh Phát');
    expect(restored.payload['sessionCustomerId'], 'session-customer-1');
    expect(restored.state, MutationQueueState.waiting);
  });

  test('acknowledgement closes the same queued intent', () {
    final mutation = QueuedMutation(
      idempotencyKey: 'session-customer.followup.create-123e4567-e89b-42d3-a456-426614174000',
      operation: 'session-customer.followup.create',
      entityType: 'followup',
      entityLabel: 'Cửa hàng Minh Phát',
      payload: const {
        'sessionCustomerId': 'session-customer-1',
        'title': 'Gọi lại',
      },
      createdAt: DateTime.utc(2026, 9, 28, 3),
    );

    final acknowledged = mutation.acknowledged('followup-1');

    expect(acknowledged.idempotencyKey, mutation.idempotencyKey);
    expect(acknowledged.state, MutationQueueState.acknowledged);
    expect(acknowledged.serverReference, 'followup-1');
    expect(acknowledged.acknowledgedAt, isNotNull);
  });
}
