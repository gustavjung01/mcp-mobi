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
    this.onSelectRoute,
    this.onRefresh,
    this.onOpenOutlet,
  });

  final List<FieldRoute> routes;
  final FieldRoute? selectedRoute;
  final FieldRouteWorkspace? workspace;
  final bool loading;
  final String? message;
  final Future<void> Function(FieldRoute route)? onSelectRoute;
  final Future<void> Function()? onRefresh;
  final void Function(FieldDayLine line)? onOpenOutlet;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  String _query = '';

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
    final visibleLines = lines.where((line) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return line.accountName.toLowerCase().contains(query) ||
          line.area.toLowerCase().contains(query) ||
          (line.address ?? '').toLowerCase().contains(query);
    }).toList(growable: false);
    final visited = lines.where((line) => line.status == 'visited').length;
    final total = day?.sessionOpened == true
        ? lines.length
        : route?.plannedCustomers ?? 0;
    final progress =
        total > 0 ? (visited / total).clamp(0.0, 1.0).toDouble() : 0.0;

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
                        route.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$visited / $total điểm',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  route.area,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(999),
                  ),
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
                        onPressed: _showRoutePicker,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Đổi tuyến'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
          if (day?.sessionOpened != true)
            AppCard(
              child: EmptyState(
                icon: Icons.route_outlined,
                title: 'Chưa có phiên đi tuyến',
                message: total > 0
                    ? 'Tuyến có $total điểm bán. Phiên hôm nay chưa được mở.'
                    : 'Tuyến chưa có điểm bán để thực hiện.',
              ),
            )
          else if (visibleLines.isEmpty)
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
    );

    return Scaffold(
      key: const Key('routes-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: route?.name ?? 'Đi tuyến',
            subtitle: _formatVietnameseDate(DateTime.now()),
            trailing: route == null
                ? null
                : _HeaderStatus(label: _statusLabel(day)),
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
              key: Key('route-option-' + route.id),
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('route-line-' + line.id),
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
                  color: visited ? AppColors.successSoft : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  line.sortOrder > 0 ? line.sortOrder.toString() : '•',
                  style: TextStyle(
                    color: visited ? AppColors.success : AppColors.primary,
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
              Icon(
                visited
                    ? Icons.check_circle_rounded
                    : Icons.navigation_rounded,
                color: visited ? AppColors.success : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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

String _statusLabel(FieldDayData? day) {
  if (day?.sessionOpened != true) return 'Chưa bắt đầu';
  if (day!.run.status == 'done' || day.run.status == 'completed') {
    return 'Đã kết thúc';
  }
  if (day.run.status == 'cancelled') return 'Đã hủy';
  return 'Đang thực hiện';
}

String _lineSubtitle(FieldDayLine line) {
  final address = (line.address ?? '').trim();
  final place = address.isNotEmpty ? address : line.area;
  if (line.checkedIn) return '$place · Đã check-in';
  return '$place · ${line.status == 'visited' ? 'Đã ghé' : 'Chưa ghé'}';
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
