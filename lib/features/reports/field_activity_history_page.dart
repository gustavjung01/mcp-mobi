import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
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
    this.onSynchronized,
  });

  final FieldActivityKind kind;
  final List<FieldDayLine> lines;
  final MutationQueueStore queue;
  final FieldActivitySyncService syncService;
  final Future<void> Function()? onSynchronized;

  @override
  State<FieldActivityHistoryPage> createState() =>
      _FieldActivityHistoryPageState();
}

class _FieldActivityHistoryPageState extends State<FieldActivityHistoryPage> {
  List<QueuedMutation> _mutations = const [];
  bool _loading = true;
  bool _syncing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh(sync: true);
  }

  Future<void> _load() async {
    try {
      final rows = await widget.queue.load(
        operations: {widget.kind.operation},
      );
      if (!mounted) return;
      setState(() {
        _mutations = rows.reversed.toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Chưa đọc được dữ liệu đồng bộ trên thiết bị.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh({bool sync = false}) async {
    if (sync && !_syncing) {
      setState(() {
        _syncing = true;
      });
      try {
        final result = await widget.syncService.syncPending();
        if (result.sent > 0) {
          await widget.onSynchronized?.call();
        }
      } finally {
        if (mounted) {
          setState(() {
            _syncing = false;
          });
        }
      }
    }
    await _load();
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
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  List<FieldDayLine> get _serverLines {
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

  @override
  Widget build(BuildContext context) {
    final serverLines = _serverLines;
    return Scaffold(
      key: Key('field-activity-history-${widget.kind.name}'),
      body: Column(
        children: [
          NavyPageHeader(
            title: _title(widget.kind),
            subtitle: 'Dữ liệu phiên hiện tại và trạng thái đồng bộ trên máy',
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
                          color: AppColors.textSecondary,
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
                  else if (serverLines.isEmpty && _mutations.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: _icon(widget.kind),
                        title: 'Chưa có dữ liệu',
                        message: 'Nội dung tạo trong phiên đi tuyến sẽ hiển thị tại đây.',
                      ),
                    )
                  else ...[
                    if (serverLines.isNotEmpty) ...[
                      const _ListTitle('Phiên hiện tại'),
                      const SizedBox(height: AppSpacing.sm),
                      ...serverLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: _ServerActivityCard(
                            kind: widget.kind,
                            line: line,
                          ),
                        ),
                      ),
                    ],
                    if (_mutations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _ListTitle('Trạng thái gửi gần đây'),
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

class _ServerActivityCard extends StatelessWidget {
  const _ServerActivityCard({
    required this.kind,
    required this.line,
  });

  final FieldActivityKind kind;
  final FieldDayLine line;

  @override
  Widget build(BuildContext context) {
    final detail = switch (kind) {
      FieldActivityKind.report => 'Báo cáo đã ghi nhận trong phiên',
      FieldActivityKind.productTrial => 'Kết quả thử đã ghi nhận trong phiên',
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
            label: 'Đã đồng bộ',
            backgroundColor: AppColors.successSoft,
            foregroundColor: AppColors.success,
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

String _title(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => 'Báo cáo',
    FieldActivityKind.productTrial => 'Kết quả thử sản phẩm',
    FieldActivityKind.followup => 'Kế hoạch & Công việc',
  };
}

IconData _icon(FieldActivityKind kind) {
  return switch (kind) {
    FieldActivityKind.report => Icons.assignment_outlined,
    FieldActivityKind.productTrial => Icons.science_outlined,
    FieldActivityKind.followup => Icons.task_alt_outlined,
  };
}
