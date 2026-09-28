import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_history_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({
    required this.client,
    super.key,
    this.now,
  });

  final FieldHistoryClient client;
  final DateTime? now;

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<FieldSessionHistoryItem> _items = const [];
  bool _loading = true;
  String? _message;
  String _route = 'all';
  String _status = 'all';
  int _days = 45;

  DateTime get _now => widget.now ?? DateTime.now();

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
      final items = await widget.client.loadSessionHistory();
      if (!mounted) return;
      setState(() => _items = items);
    } on FieldHistoryFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _routes {
    final routes = _items.map((item) => item.routeName).toSet().toList()
      ..sort();
    return routes;
  }

  List<FieldSessionHistoryItem> get _filtered {
    final cutoff = DateTime(
      _now.year,
      _now.month,
      _now.day,
    ).subtract(Duration(days: _days - 1));

    return _items
        .where((item) {
          if (_route != 'all' && item.routeName != _route) return false;
          if (_status != 'all' && item.status != _status) return false;
          final date = DateTime.tryParse((item.sessionDate ?? '').trim());
          if (date != null && date.isBefore(cutoff)) return false;
          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      key: const Key('session-history-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Lịch sử phiên',
            subtitle: 'Tối đa 45 ngày gần nhất',
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              key: const Key('session-history-refresh'),
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
                  _FiltersCard(
                    routes: _routes,
                    route: _route,
                    status: _status,
                    days: _days,
                    onRouteChanged: (value) =>
                        setState(() => _route = value ?? 'all'),
                    onStatusChanged: (value) =>
                        setState(() => _status = value ?? 'all'),
                    onDaysChanged: (value) =>
                        setState(() => _days = value ?? 45),
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
                        icon: Icons.history_rounded,
                        title: 'Chưa có phiên phù hợp',
                        message: 'Đổi bộ lọc hoặc kiểm tra lại dữ liệu tuyến.',
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SessionCard(item: item),
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

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.routes,
    required this.route,
    required this.status,
    required this.days,
    required this.onRouteChanged,
    required this.onStatusChanged,
    required this.onDaysChanged,
  });

  final List<String> routes;
  final String route;
  final String status;
  final int days;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<int?> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: const Key('session-history-route-filter'),
            initialValue: route,
            decoration: const InputDecoration(labelText: 'Tuyến'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('Tất cả tuyến')),
              ...routes.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: onRouteChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('session-history-status-filter'),
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'active', child: Text('Đang đi')),
                    DropdownMenuItem(value: 'done', child: Text('Đã kết thúc')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Đã hủy')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('session-history-days-filter'),
                  initialValue: days,
                  decoration: const InputDecoration(labelText: 'Thời gian'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 ngày')),
                    DropdownMenuItem(value: 30, child: Text('30 ngày')),
                    DropdownMenuItem(value: 45, child: Text('45 ngày')),
                  ],
                  onChanged: onDaysChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item});

  final FieldSessionHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(item.status);
    final statusColor = item.status == 'active'
        ? AppColors.primary
        : item.status == 'cancelled'
        ? AppColors.danger
        : AppColors.success;

    return AppCard(
      key: Key('session-history-${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.routeName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(
                label: status,
                backgroundColor: item.status == 'active'
                    ? AppColors.primarySoft
                    : item.status == 'cancelled'
                    ? AppColors.dangerSoft
                    : AppColors.successSoft,
                foregroundColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              _dateLabel(item.sessionDate),
              item.salesOwner,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Metric(
                label: 'Đã ghé',
                value: '${item.visited}/${item.planned}',
              ),
              _Metric(label: 'Đơn', value: item.orders.toString()),
              _Metric(label: 'Thử SP', value: item.tests.toString()),
              _Metric(label: 'Báo cáo', value: item.reports.toString()),
              _Metric(label: 'Theo dõi', value: item.followups.toString()),
            ],
          ),
          if ((item.note ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
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
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
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

String _statusLabel(String value) {
  return switch (value) {
    'active' => 'Đang đi',
    'cancelled' => 'Đã hủy',
    _ => 'Đã kết thúc',
  };
}

String _dateLabel(String? value) {
  final parsed = DateTime.tryParse((value ?? '').trim());
  if (parsed == null) return (value ?? '').trim();
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}
