import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/features/reports/session_history_page.dart';

class FakeHistoryClient implements FieldHistoryClient {
  @override
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async {
    return const [
      FieldSessionHistoryItem(
        id: 'session-1',
        routeId: 'route-1',
        routeName: 'Tuyến A',
        status: 'done',
        salesOwner: 'Nhân viên A',
        sessionDate: '2026-09-27',
        planned: 5,
        visited: 4,
        orders: 2,
        tests: 1,
        reports: 1,
        followups: 2,
      ),
      FieldSessionHistoryItem(
        id: 'session-2',
        routeId: 'route-2',
        routeName: 'Tuyến B',
        status: 'cancelled',
        salesOwner: 'Nhân viên B',
        sessionDate: '2026-09-25',
        planned: 3,
        visited: 1,
      ),
    ];
  }

  @override
  Future<List<OutletHistoryItem>> loadOutletHistory(String routeCustomerId) async =>
      const [];

  @override
  Future<List<FieldTaskItem>> loadTasks() async => const [];

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

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {}
}

void main() {
  testWidgets('session history shows 45-day facts and filters by status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionHistoryPage(
          client: FakeHistoryClient(),
          now: DateTime(2026, 9, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-history-session-1')), findsOneWidget);
    expect(find.byKey(const Key('session-history-session-2')), findsOneWidget);
    expect(find.text('Đã ghé: 4/5'), findsOneWidget);
    expect(find.text('Đơn: 2'), findsOneWidget);
    expect(find.text('Công việc: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-history-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã hủy').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-history-session-1')), findsNothing);
    expect(find.byKey(const Key('session-history-session-2')), findsOneWidget);
  });
}
