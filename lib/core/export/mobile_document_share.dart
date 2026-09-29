import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/field_history_client.dart';

class DocumentShareFailure implements Exception {
  const DocumentShareFailure(this.message);
  final String message;
}

abstract interface class DocumentSharePort {
  Future<void> shareTextDocument({
    required String fileName,
    required String mimeType,
    required String content,
    bool renderPdf = false,
  });
}

class DeviceDocumentShare implements DocumentSharePort {
  const DeviceDocumentShare();
  static const _channel = MethodChannel('com.hungphat.mcpfield/documents');

  @override
  Future<void> shareTextDocument({
    required String fileName,
    required String mimeType,
    required String content,
    bool renderPdf = false,
  }) async {
    try {
      await _channel.invokeMethod<void>('shareTextDocument', {
        'fileName': fileName,
        'mimeType': mimeType,
        'content': content,
        'renderPdf': renderPdf,
      });
    } on PlatformException catch (error) {
      throw DocumentShareFailure(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Không mở được chức năng chia sẻ file.',
      );
    } on MissingPluginException {
      throw const DocumentShareFailure(
        'Thiết bị chưa hỗ trợ chức năng chia sẻ file.',
      );
    }
  }
}

enum SessionExportKind {
  word,
  excel,
  pdf,
  markdown,
  json,
  sessionCsv,
  outletsCsv,
  ordersCsv,
  reportsCsv,
  testsCsv,
  followupsCsv,
}

class SessionReportExport {
  const SessionReportExport({
    required this.fileName,
    required this.mimeType,
    required this.content,
    this.renderPdf = false,
  });
  final String fileName;
  final String mimeType;
  final String content;
  final bool renderPdf;
}

class SessionReportExporter {
  const SessionReportExporter._();

  static SessionReportExport build(
    SessionReportDetail detail,
    SessionExportKind kind, {
    SessionReportAiResult? ai,
  }) {
    final base = _baseName(detail);
    return switch (kind) {
      SessionExportKind.word => SessionReportExport(
          fileName: '$base.doc',
          mimeType: 'application/msword',
          content: _html(detail, ai, excel: false),
        ),
      SessionExportKind.excel => SessionReportExport(
          fileName: '$base.xls',
          mimeType: 'application/vnd.ms-excel',
          content: _html(detail, ai, excel: true),
        ),
      SessionExportKind.pdf => SessionReportExport(
          fileName: '$base.pdf',
          mimeType: 'application/pdf',
          content: _plain(detail, ai),
          renderPdf: true,
        ),
      SessionExportKind.markdown => SessionReportExport(
          fileName: '$base.md',
          mimeType: 'text/markdown',
          content: '# Báo cáo kết quả phiên\n\n${_plain(detail, ai)}',
        ),
      SessionExportKind.json => SessionReportExport(
          fileName: '$base.json',
          mimeType: 'application/json',
          content: const JsonEncoder.withIndent('  ').convert(
            _json(detail, ai),
          ),
        ),
      SessionExportKind.sessionCsv => _csvExport(
          '${base}_phien.csv',
          [
            ['Mã phiên', 'Tuyến', 'Ngày', 'Nhân viên', 'Trạng thái'],
            [
              detail.session.sessionId,
              detail.session.routeName,
              detail.session.sessionDate ?? '',
              detail.session.sales ?? '',
              detail.session.status,
            ],
          ],
        ),
      SessionExportKind.outletsCsv => _csvExport(
          '${base}_diem-ban.csv',
          [
            ['Điểm bán', 'Khu vực', 'Kết quả', 'Lý do', 'Đơn', 'Thử sản phẩm', 'Báo cáo', 'Công việc'],
            ...detail.customers.map((item) => [
              item.customerName,
              item.area ?? '',
              item.visitStatus,
              item.statusReason ?? '',
              item.orderId ?? '',
              item.testId ?? '',
              item.reportId ?? '',
              item.followupCount,
            ]),
          ],
        ),
      SessionExportKind.ordersCsv => _csvExport(
          '${base}_don-hang.csv',
          [
            ['Điểm bán', 'Mã đơn'],
            ...detail.customers
                .where((item) => (item.orderId ?? '').isNotEmpty)
                .map((item) => [item.customerName, item.orderId ?? '']),
          ],
        ),
      SessionExportKind.reportsCsv => _csvExport(
          '${base}_bao-cao-thi-truong.csv',
          [
            ['Điểm bán', 'Nội dung', 'Đối thủ', 'Cơ hội', 'Rủi ro', 'Việc tiếp theo'],
            ...detail.marketReports.map((item) => [
              item.customerName,
              item.content ?? '',
              item.competitorSummary ?? '',
              item.opportunitySummary ?? '',
              item.riskSummary ?? '',
              item.nextAction ?? '',
            ]),
          ],
        ),
      SessionExportKind.testsCsv => _csvExport(
          '${base}_thu-san-pham.csv',
          [
            ['Điểm bán', 'Sản phẩm', 'Kết quả', 'Ghi chú'],
            ...detail.tests.map((item) => [
              item.customerName,
              item.productName,
              item.status,
              item.note ?? '',
            ]),
          ],
        ),
      SessionExportKind.followupsCsv => _csvExport(
          '${base}_cong-viec.csv',
          [
            ['Điểm bán', 'Công việc', 'Ngày hẹn', 'Ưu tiên', 'Người phụ trách', 'Trạng thái'],
            ...detail.followups.map((item) => [
              item.customerName,
              item.title ?? '',
              item.dueDate ?? '',
              item.priority ?? '',
              item.owner ?? '',
              item.status,
            ]),
          ],
        ),
    };
  }

  static SessionReportExport buildCsv({
    required String fileName,
    required Iterable<Iterable<Object?>> rows,
  }) {
    return _csvExport(fileName, rows);
  }

