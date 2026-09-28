import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/field_history_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../core/sync/mutation_queue.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class FieldActivityHistoryPage extends StatefulWidget {
  const FieldActivityHistoryPage({
    required this.kind,
    required this.lines,
    required this.queue,
    required this.syncService,
    super.key,
    this.historyClient,
    this.onSynchronized,
  });

  final FieldActivityKind kind;
  final List<FieldDayLine> lines;
  final MutationQueueStore queue;
  final FieldActivitySyncService syncService;
  final FieldHistoryClient? historyClient;
  final Future<void> Function()? onSynchronized;

  @override
  State<FieldActivityHistoryPage> createState() =>
      _FieldActivityHistoryPageState();
}

class _FieldActivityHistoryPageState extends State<FieldActivityHistoryPage> {
  List<QueuedMutation> _mutations = const [];
  List<SessionReportSummary> _reports = const [];
  List<FieldCheckItem> _checks = const [];
  final Map<String, String> _fieldCheckKeys = {};
  bool _loading = true;
  bool _syncing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh(sync: true);
  }

  Future<void> _loadDeviceState() async {
    try {
      final rows = await widget.queue.load(
        operations: {widget.kind.operation},
      );
      if (!mounted) return;
      _mutations = rows.reversed.toList(growable: false);
    } catch (_) {
      if (mounted) {
        _message = 'Chưa đọc được trạng thái gửi trên thiết bị.';
      }
    }
  }

  Future<void> _loadServerHistory() async {
    final client = widget.historyClient;
    if (client == null) return;
    try {
      if (widget.kind == FieldActivityKind.report) {
        _reports = await client.loadSessionReports();
      } else if (widget.kind == FieldActivityKind.productTrial) {
        _checks = await client.loadFieldChecks();
      }
    } on FieldHistoryFailure catch (failure) {
      _message = failure.message;
    }
  }

  Future<void> _refresh({bool sync = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
        if (sync) _syncing = true;
      });
    }

    if (sync) {
      try {
        final result = await widget.syncService.syncPending();
        if (result.sent > 0) {
          await widget.onSynchronized?.call();
        }
      } finally {
        _syncing = false;
      }
    }

    await Future.wait([_loadDeviceState(), _loadServerHistory()]);
    if (mounted) {
      setState(() {
        _loading = false;
        _syncing = false;
      });
    }
  }

  Future<void> _retry(QueuedMutation mutation) async {
    setState(() {
      _syncing = true;
      _message = null;
    });
    try {
      final result = await widget.syncService.syncPending(
        idempotencyKey: mutation.idempotencyKey,
      );
      if (result.sent > 0) {
        await widget.onSynchronized?.call();
      }
      await Future.wait([_loadDeviceState(), _loadServerHistory()]);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  List<FieldDayLine> get _currentSessionLines {
    return widget.lines
        .where((line) {
          return switch (widget.kind) {
            FieldActivityKind.report => line.hasReport,
            FieldActivityKind.productTrial => line.hasTest,
            FieldActivityKind.followup => line.followupCount > 0,
          };
        })
        .toList(growable: false);
  }

  Future<void> _openReport(SessionReportSummary report) async {
    final client = widget.historyClient;
    if (client == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _SessionReportDetailPage(
          report: report,
          client: client,
        ),
      ),
    );
  }

  Future<void> _editCheck(FieldCheckItem item) async {
    final client = widget.historyClient;
    if (client == null) return;
    final input = await showModalBottomSheet<_FieldCheckEditInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _FieldCheckEditSheet(item: item),
    );
    if (input == null || !mounted) return;

    final fingerprint =
        '${item.id}|${item.productName}|${input.status}|${input.note.trim()}';
    final key = _fieldCheckKeys.putIfAbsent(
      fingerprint,
      () => CanonicalIdempotencyKey.create('field-check.result.update'),
    );

    setState(() {
      _syncing = true;
      _message = null;
    });
    try {
      await client.updateFieldCheck(
        resultId: item.id,
        productName: item.productName,
        status: input.status,
        note: input.note,
        idempotencyKey: key,
      );
      _fieldCheckKeys.remove(fingerprint);
      _checks = await client.loadFieldChecks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật kết quả hậu kiểm.')),
      );
    } on FieldHistoryFailure catch (failure) {
      if (!failure.retryable) {
        _fieldCheckKeys.remove(fingerprint);
      }
      if (mounted) {
        setState(() => _message = failure.message);
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  bool get _hasServerHistory {
    return switch (widget.kind) {
      FieldActivityKind.report => _reports.isNotEmpty,
      FieldActivityKind.productTrial => _checks.isNotEmpty,
      FieldActivityKind.followup => _currentSessionLines.isNotEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentLines = _currentSessionLines;
    return Scaffold(
      key: Key('field-activity-history-${widget.kind.name}'),
      body: Column(
        children: [
          NavyPageHeader(
            title: _title(widget.kind),
            subtitle: _subtitle(widget.kind),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              key: const Key('field-activity-sync'),
              onPressed: _syncing ? null : () => _refresh(sync: true),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(sync: true),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if ((_message ?? '').isNotEmpty) ...[
                    AppCard(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_hasServerHistory &&
                      currentLines.isEmpty &&
                      _mutations.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: _icon(widget.kind),
                        title: 'Chưa có dữ liệu',
                        message: _emptyMessage(widget.kind),
                      ),
                    )
                  else ...[
                    if (widget.kind == FieldActivityKind.report &&
                        _reports.isNotEmpty) ...[
                      const _ListTitle('Lịch sử báo cáo từ hệ thống'),
                      const SizedBox(height: AppSpacing.sm),
                      ..._reports.map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _SessionReportCard(
                            report: report,
                            onTap: () => _openReport(report),
                          ),
                        ),
                      ),
                    ],
                    if (widget.kind == FieldActivityKind.productTrial &&
                        _checks.isNotEmpty) ...[
                      const _ListTitle('Kết quả thử từ hệ thống'),
                      const SizedBox(height: AppSpacing.sm),
                      ..._checks.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _FieldCheckCard(
                            item: item,
                            busy: _syncing,
                            onEdit: () => _editCheck(item),
                          ),
                        ),
                      ),
                    ],
                    if (currentLines.isNotEmpty) ...[
                      if (_reports.isNotEmpty || _checks.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      _ListTitle(
                        widget.kind == FieldActivityKind.followup
                            ? 'Trong phiên hiện tại'
                            : 'Phiên đang mở',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...currentLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CurrentActivityCard(
                            kind: widget.kind,
                            line: line,
                          ),
                        ),
                      ),
                    ],
                    if (_mutations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _ListTitle('Trạng thái gửi trên thiết bị'),
                      const SizedBox(height: AppSpacing.sm),
                      ..._mutations.map(
                        (mutation) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: _MutationCard(
                            mutation: mutation,
                            busy: _syncing,
                            onRetry: () => _retry(mutation),
                          ),
                        ),
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

class _SessionReportCard extends StatelessWidget {
  const _SessionReportCard({
    required this.report,
    required this.onTap,
  });

  final SessionReportSummary report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: Key('session-report-${report.sessionId}'),
          onTap: onTap,
          leading: const CircleAvatar(
            child: Icon(Icons.assignment_outlined),
          ),
          title: Text(
            report.routeName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            [
              _dateLabel(report.sessionDate),
              '${report.visited}/${report.planned} điểm',
              '${report.orders} đơn',
              '${report.tests} thử',
              '${report.reports} báo cáo',
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _FieldCheckCard extends StatelessWidget {
  const _FieldCheckCard({
    required this.item,
    required this.busy,
    required this.onEdit,
  });

  final FieldCheckItem item;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final status = _fieldCheckLabel(item.status);
    final color = item.status == 'opportunity'
        ? AppColors.success
        : item.status == 'risk'
        ? AppColors.danger
        : AppColors.textSecondary;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    item.accountName,
                    item.routeName ?? '',
                    _dateLabel(item.date),
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if ((item.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: status,
                backgroundColor: item.status == 'opportunity'
                    ? AppColors.successSoft
                    : item.status == 'risk'
                    ? AppColors.dangerSoft
                    : AppColors.primarySoft,
                foregroundColor: color,
              ),
              TextButton(
                key: Key('field-check-edit-${item.id}'),
                onPressed: busy ? null : onEdit,
                child: const Text('Cập nhật'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentActivityCard extends StatelessWidget {
  const _CurrentActivityCard({
    required this.kind,
    required this.line,
  });

  final FieldActivityKind kind;
  final FieldDayLine line;

  @override
  Widget build(BuildContext context) {
    final detail = switch (kind) {
      FieldActivityKind.report => 'Báo cáo đã ghi nhận trong phiên đang mở',
      FieldActivityKind.productTrial =>
        'Kết quả thử đã ghi nhận trong phiên đang mở',
      FieldActivityKind.followup => '${line.followupCount} việc cần theo dõi',
    };
    return AppCard(
      child: Row(
        children: [
          Icon(_icon(kind), color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.accountName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const StatusPill(
            label: 'Đã ghi nhận',
            backgroundColor: AppColors.successSoft,
            foregroundColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _SessionReportDetailPage extends StatefulWidget {
  const _SessionReportDetailPage({
    required this.report,
    required this.client,
  });

  final SessionReportSummary report;
  final FieldHistoryClient client;

  @override
  State<_SessionReportDetailPage> createState() =>
      _SessionReportDetailPageState();
}

class _SessionReportDetailPageState
    extends State<_SessionReportDetailPage> {
  SessionReportDetail? _detail;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final detail = await widget.client.loadSessionReportDetail(
        widget.report.sessionId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } on FieldHistoryFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            title: 'Chi tiết báo cáo phiên',
            subtitle: [
              widget.report.routeName,
              _dateLabel(widget.report.sessionDate),
            ].where((value) => value.isNotEmpty).join(' · '),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : detail == null
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      AppCard(
                        child: Text(
                          _message ?? 'Chưa tải được báo cáo phiên.',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  )
                : _SessionReportDetailBody(detail: detail),
          ),
        ],
      ),
    );
  }
}

class _SessionReportDetailBody extends StatelessWidget {
  const _SessionReportDetailBody({required this.detail});

  final SessionReportDetail detail;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final skipped = detail.customers
        .where((item) => item.visitStatus == 'skipped')
        .toList(growable: false);
    final ordered = detail.customers
        .where((item) => (item.orderId ?? '').isNotEmpty)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Metric(
              label: 'Điểm',
              value: '${session.visited}/${session.planned}',
            ),
            _Metric(label: 'Đơn', value: session.orders.toString()),
            _Metric(label: 'Thử SP', value: session.tests.toString()),
            _Metric(label: 'Báo cáo', value: session.reports.toString()),
            _Metric(label: 'Theo dõi', value: session.followups.toString()),
            _Metric(label: 'Bỏ qua', value: skipped.length.toString()),
          ],
        ),
        if (detail.marketReports.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ListTitle('Báo cáo điểm bán'),
          const SizedBox(height: AppSpacing.sm),
          ...detail.marketReports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.customerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((report.content ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        report.content!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if ((report.opportunitySummary ?? '').isNotEmpty)
                      _FactLine(
                        label: 'Cơ hội',
                        value: report.opportunitySummary!,
                      ),
                    if ((report.riskSummary ?? '').isNotEmpty)
                      _FactLine(label: 'Rủi ro', value: report.riskSummary!),
                    if ((report.nextAction ?? '').isNotEmpty)
                      _FactLine(
                        label: 'Việc tiếp theo',
                        value: report.nextAction!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (detail.tests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ListTitle('Thử sản phẩm'),
          const SizedBox(height: AppSpacing.sm),
          ...detail.tests.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: _SimpleFact(
                  icon: Icons.science_outlined,
                  title: item.productName,
                  subtitle:
                      '${item.customerName} · ${_fieldCheckLabel(item.status)}',
                  note: item.note,
                ),
              ),
            ),
          ),
        ],
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ListTitle('Điểm có đơn'),
          const SizedBox(height: AppSpacing.sm),
          ...ordered.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: _SimpleFact(
                  icon: Icons.receipt_long_outlined,
                  title: item.customerName,
                  subtitle: 'Đã phát sinh đơn trong phiên',
                ),
              ),
            ),
          ),
        ],
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ListTitle('Điểm bỏ qua / không mua'),
          const SizedBox(height: AppSpacing.sm),
          ...skipped.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: _SimpleFact(
                  icon: Icons.remove_circle_outline_rounded,
                  title: item.customerName,
                  subtitle: _skipReasonLabel(item.statusReason),
                  note: item.note,
                ),
              ),
            ),
          ),
        ],
        if (detail.followups.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ListTitle('Công việc theo dõi'),
          const SizedBox(height: AppSpacing.sm),
          ...detail.followups.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: _SimpleFact(
                  icon: Icons.task_alt_outlined,
                  title: item.title ?? 'Công việc theo dõi',
                  subtitle: [
                    item.customerName,
                    _dateLabel(item.dueDate),
                    _followupStatusLabel(item.status),
                  ].where((value) => value.isNotEmpty).join(' · '),
                  note: item.note,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SimpleFact extends StatelessWidget {
  const _SimpleFact({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.note,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
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
          ),
        ),
      ],
    );
  }
}

class _FieldCheckEditInput {
  const _FieldCheckEditInput({
    required this.status,
    required this.note,
  });

  final String status;
  final String note;
}

class _FieldCheckEditSheet extends StatefulWidget {
  const _FieldCheckEditSheet({required this.item});

  final FieldCheckItem item;

  @override
  State<_FieldCheckEditSheet> createState() => _FieldCheckEditSheetState();
}

class _FieldCheckEditSheetState extends State<_FieldCheckEditSheet> {
  late String _status;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _note = TextEditingController(text: widget.item.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.productName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.accountName,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Kết quả hậu kiểm',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              key: const Key('field-check-status'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'normal', label: Text('Bình thường')),
                ButtonSegment(value: 'opportunity', label: Text('Cơ hội')),
                ButtonSegment(value: 'risk', label: Text('Rủi ro')),
              ],
              selected: {_status},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(() => _status = values.first);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('field-check-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Ghi nhận diễn biến sau khi khách thử sản phẩm',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('field-check-save'),
              onPressed: () => Navigator.of(context).pop(
                _FieldCheckEditInput(
                  status: _status,
                  note: _note.text.trim(),
                ),
              ),
              child: const Text('Lưu kết quả'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutationCard extends StatelessWidget {
  const _MutationCard({
    required this.mutation,
    required this.busy,
    required this.onRetry,
  });

  final QueuedMutation mutation;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = switch (mutation.state) {
      MutationQueueState.waiting => 'Chờ gửi',
      MutationQueueState.failed => 'Gửi lỗi',
      MutationQueueState.acknowledged => 'Đã đồng bộ',
    };
    final color = switch (mutation.state) {
      MutationQueueState.waiting => AppColors.warning,
      MutationQueueState.failed => AppColors.danger,
      MutationQueueState.acknowledged => AppColors.success,
    };
    final background = switch (mutation.state) {
      MutationQueueState.waiting => AppColors.warningSoft,
      MutationQueueState.failed => AppColors.dangerSoft,
      MutationQueueState.acknowledged => AppColors.successSoft,
    };

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_sync_outlined, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mutation.entityLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((mutation.lastErrorMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    mutation.lastErrorMessage!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: status,
                backgroundColor: background,
                foregroundColor: color,
              ),
              if (mutation.isOutstanding) ...[
                const SizedBox(height: 4),
                TextButton(
                  key: Key(
                    'field-activity-retry-${mutation.idempotencyKey}',
                  ),
                  onPressed: busy ? null : onRetry,
                  child: const Text('Gửi lại'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

String _title(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => 'Báo cáo',
    FieldActivityKind.productTrial => 'Kết quả thử sản phẩm',
    FieldActivityKind.followup => 'Kế hoạch & Công việc',
  };
}

String _subtitle(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => 'Lịch sử báo cáo phiên từ hệ thống',
    FieldActivityKind.productTrial =>
      'Lịch sử thử sản phẩm và kết quả hậu kiểm',
    FieldActivityKind.followup =>
      'Dữ liệu phiên hiện tại và trạng thái gửi trên thiết bị',
  };
}

String _emptyMessage(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => 'Chưa có phiên đã chốt để xem báo cáo.',
    FieldActivityKind.productTrial => 'Chưa có kết quả thử sản phẩm.',
    FieldActivityKind.followup =>
      'Công việc tạo trong phiên đi tuyến sẽ hiển thị tại đây.',
  };
}

IconData _icon(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => Icons.assignment_outlined,
    FieldActivityKind.productTrial => Icons.science_outlined,
    FieldActivityKind.followup => Icons.task_alt_outlined,
  };
}

String _fieldCheckLabel(String status) {
  return switch (status) {
    'opportunity' => 'Cơ hội',
    'risk' => 'Rủi ro',
    _ => 'Bình thường',
  };
}

String _followupStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'done' => 'Đã xong',
    'doing' => 'Đang làm',
    'blocked' => 'Bị chặn',
    _ => 'Cần làm',
  };
}

String _skipReasonLabel(String? reason) {
  return switch ((reason ?? '').trim().toLowerCase()) {
    'closed' => 'Đóng cửa',
    'busy' => 'Khách bận',
    'no_demand' => 'Không nhu cầu',
    'price' => 'Chê giá',
    'competitor' => 'Đang dùng đối thủ',
    'stock_enough' => 'Còn tồn hàng',
    'other' => 'Lý do khác',
    _ => 'Đã bỏ qua trong phiên',
  };
}

String _dateLabel(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) return '';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '${day}/${month}/${parsed.year}';
}
