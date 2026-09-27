import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/app/app.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  testWidgets('app starts with system selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    expect(find.byKey(const Key('system-setup-screen')), findsOneWidget);
    expect(find.text('Chọn hệ thống'), findsOneWidget);
    expect(find.byKey(const Key('login-screen')), findsNothing);
  });

  testWidgets('valid system profile opens login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    await tester.enterText(
      find.byKey(const Key('system-name-field')),
      'Hưng Phát',
    );
    await tester.enterText(
      find.byKey(const Key('system-url-field')),
      'https://mcp.example.vn',
    );
    await tester.tap(find.byKey(const Key('system-continue-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-screen')), findsOneWidget);
    expect(find.text('Hưng Phát'), findsOneWidget);
    expect(find.text('mcp.example.vn'), findsOneWidget);
  });

  testWidgets('invalid system address stays on setup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    await tester.enterText(
      find.byKey(const Key('system-name-field')),
      'Hưng Phát',
    );
    await tester.enterText(
      find.byKey(const Key('system-url-field')),
      'not-a-url',
    );
    await tester.tap(find.byKey(const Key('system-continue-button')));
    await tester.pump();

    expect(find.byKey(const Key('system-setup-screen')), findsOneWidget);
    expect(find.text('Địa chỉ hệ thống chưa hợp lệ'), findsOneWidget);
  });

  testWidgets('login remains blocked until mobile auth contract exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    await tester.enterText(
      find.byKey(const Key('system-name-field')),
      'Hưng Phát',
    );
    await tester.enterText(
      find.byKey(const Key('system-url-field')),
      'https://mcp.example.vn',
    );
    await tester.tap(find.byKey(const Key('system-continue-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(
      find.text('Hệ thống chưa mở đăng nhập dành cho ứng dụng di động.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today-screen')), findsNothing);
  });

  testWidgets('business shell keeps five primary destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const AppShell(),
      ),
    );

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(navLabel('Hôm nay'), findsOneWidget);
    expect(navLabel('Đi tuyến'), findsOneWidget);
    expect(navLabel('Điểm bán'), findsOneWidget);
    expect(navLabel('Đơn hàng'), findsOneWidget);
    expect(navLabel('Thêm'), findsOneWidget);

    await tester.tap(navLabel('Đi tuyến'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routes-screen')), findsOneWidget);

    await tester.tap(navLabel('Đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-screen')), findsOneWidget);
  });
}