  static SessionReportExport _csvExport(
    String name,
    Iterable<Iterable<Object?>> rows,
  ) {
    return SessionReportExport(
      fileName: name,
      mimeType: 'text/csv',
      content: '\ufeff${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}',
    );
  }

  static String _csvCell(Object? value) {
    final text = (value ?? '').toString();
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _baseName(SessionReportDetail detail) {
    final date = (detail.session.sessionDate ?? '').replaceAll(RegExp(r'[^0-9]'), '-');
    return 'bao-cao-phien-${detail.session.sessionId}${date.isEmpty ? '' : '-$date'}';
  }

  static String _plain(
    SessionReportDetail detail,
    SessionReportAiResult? ai,
  ) {
    final b = StringBuffer()
      ..writeln('BÁO CÁO KẾT QUẢ PHIÊN')
      ..writeln(detail.session.routeName)
      ..writeln(
        [detail.session.sessionDate ?? '', detail.session.sales ?? '']
            .where((v) => v.isNotEmpty)
            .join(' · '),
      )
      ..writeln()
      ..writeln(
        'Kế hoạch ${detail.session.planned} · Đã ghé ${detail.session.visited} · '
        'Đơn ${detail.session.orders} · Thử sản phẩm ${detail.session.tests} · '
        'Báo cáo ${detail.session.reports} · Công việc ${detail.session.followups}',
      );
    if (ai != null) {
      b
        ..writeln()
        ..writeln('PHÂN TÍCH')
        ..writeln(ai.summary);
      _append(b, 'Rủi ro', ai.risks);
      _append(b, 'Cơ hội đơn hàng', ai.orderOpportunities);
      _append(b, 'Việc tiếp theo', ai.nextSteps);
    }
    _append(
      b,
      'Điểm bán',
      detail.customers
          .map(
            (x) => '${x.customerName} · ${x.visitStatus}'
                '${x.orderId == null ? '' : ' · Có đơn'}'
                '${x.testId == null ? '' : ' · Có thử sản phẩm'}'
                '${x.reportId == null ? '' : ' · Có báo cáo'}',
          )
          .toList(),
    );
    _append(
      b,
      'Thử sản phẩm',
      detail.tests
          .map((x) => '${x.customerName} · ${x.productName} · ${x.status}')
          .toList(),
    );
    _append(
      b,
      'Công việc',
      detail.followups
          .map((x) => '${x.customerName} · ${x.title ?? 'Công việc'}')
          .toList(),
    );
    return b.toString();
  }

  static void _append(StringBuffer b, String title, List<String> rows) {
    if (rows.isEmpty) return;
    b
      ..writeln()
      ..writeln(title.toUpperCase());
    for (final row in rows) {
      b.writeln('- $row');
    }
  }

  static Map<String, Object?> _json(
    SessionReportDetail detail,
    SessionReportAiResult? ai,
  ) {
    return {
      'session': {
        'id': detail.session.sessionId,
        'routeName': detail.session.routeName,
        'sessionDate': detail.session.sessionDate,
        'sales': detail.session.sales,
        'status': detail.session.status,
        'snapshotId': detail.snapshotId,
      },
      'customers': detail.customers
          .map((x) => {
                'customerName': x.customerName,
                'area': x.area,
                'visitStatus': x.visitStatus,
                'statusReason': x.statusReason,
                'orderId': x.orderId,
                'testId': x.testId,
                'reportId': x.reportId,
                'followupCount': x.followupCount,
              })
          .toList(),
      'marketReports': detail.marketReports
          .map((x) => {
                'customerName': x.customerName,
                'content': x.content,
                'competitorSummary': x.competitorSummary,
                'opportunitySummary': x.opportunitySummary,
                'riskSummary': x.riskSummary,
                'nextAction': x.nextAction,
              })
          .toList(),
      'tests': detail.tests
          .map((x) => {
                'customerName': x.customerName,
                'productName': x.productName,
                'status': x.status,
                'note': x.note,
              })
          .toList(),
      'followups': detail.followups
          .map((x) => {
                'customerName': x.customerName,
                'title': x.title,
                'dueDate': x.dueDate,
                'priority': x.priority,
                'owner': x.owner,
                'status': x.status,
              })
          .toList(),
      if (ai != null)
        'analysis': {
          'summary': ai.summary,
          'risks': ai.risks,
          'orderOpportunities': ai.orderOpportunities,
          'nextSteps': ai.nextSteps,
          'analyzedAt': ai.analyzedAt,
        },
    };
  }

  static String _html(
    SessionReportDetail detail,
    SessionReportAiResult? ai, {
    required bool excel,
  }) {
    final rows = detail.customers
        .map(
          (x) => '<tr><td>${_esc(x.customerName)}</td>'
              '<td>${_esc(x.area ?? '')}</td>'
              '<td>${_esc(x.visitStatus)}</td>'
              '<td>${_esc(x.orderId ?? '')}</td>'
              '<td>${_esc(x.testId ?? '')}</td>'
              '<td>${_esc(x.reportId ?? '')}</td></tr>',
        )
        .join();
    return '<html><head><meta charset="utf-8"></head><body>'
        '${excel ? '' : '<h1>Báo cáo kết quả phiên</h1><p>${_esc(detail.session.routeName)}</p>'}'
        '<table border="1"><tr><th>Điểm bán</th><th>Khu vực</th>'
        '<th>Kết quả</th><th>Mã đơn</th><th>Mã thử sản phẩm</th><th>Mã báo cáo</th></tr>'
        '$rows</table>'
        '${ai == null || excel ? '' : '<h2>Phân tích</h2><p>${_esc(ai.summary)}</p>'}'
        '</body></html>';
  }

  static String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
