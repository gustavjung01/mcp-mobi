import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    this.displayName,
    this.onOpenRoutes,
    this.onOpenOutlets,
  });

  final String? displayName;
  final VoidCallback? onOpenRoutes;
  final VoidCallback? onOpenOutlets;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = (displayName ?? '').trim();

    return Scaffold(
      key: const Key('today-screen'),
      body: SafeArea(
        child: ListView(
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
            const SizedBox(height: AppSpacing.md),
            _TodayOverview(
              dateLabel: _formatVietnameseDate(now),
              onOpenRoutes: onOpenRoutes,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Đơn hàng',
                    value: '0',
                    helper: 'Chưa gửi 0',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryTile(
                    label: 'Báo cáo',
                    value: '0',
                    helper: 'Chưa gửi 0',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryTile(
                    label: 'Công việc',
                    value: '0',
                    helper: 'Cần theo dõi 0',
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chưa có điểm bán tiếp theo',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Danh sách sẽ cập nhật khi có tuyến làm việc.',
                            style: TextStyle(
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
            const AppCard(
              child: Column(
                children: [
                  _TaskRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Ghé các điểm còn lại',
                    value: '0',
                    color: AppColors.success,
                  ),
                  Divider(height: 22),
                  _TaskRow(
                    icon: Icons.assignment_outlined,
                    label: 'Hoàn thành báo cáo',
                    value: '0',
                    color: AppColors.primary,
                  ),
                  Divider(height: 22),
                  _TaskRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Gửi đơn hàng',
                    value: '0',
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ],
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: null,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const Positioned(
              right: 11,
              top: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 7, height: 7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({
    required this.dateLabel,
    required this.onOpenRoutes,
  });

  final String dateLabel;
  final VoidCallback? onOpenRoutes;

  @override
  Widget build(BuildContext context) {
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tuyến hôm nay',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Chưa có tuyến',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chưa bắt đầu',
                        style: TextStyle(
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
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: 0,
                              strokeWidth: 6,
                              backgroundColor: AppColors.border,
                            ),
                            Text(
                              '0/0',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tiến độ ghé',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Chưa có điểm',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
              label: const Text('Đi tuyến'),
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
  return weekdays[value.weekday - 1] +
      ', ' +
      day +
      '/' +
      month +
      '/' +
      value.year.toString();
}
