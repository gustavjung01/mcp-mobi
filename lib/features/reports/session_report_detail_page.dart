import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_history_client.dart';
import '../../core/export/mobile_document_share.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class SessionReportDetailPage extends StatefulWidget {
  const SessionReportDetailPage({
    required this.client,
    required this.sessionId,
    required this.canWriteReport,
    super.key,
    this.sharePort = const DeviceDocumentShare(),
  });

  final FieldHistoryClient client;
  final String sessionId;
  final bool canWriteReport;
  final DocumentSharePort sharePort;

  @override
  State<SessionReportDetailPage> createState() =>
      _SessionReportDetailPageState();
}

class _SessionReportDetailPageState extends State<SessionReportDetailPage> {
  SessionReportDetail? _detail;
  SessionReportAiResult? _analysis;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  String? _snapshotKey;
  String? _analysisKey;

  SessionReportActionClient? get _actions {
    final client = widget.client;
    return client is SessionReportActionClient
        ? client as SessionReportActionClient
        : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final detail = await widget.client.loadSessionReportDetail(widget.sessionId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on FieldHistoryFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _snapshot() async {
    final actions = _actions;
    if (!widget.canWriteReport || actions == null || _busy) return;
    _snapshotKey ??=
        CanonicalIdempotencyKey.create('mcp.session-report.snapshot');
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await actions.createSessionReportSnapshot(
        sessionId: widget.sessionId,
        idempotencyKey: _snapshotKey!,
      );
      _snapshotKey = null;
      final detail = await widget.client.loadSessionReportDetail(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _message = 'Đã cập nhật bản chốt báo cáo phiên.';
      });
    } on FieldHistoryFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final actions = _actions;
    final detail = _detail;
    if (!widget.canWriteReport || actions == null || detail == null || _busy) {
      return;
    }
    if (!detail.hasSnapshot) {
      setState(() {
        _message = 'Cần tạo bản chốt báo cáo phiên trước khi phân tích.';
      });
      return;
    }

    _analysisKey ??=
        CanonicalIdempotencyKey.create('mcp.session-report.analyze');
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await actions.analyzeSessionReport(
        sessionId: widget.sessionId,
        idempotencyKey: _analysisKey!,
      );
      _analysisKey = null;
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _message = 'Đã hoàn tất phân tích báo cáo.';
      });
    } on FieldHistoryFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(SessionExportKind kind) async {
    final detail = _detail;
    if (detail == null || _busy) return;
    final file = SessionReportExporter.build(detail, kind, ai: _analysis);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.sharePort.shareTextDocument(
        fileName: file.fileName,
        mimeType: file.mimeType,
        content: file.content,
        renderPdf: file.renderPdf,
      );
    } on DocumentShareFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      key: const Key('session-report-detail-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Báo cáo phiên',
            subtitle: detail?.session.routeName ?? 'Chi tiết phiên',
            leading: IconButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              key: const Key('session-report-refresh'),
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if ((_message ?? '').isNotEmpty) ...[
                    AppCard(
                      child: Text(
                        _message!,
                        key: const Key('session-report-message'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (detail == null)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'Chưa có dữ liệu báo cáo',
                        message: 'Kiểm tra lại phiên hoặc tải lại dữ liệu.',
                      ),
                    )
                  else ...[
                    _HeaderCard(detail: detail),
                    const SizedBox(height: AppSpacing.md),
                    _ActionCard(
                      detail: detail,
                      canWriteReport:
                          widget.canWriteReport && _actions != null,
                      busy: _busy,
                      onSnapshot: _snapshot,
                      onAnalyze: _analyze,
                      onExport: _export,
                    ),
                    if (_analysis != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _AnalysisCard(analysis: _analysis!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _Section(
                      title: 'Điểm bán trong phiên',
                      children: detail.customers
                          .map(
                            (item) => _Fact(
                              title: item.customerName,
                              subtitle: [
                                if ((item.area ?? '').isNotEmpty) item.area!,
                                _visitLabel(item.visitStatus),
                                if (item.orderId != null) 'Có đơn',
                                if (item.testId != null) 'Có thử sản phẩm',
                                if (item.reportId != null) 'Có báo cáo',
                                if (item.followupCount > 0)
                                  '${item.followupCount} công việc',
                              ].join(' · '),
                              note: item.note,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (detail.marketReports.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Section(
                        title: 'Báo cáo thị trường',
                        children: detail.marketReports
                            .map(
                              (item) => _Fact(
                                title: item.customerName,
                                subtitle: [
                                  item.competitorSummary,
                                  item.opportunitySummary,
                                  item.riskSummary,
                                  item.nextAction,
                                ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                                note: item.content ?? item.note,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (detail.tests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Section(
                        title: 'Thử sản phẩm',
                        children: detail.tests
                            .map(
                              (item) => _Fact(
                                title: item.productName,
                                subtitle:
                                    '${item.customerName} · ${_testLabel(item.status)}',
                                note: item.note,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (detail.followups.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Section(
                        title: 'Kế hoạch & Công việc',
                        children: detail.followups
                            .map(
                              (item) => _Fact(
                                title: item.title ?? 'Công việc theo dõi',
                                subtitle: [
                                  item.customerName,
                                  if ((item.dueDate ?? '').isNotEmpty)
                                    item.dueDate!,
                                  if ((item.owner ?? '').isNotEmpty)
                                    item.owner!,
                                  _taskStatus(item.status),
                                ].join(' · '),
                                note: item.note,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});
  final SessionReportDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.session;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.routeName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(
                label: detail.hasSnapshot ? 'Đã có bản chốt' : 'Chưa có bản chốt',
                backgroundColor: detail.hasSnapshot
                    ? AppColors.successSoft
                    : AppColors.warningSoft,
                foregroundColor: detail.hasSnapshot
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [s.sessionDate ?? '', s.sales ?? '']
                .where((value) => value.isNotEmpty)
                .join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Metric('Kế hoạch', s.planned),
              _Metric('Đã ghé', s.visited),
              _Metric('Đơn', s.orders),
              _Metric('Thử sản phẩm', s.tests),
              _Metric('Báo cáo', s.reports),
              _Metric('Công việc', s.followups),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.detail,
    required this.canWriteReport,
    required this.busy,
    required this.onSnapshot,
    required this.onAnalyze,
    required this.onExport,
  });

  final SessionReportDetail detail;
  final bool canWriteReport;
  final bool busy;
  final VoidCallback onSnapshot;
  final VoidCallback onAnalyze;
  final ValueChanged<SessionExportKind> onExport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thao tác báo cáo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (canWriteReport)
                OutlinedButton.icon(
                  key: const Key('session-report-snapshot'),
                  onPressed: busy ? null : onSnapshot,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    detail.hasSnapshot ? 'Cập nhật bản chốt' : 'Tạo bản chốt',
                  ),
                ),
              if (canWriteReport)
                FilledButton.tonalIcon(
                  key: const Key('session-report-analyze'),
                  onPressed: busy ? null : onAnalyze,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Phân tích AI'),
                ),
              PopupMenuButton<SessionExportKind>(
                key: const Key('session-report-export'),
                enabled: !busy,
                tooltip: 'Xuất file',
                onSelected: onExport,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: SessionExportKind.word,
                    child: Text('Word'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.excel,
                    child: Text('Excel'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.pdf,
                    child: Text('PDF'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.markdown,
                    child: Text('Markdown'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.json,
                    child: Text('JSON'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: SessionExportKind.sessionCsv,
                    child: Text('CSV · Phiên'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.outletsCsv,
                    child: Text('CSV · Điểm bán'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.ordersCsv,
                    child: Text('CSV · Đơn hàng'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.reportsCsv,
                    child: Text('CSV · Báo cáo'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.testsCsv,
                    child: Text('CSV · Thử sản phẩm'),
                  ),
                  PopupMenuItem(
                    value: SessionExportKind.followupsCsv,
                    child: Text('CSV · Công việc'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_outlined, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Xuất file',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});
  final SessionReportAiResult analysis;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('session-report-analysis-result'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích báo cáo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            analysis.summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (analysis.orderOpportunities.isNotEmpty)
            _BulletGroup('Cơ hội đơn hàng', analysis.orderOpportunities),
          if (analysis.risks.isNotEmpty) _BulletGroup('Rủi ro', analysis.risks),
          if (analysis.nextSteps.isNotEmpty)
            _BulletGroup('Việc tiếp theo', analysis.nextSteps),
        ],
      ),
    );
  }
}

class _BulletGroup extends StatelessWidget {
  const _BulletGroup(this.title, this.items);
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          ...items.map(
            (item) => Text(
              '• $item',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...children.map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(child: child),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.title,
    required this.subtitle,
    this.note,
  });

  final String title;
  final String subtitle;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        if ((note ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

String _visitLabel(String value) => switch (value) {
      'visited' => 'Đã ghé',
      'skipped' => 'Bỏ qua',
      _ => 'Chờ ghé',
    };

String _testLabel(String value) => switch (value) {
      'opportunity' => 'Cơ hội',
      'risk' => 'Rủi ro',
      _ => 'Bình thường',
    };

String _taskStatus(String value) => switch (value) {
      'done' => 'Đã xong',
      'doing' => 'Đang làm',
      'blocked' => 'Bị chặn',
      _ => 'Cần làm',
    };
