import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';

class FakeActivityAdmin
    implements FieldActivityClient, FieldReportSettingsAdminClient {
  @override
  Future<List<FieldReportSettingGroup>> loadReportSettings() async => const [];

  @override
  Future<FieldActivityResult> submit({
    required FieldActivityKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    return const FieldActivityResult(
      referenceId: 'unused',
      data: {'id': 'unused'},
    );
  }

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettingGroups() async {
    return const [];
  }

  @override
  Future<void> saveReportSettingGroup({
    String? groupId,
    required String title,
    required String description,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> saveReportSettingItem({
    String? itemId,
    required String groupId,
    required String label,
    required String value,
    required String category,
    required String brandName,
    required String productId,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  }) async {}
}

MobileSession session(List<String> permissions) => MobileSession(
  token: 'nppusr.test-token',
  employeeId: '11111111-1111-4111-8111-111111111111',
  loginName: 'staff.test',
  displayName: 'Nhân viên A',
  expiresAt: null,
  permissions: permissions,
);

void main() {
  testWidgets('report setting menu is hidden without permission', (
    tester,
  ) async {
    final client = FakeActivityAdmin();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session(const []),
          fieldActivityClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm').last);
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập báo cáo thị trường'), findsNothing);
  });

  testWidgets('report setting menu opens with permission', (tester) async {
    final client = FakeActivityAdmin();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: session(const ['mcp.report-setting.write']),
          fieldActivityClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm').last);
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập báo cáo thị trường'), findsOneWidget);

    await tester.tap(find.text('Thiết lập báo cáo thị trường'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-settings-screen')), findsOneWidget);
  });
}
