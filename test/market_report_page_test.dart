import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/sync/field_activity_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/features/reports/market_report_page.dart';

class FakeQueue implements MutationQueueStore {
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
    final index = items.indexWhere(
      (item) => item.idempotencyKey == mutation.idempotencyKey,
    );
    if (index >= 0) {
      items[index] = mutation;
    } else {
      items.add(mutation);
    }
  }
}

class FakeActivityClient implements FieldActivityClient {
  Map<String, Object?>? submittedPayload;
  String? submittedKey;

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettings() async {
    return const [
      FieldReportSettingGroup(
        id: 'group-competitor',
        key: 'market_competitors',
        title: 'Đối thủ',
        items: [
          FieldReportSettingItem(
            id: 'competitor-a',
            key: 'competitor-a',
            label: 'Đối thủ A',
            value: 'Đối thủ A',
            groupKey: 'market_competitors',
            groupTitle: 'Đối thủ',
          ),
        ],
      ),
      FieldReportSettingGroup(
        id: 'group-used-tea',
        key: 'used_tea',
        title: 'SP đang dùng · Trà',
        items: [
          FieldReportSettingItem(
            id: 'used-tea-a',
            key: 'used-tea-a',
            label: 'Trà A',
            value: 'Trà A',
            groupKey: 'used_tea',
            groupTitle: 'SP đang dùng · Trà',
          ),
        ],
      ),
      FieldReportSettingGroup(
        id: 'group-fields',
        key: 'report_fields',
        title: 'Field báo cáo',
        items: [
          FieldReportSettingItem(
            id: 'field-hidden',
            key: 'field-hidden',
            label: 'Không render chip field',
            value: 'Không render chip field',
            groupKey: 'report_fields',
            groupTitle: 'Field báo cáo',
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
    submittedPayload = payload;
    submittedKey = idempotencyKey;
    return const FieldActivityResult(
      referenceId: 'report-1',
      data: {'reportId': 'report-1'},
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
  testWidgets('market report separates competitor and used-product sections', (
    tester,
  ) async {
    final client = FakeActivityClient();
    final queue = FakeQueue();

    await tester.pumpWidget(
      MaterialApp(
        home: MarketReportPage(
          line: line,
          routeName: 'Tuyến 1',
          routeId: 'route-1',
          sessionDate: '2026-09-28',
          owner: 'Nhân viên A',
          activityClient: client,
          submissionService: FieldActivitySubmissionService(
            client: client,
            queue: queue,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đối thủ'), findsOneWidget);
    expect(find.text('Đối thủ A'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('SP khách đang dùng'),
      300,
    );
    expect(find.text('SP khách đang dùng'), findsOneWidget);
    expect(find.text('SP đang dùng · Trà'), findsOneWidget);
    expect(find.text('Trà A'), findsOneWidget);
    expect(find.text('Không render chip field'), findsNothing);

    await tester.tap(
      find.byKey(const Key('market-report-setting-competitor-a')),
    );
    await tester.tap(
      find.byKey(const Key('market-report-setting-used-tea-a')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('market-report-submit')));
    await tester.pumpAndSettle();

    final selected =
        client.submittedPayload?['selected'] as Map<String, Object?>?;
    final competitors = selected?['competitors'] as List?;
    final usedProducts = selected?['usedProducts'] as List?;
    expect(competitors, hasLength(1));
    expect(usedProducts, hasLength(1));
    expect(client.submittedKey, isNotNull);
    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(client.submittedKey!), isTrue);
  });
}
