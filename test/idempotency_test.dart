import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';

void main() {
  test('canonical idempotency key follows shared contract', () {
    final key = CanonicalIdempotencyKey.create(
      ' Session Customer CHECKIN set ',
      uuid: '123e4567-e89b-42d3-a456-426614174000',
    );

    expect(
      key,
      'session-customer-checkin-set-123e4567-e89b-42d3-a456-426614174000',
    );
    expect(CanonicalIdempotencyKey.isValid(key), isTrue);
  });

  test('canonical operation preserves dots and trims unsafe characters', () {
    expect(
      CanonicalIdempotencyKey.normalizeOperation(
        '  mcp.sales-order.create / mobile  ',
      ),
      'mcp.sales-order.create-mobile',
    );
  });
}
