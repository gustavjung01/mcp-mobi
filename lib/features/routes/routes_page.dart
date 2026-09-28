import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({
    super.key,
    this.routes = const [],
    this.selectedRoute,
    this.workspace,
    this.loading = false,
    this.message,
    this.routeActionBusy = false,
    this.onSelectRoute,
    this.onRefresh,
    this.onOpenOutlet,
    this.onStartRoute,
    this.onFinishRoute,
    this.onAddCustomer,
  });

  final List<FieldRoute> routes;
  final FieldRoute? selectedRoute;
  final FieldRouteWorkspace? workspace;
  final bool loading;
  final String? message;
  final bool routeActionBusy;
  final Future<void> Function(FieldRoute route)? onSelectRoute;
  final Future<void> Function()? onRefresh;
  final void Function(FieldDayLine line)? onOpenOutlet;
  final Future<void> Function()? onStartRoute;
  final Future<void> Function()? onFinishRoute;
  final Future<void> Function()? onAddCustomer;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  String _query = '';
  String _filter = 'all';

  Future<void> _showRoutePicker() async {
    if (widget.routes.isEmpty || widget.onSelectRoute == null) return;
    final route = await showModalBottomSheet<FieldRoute>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            shrinkWrap: true,
            itemCount: widget.routes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = widget.routes[index];
              return ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(item.name),
                subtitle: Text(item.area),
                trailing: item.id == widget.selectedRoute?.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        );
      },
    );
    if (route != null) await widget.onSelectRoute!(route);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.selectedRoute;
    final day = widget.workspace?.day;
    final lines = day?.lines ?? const <FieldDayLine>[];
    final query = _query.trim().toLowerCase();
    final visibleLines = lines
        .where((line) {
          if (!_matchesSessionFilter(line, _filter)) return false;
          if (query.isEmpty) return true;
          return line.accountName.toLowerCase().contains(query) ||
              line.area.toLowerCase().contains(query) ||
              (line.address ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
    final visited = lines.where((line) => line.status == 'visited').length;
    final total = day?.sessionOpened == true
        ? lines.length
        : route?.plannedCustomers ?? 0;
    final progress = total > 0
        ? (visited / total).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final percent = total > 0 ? (progress * 100).round() : 0;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (widget.loading) const LinearProgressIndicator(minHeight: 2),
        if ((widget.message ?? '').isNotEmpty) ...[
          if (widget.loading) const SizedBox(height: AppSpacing.sm),
          _Notice(message: widget.message!),
        ],
        if (route == null) ...[
          if (widget.loading || (widget.message ?? '').isNotEmpty)
            const SizedBox(height: AppSpacing.md),
          _RouteSelectionCard(
            routes: widget.routes,
            onSelectRoute: widget.onSelectRoute,
          ),
        ] else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$visited/$total điểm đã ghé',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  color: AppColors.success,
                  backgroundColor: AppColors.successSoft,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    StatusPill(
                      label: _statusLabel(day),
                      icon: day?.sessionOpened == true
                          ? Icons.play_circle_outline_rounded
                          : Icons.schedule_rounded,
                      backgroundColor: day?.sessionOpened == true
                          ? AppColors.successSoft
                          : AppColors.primarySoft,
                      foregroundColor: day?.sessionOpened == true
                          ? AppColors.success
                          : AppColors.primaryDark,
                    ),
                    const Spacer(),
                    if (widget.routes.length > 1)
                      TextButton.icon(
                        onPressed: widget.routeActionBusy
                            ? null
                            : _showRoutePicker,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Đổi tuyến'),
                      ),
                  ],
                ),
                if (day?.sessionOpened != true) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('route-start-button'),
                      onPressed: widget.routeActionBusy
                          ? null
                          : widget.onStartRoute,
                      icon: widget.routeActionBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        widget.routeActionBusy
                            ? 'Đang bắt đầu...'
                            : 'Bắt đầu tuyến',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (day?.sessionOpened != true)
            _FixedRoutePreview(
              customers:
                  widget.workspace?.customers ?? const <FieldRouteCustomer>[],
              query: _query,
              onQueryChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Danh sách điểm bán',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${visibleLines.length} điểm trong phiên hôm nay',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canAddCustomer(day) && widget.onAddCustomer != null)
                  OutlinedButton.icon(
                    key: const Key('route-add-customer-button'),
                    onPressed: widget.routeActionBusy
                        ? null
                        : () => widget.onAddCustomer!(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Thêm khách'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _SessionFilterBar(
              lines: lines,
              selected: _filter,
              onSelected: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('route-outlet-search'),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Tìm điểm bán trong tuyến...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (visibleLines.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Không có điểm bán phù hợp',
                  message: 'Thử đổi từ khóa tìm kiếm.',
                ),
              )
            else
              ...visibleLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _VisitLineCard(
                    line: line,
                    onTap: widget.onOpenOutlet == null
                        ? null
                        : () => widget.onOpenOutlet!(line),
                  ),
                ),
              ),
          ],
        ],
      ],
    );

    return Scaffold(
      key: const Key('routes-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: route?.name ?? 'Đi tuyến',
            subtitle: route == null
                ? _formatVietnameseDate(DateTime.now())
                : '${_formatVietnameseDate(DateTime.now())} · ${route.area}',
            trailing: day?.sessionOpened == true
                ? _FinishButton(
                    busy: widget.routeActionBusy,
                    onPressed: widget.onFinishRoute,
                  )
                : null,
          ),
          Expanded(
            child: widget.onRefresh == null
                ? body
                : RefreshIndicator(
                    onRefresh: widget.onRefresh!,
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FixedRoutePreview extends StatelessWidget {
  const _FixedRoutePreview({
    required this.customers,
    required this.query,
    required this.onQueryChanged,
  });

  final List<FieldRouteCustomer> customers;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final visible = customers
        .where((customer) {
          if (normalized.isEmpty) return true;
          return customer.accountName.toLowerCase().contains(normalized) ||
              customer.area.toLowerCase().contains(normalized) ||
              customer.accountId.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Điểm bán cố định của tuyến',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${customers.length} điểm sẽ được đưa vào phiên khi bắt đầu tuyến.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('route-preview-search'),
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Tìm điểm bán cố định...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (customers.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.route_outlined,
              title: 'Tuyến chưa có điểm bán',
              message: 'Danh sách cố định của tuyến hiện đang trống.',
            ),
          )
        else if (visible.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Không có điểm bán phù hợp',
              message: 'Thử đổi từ khóa tìm kiếm.',
            ),
          )
        else
          ...visible.map(
            (customer) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  key: Key('route-preview-${customer.id}'),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      customer.sortOrder > 0
                          ? customer.sortOrder.toString()
                          : '•',
                    ),
                  ),
                  title: Text(
                    customer.accountName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    customer.area,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionFilterBar extends StatelessWidget {
  const _SessionFilterBar({
    required this.lines,
    required this.selected,
    required this.onSelected,
  });

  final List<FieldDayLine> lines;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = <(String, String)>[
      ('all', 'Tất cả'),
      ('pending', 'Chờ ghé'),
      ('visited', 'Đã ghé'),
      ('skipped', 'Bỏ qua'),
      ('added', 'Thêm mới'),
      ('followups', 'Có việc'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final count = lines
              .where((line) => _matchesSessionFilter(line, item.$1))
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              key: Key('route-filter-${item.$1}'),
              label: Text('${item.$2}  $count'),
              selected: selected == item.$1,
              onSelected: (_) => onSelected(item.$1),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton({
    required this.busy,
    this.onPressed,
  });

  final bool busy;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('route-finish-button'),
      onPressed: busy || onPressed == null ? null : () => onPressed!(),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: AppColors.danger,
        disabledBackgroundColor: const Color(0x66FFFFFF),
      ),
      child: Text(busy ? 'Đang lưu' : 'Kết thúc'),
    );
  }
}

class _RouteSelectionCard extends StatelessWidget {
  const _RouteSelectionCard({
    required this.routes,
    required this.onSelectRoute,
  });

  final List<FieldRoute> routes;
  final Future<void> Function(FieldRoute route)? onSelectRoute;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.route_outlined,
          title: 'Chưa có tuyến làm việc',
          message: 'Danh sách tuyến sẽ hiển thị khi hệ thống có dữ liệu.',
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn tuyến làm việc',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...routes.map(
            (route) => InkWell(
              key: Key('route-option-${route.id}'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onSelectRoute == null
                  ? null
                  : () {
                      onSelectRoute!(route);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.route_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${route.area} · ${route.plannedCustomers} điểm',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitLineCard extends StatelessWidget {
  const _VisitLineCard({
    required this.line,
    this.onTap,
  });

  final FieldDayLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visited = line.status == 'visited';
    final skipped = line.status == 'skipped';
    final statusColor = skipped
        ? AppColors.warning
        : visited
        ? AppColors.success
        : AppColors.primary;
    final statusSoft = skipped
        ? AppColors.warning.withValues(alpha: 0.12)
        : visited
        ? AppColors.successSoft
        : AppColors.primarySoft;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('route-line-${line.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  line.sortOrder > 0 ? line.sortOrder.toString() : '•',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.accountName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lineSubtitle(line),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  skipped
                      ? Icons.skip_next_rounded
                      : visited
                      ? Icons.check_rounded
                      : Icons.navigation_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _canAddCustomer(FieldDayData? day) {
  if (day?.sessionOpened != true) return false;
  final status = day!.run.status.trim().toLowerCase();
  return !const {'done', 'completed', 'cancelled', 'closed'}.contains(status);
}

String _statusLabel(FieldDayData? day) {
  if (day?.sessionOpened != true) return 'Chưa bắt đầu';
  if (day!.run.status == 'done' || day.run.status == 'completed') {
    return 'Đã kết thúc';
  }
  if (day.run.status == 'cancelled') return 'Đã hủy';
  return 'Đang thực hiện';
}

bool _matchesSessionFilter(FieldDayLine line, String filter) {
  return switch (filter) {
    'pending' => line.status == 'pending',
    'visited' => line.status == 'visited',
    'skipped' => line.status == 'skipped',
    'added' => line.source == 'added',
    'followups' => line.followupCount > 0,
    _ => true,
  };
}

String _lineSubtitle(FieldDayLine line) {
  final address = (line.address ?? '').trim();
  final place = address.isNotEmpty ? address : line.area;
  if (line.status == 'skipped') {
    final reason = _skipReasonLabel(line.statusReason);
    return reason.isEmpty
        ? '$place · Bỏ qua / không mua'
        : '$place · Bỏ qua / không mua · $reason';
  }
  if (line.checkedIn) return '$place · Đã check-in';
  final status = line.status == 'visited' ? 'Đã ghé' : 'Chờ ghé';
  final source = line.source == 'added' ? ' · Thêm mới' : '';
  final followup = line.followupCount > 0 ? ' · Có việc' : '';
  return '$place · $status$source$followup';
}

String _skipReasonLabel(String? value) {
  return switch ((value ?? '').trim()) {
    'closed' => 'Đóng cửa',
    'busy' => 'Khách bận',
    'no_demand' => 'Không nhu cầu',
    'price' => 'Chê giá',
    'competitor' => 'Đang dùng đối thủ',
    'stock_enough' => 'Còn tồn hàng',
    'other' => 'Khác',
    _ => (value ?? '').trim(),
  };
}

String _formatVietnameseDate(DateTime value) {
  const weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '${weekdays[value.weekday - 1]}, $day/$month/${value.year}';
}
