import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/sync/field_activity_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/features/product_trials/product_trial_page.dart';

class MemoryQueue implements MutationQueueStore {
  final items = <QueuedMutation>[];

  @override
  Future<List<QueuedMutation>> load({Set<String>? operations}) async {
    if (operations == null || operations.isEmpty) return List.of(items);
    return items
        .where((item) => operations.contains(item.operation))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    items.removeWhere((item) => item.idempotencyKey == idempotencyKey);
  }

  @override
  Future<void> save(QueuedMutation mutation) async {
    items.removeWhere(
      (item) => item.idempotencyKey == mutation.idempotencyKey,
    );
    items.add(mutation);
  }
}

class TrialActivityClient
    implements FieldActivityClient, FieldActivityReferenceClient {
  Map<String, Object?>? payload;
  String? key;

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettings() async => const [];

  @override
  Future<List<FieldReportTemplate>> loadReportTemplates() async => const [];

  @override
  Future<List<FieldTestFile>> loadTestFiles() async {
    return const [
      FieldTestFile(
        id: 'file-1',
        title: 'Phiếu Trà',
        testDate: '2026-09-28',
        products: [
          FieldTestProduct(
            id: 'test-product-1',
            productName: 'Trà đào Peso',
          ),
        ],
      ),
    ];
  }

  @override
  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    this.payload = payload;
    key = idempotencyKey;
    return const FieldActivityResult(
      referenceId: 'result-1',
      data: {'testId': 'result-1'},
    );
  }
}

const line = FieldDayLine(
  id: 'line-1',
  sessionCustomerId: 'session-customer-1',
  routeCustomerId: 'route-customer-1',
  sortOrder: 1,
  accountName: 'Điểm bán A',
  area: 'Quận 1',
  source: 'planned',
  status: 'pending',
  note: '',
  hasOrder: false,
  hasTest: false,
  hasReport: false,
  followupCount: 0,
  checkedIn: true,
);

void main() {
  testWidgets('product trial selects canonical file and product', (tester) async {
    final client = TrialActivityClient();
    final queue = MemoryQueue();

    await tester.pumpWidget(
      MaterialApp(
        home: ProductTrialPage(
          line: line,
          activityClient: client,
          submissionService: FieldActivitySubmissionService(
            client: client,
            queue: queue,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('product-trial-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phiếu Trà · 2026-09-28').last);
    await tester.pumpAndSettle();

    final product = find.byKey(
      const Key('product-trial-product-test-product-1'),
    );
    await tester.ensureVisible(product);
    await tester.tap(product);
    await tester.pump();

    final input = tester.widget<TextField>(
      find.byKey(const Key('product-trial-name')),
    );
    expect(input.controller?.text, 'Trà đào Peso');

    await tester.tap(find.byKey(const Key('product-trial-submit')));
    await tester.pumpAndSettle();

    expect(client.payload?['fileId'], 'file-1');
    final results = client.payload?['results'] as List;
    final result = results.single as Map<String, Object?>;
    expect(result['productId'], 'test-product-1');
    expect(result['productName'], 'Trà đào Peso');
    expect(client.key, startsWith('session-customer.test.create-'));
    expect(client.key, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
  });
}
