import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('today-screen'),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.xs),
          const ScreenHeader(
            title: 'Hôm nay',
            subtitle: 'Tổng quan công việc cần xử lý',
            trailing: StatusPill(
              label: 'Sẵn sàng',
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tuyến hôm nay',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '0 / 0 điểm',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(value: 0, minHeight: 8),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Chưa có tuyến được đồng bộ.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppPrimaryButton(
                  label: 'Bắt đầu đi tuyến',
                  icon: Icons.route_outlined,
                  onPressed: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Cần theo dõi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.receipt_long_outlined,
                  value: '0',
                  label: 'Đơn hàng',
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.assignment_outlined,
                  value: '0',
                  label: 'Báo cáo',
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.task_alt_outlined,
                  value: '0',
                  label: 'Công việc',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
