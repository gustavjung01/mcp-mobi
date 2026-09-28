import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_history_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    required this.client,
    super.key,
    this.now,
  });

  final FieldHistoryClient client;
  final DateTime? now;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _search = TextEditingController();
  List<FieldTaskItem> _items = const [];
  bool _loading = true;
  String? _message;
  String _status = 'all';
  String _priority = 'all';
  String _owner = 'all';
  String _due = 'all';

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final items = await widget.client.loadTasks();
      if (!mounted) return;
      setState(() => _items = items);
    } on FieldHistoryFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _owners {
    final owners = _items.map((item) => item.owner).toSet().toList()..sort();
    return owners;
  }

  List<FieldTaskItem> get _filtered {
    final search = _search.text.trim().toLowerCase();
    return _items
        .where((item) {
          if (_status != 'all' && item.status != _status) return false;
          if (_priority != 'all' && item.priority != _priority) return false;
          if (_owner != 'all' && item.owner != _owner) return false;
          if (_due == 'overdue' && !item.isOverdue(_now)) return false;
          if (_due == 'today' && !item.isDueToday(_now)) return false;
          if (_due == 'upcoming') {
            if (item.isOverdue(_now) || item.isDueToday(_now)) return false;
            if ((item.dueDate ?? '').isEmpty) return false;
          }
          if (_due == 'no_date' && (item.dueDate ?? '').isNotEmpty) {
            return false;
          }
          if (search.isEmpty) return true;
          final haystack = [
            item.title,
            item.customerName,
            item.routeName,
            item.owner,
            item.note ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(search);
        })
        .toList(growable: false);
  }

  void _openDetail(FieldTaskItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _TaskDetailSheet(item: item, now: _now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final overdue = _items.where((item) => item.isOverdue(_now)).length;
    final high = _items
        .where((item) => item.priority == 'high' || item.priority == 'urgent')
        .length;
    final open = _items.where((item) => item.status != 'done').length;

    return Scaffold(
      key: const Key('tasks-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Kế hoạch & Công việc',
            subtitle: 'Công việc thực tế từ các phiên',
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              key: const Key('tasks-refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Kpi(label: 'Cần xử lý', value: open),
                      _Kpi(label: 'Quá hạn', value: overdue),
                      _Kpi(label: 'Ưu tiên cao', value: high),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('tasks-search'),
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Tìm công việc',
                            hintText:
                                'Tên việc, điểm bán, tuyến, người phụ trách',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('tasks-status-filter'),
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'Trạng thái',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Tất cả'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'todo',
                                    child: Text('Cần làm'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'doing',
                                    child: Text('Đang làm'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'done',
                                    child: Text('Đã xong'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'blocked',
                                    child: Text('Bị chặn'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _status = value ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('tasks-priority-filter'),
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                  labelText: 'Ưu tiên',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Tất cả'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'urgent',
                                    child: Text('Khẩn'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'high',
                                    child: Text('Cao'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'medium',
                                    child: Text('Trung bình'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'low',
                                    child: Text('Thấp'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _priority = value ?? 'all'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('tasks-owner-filter'),
                                initialValue: _owner,
                                decoration: const InputDecoration(
                                  labelText: 'Phụ trách',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Tất cả'),
                                  ),
                                  ..._owners.map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _owner = value ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('tasks-due-filter'),
                                initialValue: _due,
                                decoration: const InputDecoration(
                                  labelText: 'Hạn xử lý',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Tất cả'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'overdue',
                                    child: Text('Quá hạn'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'today',
                                    child: Text('Hôm nay'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'upcoming',
                                    child: Text('Sắp tới'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'no_date',
                                    child: Text('Chưa có hạn'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _due = value ?? 'all'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Text(
                        _message!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.task_alt_outlined,
                        title: 'Chưa có công việc phù hợp',
                        message: 'Đổi bộ lọc hoặc kiểm tra lại dữ liệu phiên.',
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _TaskCard(
                          item: item,
                          now: _now,
                          onTap: () => _openDetail(item),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 20,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final FieldTaskItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue(now);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: Key('task-${item.id}'),
          onTap: onTap,
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          title: Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [item.customerName, item.routeName, item.owner].join(' · '),
                ),
                const SizedBox(height: 3),
                Text(
                  overdue
                      ? 'Quá hạn · ${_dateLabel(item.dueDate)}'
                      : "Hạn: ${_dateLabel(item.dueDate, empty: 'Chưa đặt')}",
                  style: TextStyle(
                    color: overdue ? AppColors.danger : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: overdue ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: _statusLabel(item.status),
                backgroundColor: _statusBackground(item.status),
                foregroundColor: _statusColor(item.status),
              ),
              const SizedBox(height: 4),
              Text(
                _priorityLabel(item.priority),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.item, required this.now});

  final FieldTaskItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(label: 'Điểm bán', value: item.customerName),
          _DetailLine(label: 'Tuyến', value: item.routeName),
          _DetailLine(
            label: 'Phiên phát sinh',
            value: _dateLabel(item.sessionDate, empty: 'Chưa xác định'),
          ),
          _DetailLine(label: 'Nguồn', value: _typeLabel(item.followupType)),
          _DetailLine(label: 'Phụ trách', value: item.owner),
          _DetailLine(label: 'Ưu tiên', value: _priorityLabel(item.priority)),
          _DetailLine(label: 'Trạng thái', value: _statusLabel(item.status)),
          _DetailLine(
            label: overdue ? 'Hạn xử lý · Quá hạn' : 'Hạn xử lý',
            value: _dateLabel(item.dueDate, empty: 'Chưa đặt'),
          ),
          if ((item.note ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Text(
                item.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String value) {
  return switch (value) {
    'doing' => 'Đang làm',
    'done' => 'Đã xong',
    'blocked' => 'Bị chặn',
    _ => 'Cần làm',
  };
}

Color _statusColor(String value) {
  return switch (value) {
    'doing' => AppColors.warning,
    'done' => AppColors.success,
    'blocked' => AppColors.danger,
    _ => AppColors.primary,
  };
}

Color _statusBackground(String value) {
  return switch (value) {
    'doing' => AppColors.warningSoft,
    'done' => AppColors.successSoft,
    'blocked' => AppColors.dangerSoft,
    _ => AppColors.primarySoft,
  };
}

String _priorityLabel(String value) {
  return switch (value) {
    'urgent' => 'Ưu tiên: Khẩn',
    'high' => 'Ưu tiên: Cao',
    'low' => 'Ưu tiên: Thấp',
    _ => 'Ưu tiên: Trung bình',
  };
}

String _typeLabel(String value) {
  return switch (value) {
    'order' => 'Đơn hàng',
    'test' => 'Sau khi thử sản phẩm',
    'report' => 'Báo cáo',
    'debt' => 'Công nợ',
    'delivery' => 'Giao hàng',
    _ => 'Theo dõi chung',
  };
}

String _dateLabel(String? value, {String empty = ''}) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) return empty;
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}
