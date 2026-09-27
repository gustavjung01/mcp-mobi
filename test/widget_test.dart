import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/app/app.dart';

void main() {
  testWidgets('MCP Field shell renders five primary destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(find.text('Hôm nay'), findsWidgets);
    expect(find.text('Đi tuyến'), findsOneWidget);
    expect(find.text('Điểm bán'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Thêm'), findsOneWidget);
  });

  testWidgets('bottom navigation switches business sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    await tester.tap(find.text('Đi tuyến'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routes-screen')), findsOneWidget);

    await tester.tap(find.text('Điểm bán'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outlets-screen')), findsOneWidget);

    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-screen')), findsOneWidget);

    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-screen')), findsOneWidget);
    expect(find.text('Lịch sử phiên'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.text('Kết quả thử sản phẩm'), findsOneWidget);
    expect(find.text('Kế hoạch & Công việc'), findsOneWidget);
    expect(find.text('Mở hoặc liên kết mã khách'), findsOneWidget);
    expect(find.text('Thiết lập'), findsOneWidget);
  });
}
