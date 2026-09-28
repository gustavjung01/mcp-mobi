import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/sync/field_activity_sync.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/features/reports/field_activity_history_page.dart';

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
  @override
  Future<List<FieldReportSettingGroup>> loadReportSettings() async => const [];

  @override
  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) {
    throw StateError('submit should not run with empty queue');
  }
}

class FakeHistoryClient implements FieldHistoryClient {
  String checkStatus = 'normal';
  String? lastKey;
  String? lastStatus;

  @override
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async => const [];

  @override
  Future<List<FieldTaskItem>> loadTasks() async => const [];

  @override
  Future<List<SessionReportSummary>> loadSessionReports() async {
    return const [
      SessionReportSummary(
        id: 'session-report-1',
        sessionId: 'session-1',
        routeName: 'Tuyến 1',
        status: 'done',
        sessionDate: '2026-09-27',
        planned: 3,
        visited: 2,
        orders: 1,
        tests: 1,
        reports: 1,
        followups: 1,
      ),
    ];
  }

  @override
  Future<SessionReportDetail> loadSessionReportDetail(String sessionId) async {
    return const SessionReportDetail(
      session: SessionReportSummary(
        id: 'session-report-1',
        sessionId: 'session-1',
        routeName: 'Tuyến 1',
        status: 'done',
        sessionDate: '2026-09-27',
        planned: 3,
        visited: 2,
        orders: 1,
        tests: 1,
        reports: 1,
        followups: 1,
      ),
      customers: [
        SessionCustomerFact(
          id: 'sc-1',
          customerName: 'Điểm bán A',
          visitStatus: 'visited',
          orderId: 'order-1',
        ),
        SessionCustomerFact(
          id: 'sc-2',
          customerName: 'Điểm bán B',
          visitStatus: 'skipped',
          statusReason: 'closed',
        ),
      ],
      marketReports: [
        SessionMarketReportFact(
          id: 'report-1',
          customerName: 'Điểm bán A',
          content: 'Đối thủ: Đối thủ A\nSP đang dùng · Trà: Trà A',
          opportunitySummary: 'Có nhu cầu',
          riskSummary: 'Cạnh tranh giá',
        ),
      ],
      tests: [
        SessionTestFact(
          id: 'test-1',
          customerName: 'Điểm bán A',
          productName: 'Trà đào',
          status: 'opportunity',
        ),
      ],
      followups: [
        SessionFollowupFact(
          id: 'followup-1',
          customerName: 'Điểm bán A',
          status: 'pending',
          title: 'Gọi lại',
        ),
      ],
    );
  }

  @override
  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  }) async {
    return [
      FieldCheckItem(
        id: 'result-1',
        accountName: 'Điểm bán A',
        productName: 'Trà đào',
        status: checkStatus,
        date: '2026-09-27',
        routeName: 'Tuyến 1',
      ),
    ];
  }

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {
    lastKey = idempotencyKey;
    lastStatus = status;
    checkStatus = status;
  }
}

void main() {
  testWidgets('report history opens real session detail', (tester) async {
    final queue = FakeQueue();
    final activity = FakeActivityClient();
    final history = FakeHistoryClient();

    await tester.pumpWidget(
      MaterialApp(
        home: FieldActivityHistoryPage(
          kind: FieldActivityKind.report,
          lines: const [],
          queue: queue,
          syncService: FieldActivitySyncService(
            client: activity,
            queue: queue,
          ),
          historyClient: history,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử báo cáo từ hệ thống'), findsOneWidget);
    expect(find.byKey(const Key('session-report-session-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-report-session-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('session-report-detail-screen')),
      findsOneWidget,
    );
    expect(find.text('Báo cáo điểm bán'), findsOneWidget);
    expect(find.textContaining('Đối thủ: Đối thủ A'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Điểm bỏ qua / không mua'),
      300,
    );
    expect(find.text('Điểm bỏ qua / không mua'), findsOneWidget);
    expect(find.text('Đóng cửa'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Công việc theo dõi'),
      300,
    );
    expect(find.text('Công việc theo dõi'), findsOneWidget);
  });

  testWidgets('field check update uses canonical idempotency key', (
    tester,
  ) async {
    final queue = FakeQueue();
    final activity = FakeActivityClient();
    final history = FakeHistoryClient();

    await tester.pumpWidget(
      MaterialApp(
        home: FieldActivityHistoryPage(
          kind: FieldActivityKind.productTrial,
          lines: const [],
          queue: queue,
          syncService: FieldActivitySyncService(
            client: activity,
            queue: queue,
          ),
          historyClient: history,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field-check-edit-result-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cơ hội').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('field-check-save')));
    await tester.pumpAndSettle();

    expect(history.lastStatus, 'opportunity');
    expect(history.lastKey, isNotNull);
    expect(CanonicalIdempotencyKey.isValid(history.lastKey!), isTrue);
    expect(find.text('Đã cập nhật kết quả hậu kiểm.'), findsOneWidget);
  });
}
