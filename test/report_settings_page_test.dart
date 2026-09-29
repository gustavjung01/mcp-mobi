import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/features/reports/report_settings_page.dart';

class FakeSettingsClient implements FieldReportSettingsAdminClient {
  bool active = true;
  bool failNext = true;
  final keys = <String>[];

  FieldReportSettingGroup get group => FieldReportSettingGroup(
    id: 'group-1',
    key: 'competitor',
    title: 'Đối thủ',
    description: 'Theo dõi đối thủ tại điểm bán',
    status: active ? 'active' : 'inactive',
    sortOrder: 1,
    items: const [
      FieldReportSettingItem(
        id: 'item-1',
        key: 'brand-a',
        label: 'Nhãn A',
        value: 'Nhãn A',
        groupKey: 'competitor',
        groupTitle: 'Đối thủ',
        status: 'active',
        sortOrder: 1,
      ),
    ],
  );

  @override
  Future<List<FieldReportSettingGroup>> loadReportSettingGroups() async {
    return [group];
  }

  @override
  Future<void> saveReportSettingGroup({
    String? groupId,
    required String title,
    required String description,
    required int sortOrder,
    String? status,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failNext) {
      failNext = false;
      throw const FieldActivityFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Mạng đang gián đoạn. Vui lòng thử lại.',
        retryable: true,
      );
    }
    active = status == 'active';
  }

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

void main() {
  testWidgets(
    'report setting retry reuses the same canonical key',
    (tester) async {
      final client = FakeSettingsClient();
      await tester.pumpWidget(
        MaterialApp(home: ReportSettingsPage(client: client)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đối thủ'), findsOneWidget);
      expect(find.text('Nhãn A'), findsOneWidget);
      expect(
        find.byKey(const Key('report-setting-add-item-group-1')),
        findsOneWidget,
      );

      final toggle = find.byKey(
        const Key('report-setting-group-toggle-group-1'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        find.text('Mạng đang gián đoạn. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(client.keys, hasLength(1));

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(client.keys, hasLength(2));
      expect(client.keys[1], client.keys[0]);
      expect(
        client.keys.first,
        matches(RegExp(r'^[A-Za-z0-9._-]+$')),
      );
      expect(
        client.keys.first,
        startsWith('mcp.report-setting-group.update-'),
      );
      expect(find.text('Đã tắt'), findsOneWidget);
    },
  );
}
