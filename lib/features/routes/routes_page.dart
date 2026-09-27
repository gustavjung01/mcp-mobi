import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      key: const Key('routes-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Đi tuyến',
            subtitle: _formatVietnameseDate(now),
            trailing: const _HeaderStatus(),
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
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tuyến hôm nay',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '0 / 0 điểm',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Chưa có tuyến được giao',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(
                        value: 0,
                        minHeight: 7,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const StatusPill(
                            label: 'Chưa bắt đầu',
                            icon: Icons.schedule_rounded,
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 40,
                            child: FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                              ),
                              label: const Text('Bắt đầu'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _ViewSwitcher(),
                const SizedBox(height: AppSpacing.md),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm điểm bán trong tuyến...',
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
                        icon: Icons.list_alt_rounded,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: 'Chưa ghé',
                        icon: Icons.navigation_outlined,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: 'Đã ghé',
                        icon: Icons.check_circle_outline_rounded,
                        backgroundColor: AppColors.successSoft,
                        foregroundColor: AppColors.success,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: 'Cần chú ý',
                        icon: Icons.priority_high_rounded,
                        backgroundColor: AppColors.warningSoft,
                        foregroundColor: AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppCard(
                  child: EmptyState(
                    icon: Icons.route_outlined,
                    title: 'Chưa có điểm bán trong tuyến',
                    message: 'Khi tuyến được giao, danh sách điểm bán sẽ hiển thị tại đây.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Chưa bắt đầu',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          const Expanded(
            child: _ViewOption(
              label: 'Danh sách',
              icon: Icons.list_alt_rounded,
              selected: true,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: AppColors.border,
          ),
          const Expanded(
            child: _ViewOption(
              label: 'Bản đồ',
              icon: Icons.map_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewOption extends StatelessWidget {
  const _ViewOption({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
