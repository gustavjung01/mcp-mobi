import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/main.dart';

void main() {
  testWidgets('MCP Field foundation renders without demo controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const McpFieldApp());

    expect(find.text('MCP Field'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
