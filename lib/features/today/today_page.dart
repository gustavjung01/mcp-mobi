import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    this.displayName,
    this.selectedRoute,
    this.workspace,
    this.loading = false,
    this.message,
    this.onOpenRoutes,
    this.onOpenOutlets,
    this.onRefresh,
  });

  final String? displayName;
  final FieldRoute? selectedRoute;
  final FieldRouteWorkspace? workspace;
  final bool loading;
  final String? message;
  final VoidCallback? onOpenRoutes;
  final VoidCallback? onOpenOutlets;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = (displayName ?? '').trim();
    final day = workspace?.day;
    final lines = day?.lines ?? const <FieldDayLine>[];
    final visited = lines.where((line) => line.status == 'visited').length;
    final total = day?.sessionOpened == true
        ? lines.length
        : selectedRoute?.plannedCustomers ?? 0;
    final orders = lines.where((line) => line.hasOrder).length;
    final reports = lines.where((line) => line.hasReport).length;
    final followups = lines.fold<int>(
      0,
      (sum, line) => sum + line.followupCount,
    );
    final nextLine = _nextPendingLine(lines);
    final nextCustomer = _nextCustomer(workspace, nextLine);
    final routeStatus = day?.sessionOpened == true
        ? _sessionStatusLabel(day!.run.status)
        : selectedRoute == null
        ? 'Chưa chọn tuyến'
        : 'Chưa mở phiên';

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _TodayHeader(
          greeting: _greetingFor(now),
          displayName: name.isEmpty ? 'Nhân viên thị trường' : name,
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if ((message ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Notice(message: message!),
        ],
        const SizedBox(height: AppSpacing.md),
        _TodayOverview(
          dateLabel: _formatVietnameseDate(now),
          routeName: selectedRoute?.name ?? 'Chưa chọn tuyến',
          routeStatus: routeStatus,
          visited: visited,
          total: total,
          onOpenRoutes: onOpenRoutes,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Đơn hàng',
                value: orders.toString(),
                helper: 'Trong phiên hôm nay',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryTile(
                label: 'Báo cáo',
                value: reports.toString(),
                helper: 'Đã ghi nhận',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryTile(
                label: 'Công việc',
                value: followups.toString(),
                helper: 'Cần theo dõi',
                helperColor: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          title: 'Điểm bán tiếp theo',
          actionLabel: 'Xem tất cả',
          onPressed: onOpenOutlets,
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          key: const Key('today-open-outlets-button'),
          onTap: onOpenOutlets,
          behavior: HitTestBehavior.opaque,
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextLine?.accountName ??
                            nextCustomer?.accountName ??
                            'Chưa có điểm bán tiếp theo',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nextLine != null
                            ? _outletSubline(nextLine.area, nextLine.address)
                            : nextCustomer != null
                            ? nextCustomer.area
                            : selectedRoute == null
                            ? 'Chọn tuyến để xem điểm bán.'
                            : 'Chưa có điểm bán cần xử lý.',
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
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Việc cần làm hôm nay'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              _TaskRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Ghé các điểm còn lại',
                value: (total - visited).clamp(0, total).toString(),
                color: AppColors.success,
              ),
              const Divider(height: 22),
              _TaskRow(
                icon: Icons.assignment_outlined,
                label: 'Báo cáo đã ghi nhận',
                value: reports.toString(),
                color: AppColors.primary,
              ),
              const Divider(height: 22),
              _TaskRow(
                icon: Icons.receipt_long_outlined,
                label: 'Đơn hàng đã ghi nhận',
                value: orders.toString(),
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      key: const Key('today-screen'),
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(
                onRefresh: onRefresh!,
                child: list,
              ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.greeting,
    required this.displayName,
  });

  final String greeting;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.primaryDark,
            size: 28,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const IconButton(
          onPressed: null,
          icon: Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({
    required this.dateLabel,
    required this.routeName,
    required this.routeStatus,
    required this.visited,
    required this.total,
    required this.onOpenRoutes,
  });

  final String dateLabel;
  final String routeName;
  final String routeStatus;
  final int visited;
  final int total;
  final VoidCallback? onOpenRoutes;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0
        ? (visited / total).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Text(
                'Hôm nay',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tuyến hôm nay',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        routeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        routeStatus,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: AppColors.border,
                            ),
                            Text(
                              '$visited/$total',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Tiến độ ghé',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('today-open-routes-button'),
              onPressed: onOpenRoutes,
              icon: const Icon(Icons.route_rounded, size: 18),
              label: Text(
                routeName == 'Chưa chọn tuyến' ? 'Chọn tuyến' : 'Đi tuyến',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.helper,
    this.helperColor = AppColors.textSecondary,
  });

  final String label;
  final String value;
  final String helper;
  final Color helperColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: helperColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
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

FieldDayLine? _nextPendingLine(List<FieldDayLine> lines) {
  for (final line in lines) {
    if (line.status == 'pending') return line;
  }
  return null;
}

FieldRouteCustomer? _nextCustomer(
  FieldRouteWorkspace? workspace,
  FieldDayLine? line,
) {
  if (line != null || workspace == null) return null;
  for (final customer in workspace.customers) {
    if (customer.status != 'hidden') return customer;
  }
  return null;
}

String _outletSubline(String area, String? address) {
  final value = (address ?? '').trim();
  return value.isNotEmpty ? value : area;
}

String _sessionStatusLabel(String status) {
  if (status == 'done' || status == 'completed') return 'Đã kết thúc';
  if (status == 'cancelled') return 'Đã hủy';
  return 'Đang thực hiện';
}

String _greetingFor(DateTime value) {
  if (value.hour < 11) return 'Chào buổi sáng';
  if (value.hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
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
