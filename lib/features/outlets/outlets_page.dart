import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class OutletsPage extends StatelessWidget {
  const OutletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('outlets-screen'),
      body: Column(
        children: [
          const NavyPageHeader(
            title: 'Điểm bán',
            subtitle: 'Tra cứu và mở hồ sơ điểm bán',
            trailing: StatusPill(
              label: '0 điểm',
              backgroundColor: Color(0x26FFFFFF),
              foregroundColor: Colors.white,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, mã hoặc số điện thoại...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      StatusPill(
                        label: 'Tất cả',
                        icon: Icons.storefront_outlined,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: 'Trong tuyến',
                        icon: Icons.route_outlined,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: 'Đã ghé',
                        icon: Icons.check_circle_outline_rounded,
                        backgroundColor: AppColors.successSoft,
                        foregroundColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppCard(
                  child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Chưa có dữ liệu điểm bán',
                    message:
                        'Danh sách điểm bán sẽ hiển thị sau khi dữ liệu được đồng bộ.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _ActionHint(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionHint extends StatelessWidget {
  const _ActionHint();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khi mở một điểm bán',
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
            children: const [
              _ActionChip(
                icon: Icons.location_on_outlined,
                label: 'Check-in',
                color: AppColors.success,
              ),
              _ActionChip(
                icon: Icons.receipt_long_outlined,
                label: 'Ra đơn hàng',
                color: AppColors.primary,
              ),
              _ActionChip(
                icon: Icons.assignment_outlined,
                label: 'Lập báo cáo',
                color: AppColors.warning,
              ),
              _ActionChip(
                icon: Icons.science_outlined,
                label: 'Thử sản phẩm',
                color: Color(0xFF7E57C2),
              ),
              _ActionChip(
                icon: Icons.task_alt_outlined,
                label: 'Việc cần theo dõi',
                color: AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
