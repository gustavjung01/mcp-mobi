import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.onLogout,
  });

  final Future<void> Function()? onLogout;

  static const _items = <_MoreItem>[
    _MoreItem(Icons.history, 'Lịch sử phiên'),
    _MoreItem(Icons.assignment_outlined, 'Báo cáo'),
    _MoreItem(Icons.science_outlined, 'Kết quả thử sản phẩm'),
    _MoreItem(Icons.task_alt_outlined, 'Kế hoạch & Công việc'),
    _MoreItem(Icons.qr_code_scanner, 'Mở hoặc liên kết mã khách'),
    _MoreItem(Icons.settings_outlined, 'Thiết lập'),
  ];

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
            subtitle: 'Các nghiệp vụ và thiết lập khác',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < _items.length; index++) ...[
                  _MoreTile(item: _items[index]),
                  if (index < _items.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              ],
            ),
          ),
          if (onLogout != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: const Key('logout-button'),
              onPressed: () {
                onLogout!();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(item.icon, color: AppColors.primaryDark),
      title: Text(item.label, style: Theme.of(context).textTheme.titleMedium),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
