import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/export/mobile_document_share.dart';
import 'package:mcp_field/features/reports/session_report_detail_page.dart';

class FakeHistoryClient
    implements FieldHistoryClient, SessionReportActionClient {
  bool hasSnapshot = false;
  String? snapshotKey;
  String? analysisKey;

  SessionReportDetail get detail => SessionReportDetail(
        session: const SessionReportSummary(
          id: 'report-1',
          sessionId: 'session-1',
          routeName: 'Tuyến A',
          status: 'done',
          sessionDate: '2026-09-28',
          sales: 'Nhân viên A',
          planned: 2,
          visited: 2,
          orders: 1,
          tests: 1,
          reports: 1,
          followups: 1,
        ),
        snapshotId: hasSnapshot ? 'snapshot-1' : null,
        customers: const [
          SessionCustomerFact(
            id: 'sc-1',
            customerName: 'Điểm bán A',
            visitStatus: 'visited',
            orderId: 'order-1',
            testId: 'test-1',
            reportId: 'report-1',
            followupCount: 1,
            area: 'Quận 1',
          ),
        ],
        marketReports: const [
          SessionMarketReportFact(
            id: 'market-1',
            customerName: 'Điểm bán A',
            content: 'Khách cần báo giá',
            opportunitySummary: 'Có nhu cầu',
          ),
        ],
        tests: const [
          SessionTestFact(
            id: 'test-1',
            customerName: 'Điểm bán A',
            productName: 'Trà đào',
            status: 'opportunity',
          ),
        ],
        followups: const [
          SessionFollowupFact(
            id: 'followup-1',
            customerName: 'Điểm bán A',
            status: 'pending',
            title: 'Gọi lại',
          ),
        ],
      );

  @override
  Future<SessionReportDetail> loadSessionReportDetail(String sessionId) async {
    expect(sessionId, 'session-1');
    return detail;
  }

  @override
  Future<void> createSessionReportSnapshot({
    required String sessionId,
    required String idempotencyKey,
  }) async {
    snapshotKey = idempotencyKey;
    hasSnapshot = true;
  }

  @override
  Future<SessionReportAiResult> analyzeSessionReport({
    required String sessionId,
    required String idempotencyKey,
  }) async {
    analysisKey = idempotencyKey;
    return const SessionReportAiResult(
      summary: 'Phiên có cơ hội chốt thêm đơn.',
      orderOpportunities: ['Gọi lại Điểm bán A'],
      risks: ['Cần theo dõi tồn'],
      nextSteps: ['Gửi báo giá'],
    );
  }

  @override
  Future<List<FieldSessionHistoryItem>> loadSessionHistory() async => const [];

  @override
  Future<List<FieldTaskItem>> loadTasks() async => const [];

  @override
  Future<List<OutletHistoryItem>> loadOutletHistory(String routeCustomerId) async =>
      const [];

  @override
  Future<List<SessionReportSummary>> loadSessionReports() async => const [];

  @override
  Future<List<FieldCheckItem>> loadFieldChecks({
    String? status,
    String? search,
  }) async =>
      const [];

  @override
  Future<void> updateFieldCheck({
    required String resultId,
    required String productName,
    required String status,
    required String idempotencyKey,
    String? note,
  }) async {}
}

class FakeSharePort implements DocumentSharePort {
  String? fileName;
  String? mimeType;
  String? content;
  bool renderPdf = false;

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
    this.renderPdf = renderPdf;
  }
}

void main() {
  testWidgets('session report supports snapshot, AI and native export', (
    tester,
  ) async {
    final client = FakeHistoryClient();
    final share = FakeSharePort();

    await tester.pumpWidget(
      MaterialApp(
        home: SessionReportDetailPage(
          client: client,
          sessionId: 'session-1',
          canWriteReport: true,
          sharePort: share,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tuyến A'), findsWidgets);
    expect(find.text('Chưa có bản chốt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-report-snapshot')));
    await tester.pumpAndSettle();

    expect(client.snapshotKey, isNotNull);
    expect(
      client.snapshotKey,
      startsWith('mcp.session-report.snapshot-'),
    );
    expect(
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(client.snapshotKey!),
      isTrue,
    );
    expect(find.text('Đã có bản chốt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-report-analyze')));
    await tester.pumpAndSettle();

    expect(client.analysisKey, isNotNull);
    expect(client.analysisKey, startsWith('mcp.session-report.analyze-'));
    expect(find.byKey(const Key('session-report-analysis-result')), findsOneWidget);
    expect(find.text('Phiên có cơ hội chốt thêm đơn.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-report-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF').last);
    await tester.pumpAndSettle();

    expect(share.mimeType, 'application/pdf');
    expect(share.fileName, endsWith('.pdf'));
    expect(share.renderPdf, isTrue);
    expect(share.content, contains('BÁO CÁO KẾT QUẢ PHIÊN'));
  });

  test('session exporter covers the six CSV business surfaces', () {
    final detail = FakeHistoryClient().detail;
    for (final kind in const [
      SessionExportKind.sessionCsv,
      SessionExportKind.outletsCsv,
      SessionExportKind.ordersCsv,
      SessionExportKind.reportsCsv,
      SessionExportKind.testsCsv,
      SessionExportKind.followupsCsv,
    ]) {
      final file = SessionReportExporter.build(detail, kind);
      expect(file.mimeType, 'text/csv');
      expect(file.fileName, endsWith('.csv'));
      expect(file.content, isNotEmpty);
    }
  });
}
