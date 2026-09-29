import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/sync/sync_status.dart';
import 'package:mcp_field/features/more/more_page.dart';

void main() {
  testWidgets('More hides unavailable actions and exposes one sync retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MorePage(
          onTasks: () {},
          syncStatus: AppSyncStatus.waiting(2),
          onRetrySync: () {
            retries += 1;
          },
        ),
      ),
    );

    expect(find.text('Kế hoạch & Công việc'), findsOneWidget);
    expect(find.text('Tuyến cố định'), findsNothing);
    expect(find.text('Báo cáo'), findsNothing);
    expect(find.text('Mở hoặc liên kết mã khách'), findsNothing);
    expect(find.text('Thiết lập'), findsOneWidget);
    expect(find.byKey(const Key('sync-status-card')), findsOneWidget);
    expect(find.text('Còn 2 thao tác đang chờ gửi.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-retry-button')));
    await tester.pump();
    expect(retries, 1);
  });
}
