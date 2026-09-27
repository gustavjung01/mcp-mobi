import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('routes-screen'),
      body: Column(
        children: [
          const NavyPageHeader(
            title: 'Đi tuyến',
            subtitle: 'Theo dõi tuyến và tiến độ ghé điểm bán',
            trailing: _HeaderStatus(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tuyến làm việc',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '0 / 0 điểm',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Chưa có tuyến được giao',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(
                        value: 0,
                        minHeight: 8,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppPrimaryButton(
                        label: 'Bắt đầu đi tuyến',
                        icon: Icons.play_arrow_rounded,
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  children: [
                    Expanded(
                      child: _ModeTab(
                        label: 'Danh sách',
                        icon: Icons.list_alt_rounded,
                        selected: true,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ModeTab(
                        label: 'Bản đồ',
                        icon: Icons.map_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Tìm điểm bán trong tuyến',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppCard(
                  child: EmptyState(
                    icon: Icons.route_outlined,
                    title: 'Chưa có điểm bán trong tuyến',
                    message: 'Danh sách sẽ hiển thị sau khi đồng bộ dữ liệu.',
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
