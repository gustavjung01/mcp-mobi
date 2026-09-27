import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/app/app.dart';

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  testWidgets('MCP Field shell renders five primary destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(find.text('Hôm nay'), findsWidgets);
    expect(navLabel('Đi tuyến'), findsOneWidget);
    expect(navLabel('Điểm bán'), findsOneWidget);
    expect(navLabel('Đơn hàng'), findsOneWidget);
    expect(navLabel('Thêm'), findsOneWidget);
  });

  testWidgets('bottom navigation switches business sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routes-screen')), findsOneWidget);

    await tester.tap(navLabel('Điểm bán'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outlets-screen')), findsOneWidget);

    await tester.tap(navLabel('Đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-screen')), findsOneWidget);

    await tester.tap(navLabel('Thêm'));
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
