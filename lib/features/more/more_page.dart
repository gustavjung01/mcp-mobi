import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('more-screen'),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.xs),
          const ScreenHeader(
            title: 'Thêm',
            subtitle: 'Các chức năng khác',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreTile(
                  icon: Icons.assignment_outlined,
                  label: 'Báo cáo',
                ),
                const Divider(height: 1, indent: 64),
                _MoreTile(
                  icon: Icons.task_alt_outlined,
                  label: 'Công việc',
                ),
                const Divider(height: 1, indent: 64),
                _MoreTile(
                  icon: Icons.settings_outlined,
                  label: 'Thiết lập',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
    );
  }
}
