import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/features/tasks/tasks_page.dart';

class FakeHistoryClient implements FieldHistoryClient {
  @override
  Future<List<OutletHistoryItem>> loadOutletHistory(String routeCustomerId) async =>
      const [];

  @override
  Future<List<FieldTaskItem>> loadTasks() async {
    return const [
      FieldTaskItem(
        id: 'task-overdue',
        title: 'Gọi lại chốt đơn',
        customerName: 'Điểm bán A',
        routeName: 'Tuyến A',
        status: 'todo',
        priority: 'high',
        owner: 'Nhân viên A',
        followupType: 'order',
        sessionId: 'session-1',
        sessionDate: '2026-09-20',
        dueDate: '2026-09-27',
        note: 'Khách cần xác nhận số lượng',
      ),
      FieldTaskItem(
        id: 'task-done',
        title: 'Kiểm tra sau thử',
        customerName: 'Điểm bán B',
        routeName: 'Tuyến B',
        status: 'done',
        priority: 'medium',
        owner: 'Nhân viên B',
        followupType: 'test',
        sessionId: 'session-2',
        sessionDate: '2026-09-22',
        dueDate: '2026-09-26',
      ),
      FieldTaskItem(
        id: 'task-blocked',
        title: 'Chờ phản hồi giá',
        customerName: 'Điểm bán C',
        routeName: 'Tuyến C',
        status: 'blocked',
        priority: 'urgent',
        owner: 'Nhân viên A',
        followupType: 'report',
        dueDate: '2026-09-30',
      ),
    ];
  }

  @override
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async => const [];

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
  testWidgets('tasks page shows real work states and overdue filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TasksPage(
          client: FakeHistoryClient(),
          now: DateTime(2026, 9, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-task-overdue')), findsOneWidget);
    expect(find.byKey(const Key('task-task-done')), findsOneWidget);
    expect(find.text('Quá hạn · 27/09/2026'), findsOneWidget);
    expect(find.text('Từ đơn hàng'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-task-blocked')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('task-task-blocked')), findsOneWidget);
    expect(find.text('Bị chặn'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('tasks-due-filter')),
      -300,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, 160));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tasks-due-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quá hạn').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-task-overdue')), findsOneWidget);
    expect(find.byKey(const Key('task-task-done')), findsNothing);
    expect(find.byKey(const Key('task-task-blocked')), findsNothing);

    await tester.tap(find.byKey(const Key('task-task-overdue')));
    await tester.pumpAndSettle();
    expect(find.text('Nguồn phát sinh'), findsOneWidget);
    expect(find.text('Từ đơn hàng'), findsWidgets);
    expect(find.text('Loại công việc'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Khách cần xác nhận số lượng'), findsOneWidget);
  });
}
