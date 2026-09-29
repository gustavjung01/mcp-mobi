import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/export/mobile_document_share.dart';
import 'package:mcp_field/features/reports/data_exports_page.dart';

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
        sessionDate: '2026-09-28',
        planned: 2,
        visited: 2,
        orders: 1,
        tests: 1,
        reports: 1,
        followups: 1,
      ),
    ];
  }

  @override
  Future<List<FieldTaskItem>> loadTasks() async {
    return const [
      FieldTaskItem(
        id: 'followup-1',
        title: 'Gọi lại',
        customerName: 'Điểm bán A',
        routeName: 'Tuyến A',
        status: 'todo',
        priority: 'high',
        owner: 'Nhân viên A',
        followupType: 'order',
        sessionId: 'session-1',
      ),
    ];
  }

  @override
  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  }) async {
    return const [
      FieldCheckItem(
        id: 'check-1',
        accountName: 'Điểm bán A',
        productName: 'Trà đào',
        status: 'opportunity',
        date: '2026-09-28',
        routeName: 'Tuyến A',
      ),
    ];
  }

  @override
  Future<List<SessionReportSummary>> loadSessionReports() async {
    return const [
      SessionReportSummary(
        id: 'report-1',
        sessionId: 'session-1',
        routeName: 'Tuyến A',
        status: 'done',
      ),
    ];
  }

  @override
  Future<SessionReportDetail> loadSessionReportDetail(String sessionId) async {
    return const SessionReportDetail(
      session: SessionReportSummary(
        id: 'report-1',
        sessionId: 'session-1',
        routeName: 'Tuyến A',
        status: 'done',
      ),
      customers: [],
      marketReports: [
        SessionMarketReportFact(
          id: 'market-1',
          customerName: 'Điểm bán A',
          content: 'Khách cần báo giá',
        ),
      ],
      tests: [],
      followups: [],
    );
  }

  @override
  Future<List<OutletHistoryItem>> loadOutletHistory(
    String routeCustomerId,
  ) async => const [];

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {}
}

class FakeFieldDataClient implements FieldDataClient {
  @override
  Future<List<FieldRoute>> loadRoutes() async => const [];

  @override
  Future<List<FieldOutlet>> loadOutlets() async {
    return const [
      FieldOutlet(
        id: 'outlet-1',
        routeId: 'route-1',
        routeName: 'Tuyến A',
        code: 'KH001',
        name: 'Điểm bán A',
        phone: '0909000111',
        area: 'Quận 1',
        address: '123 Đường A',
        status: 'active',
        note: '',
        coreCustomerCode: 'KH001',
      ),
    ];
  }

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) {
    throw UnimplementedError();
  }
}

class FakeOrderDataClient implements OrderDataClient {
  @override
  Future<List<FieldOrder>> loadOrders() async {
    return const [
      FieldOrder(
        id: 'order-1',
        status: 'confirmed',
        number: 'SO-001',
        customerName: 'Điểm bán A',
        customerCode: 'KH001',
        total: 100000,
      ),
    ];
  }

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async => const [];

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) {
    throw UnimplementedError();
  }
}

class FakeSharePort implements DocumentSharePort {
  String? fileName;
  String? mimeType;
  String? content;

  @override
  Future<void> shareTextDocument({
    required String fileName,
    required String mimeType,
    required String content,
    bool renderPdf = false,
  }) async {
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.content = content;
  }
}

void main() {
  testWidgets('data export center exposes six office CSV datasets', (
    tester,
  ) async {
    final share = FakeSharePort();
    await tester.pumpWidget(
      MaterialApp(
        home: DataExportsPage(
          historyClient: FakeHistoryClient(),
          fieldDataClient: FakeFieldDataClient(),
          orderDataClient: FakeOrderDataClient(),
          sharePort: share,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      'sessions',
      'orders',
      'outlets',
      'reports',
      'tests',
      'followups',
    ]) {
      expect(find.byKey(Key('data-export-$key')), findsOneWidget);
    }

    final followups = find.byKey(const Key('data-export-followups'));
    await tester.ensureVisible(followups);
    await tester.tap(followups);
    await tester.pumpAndSettle();

    expect(share.fileName, 'mcp-cong-viec.csv');
    expect(share.mimeType, 'text/csv');
    expect(share.content, contains('Gọi lại'));
    expect(share.content, contains('Từ đơn hàng'));
  });
}
