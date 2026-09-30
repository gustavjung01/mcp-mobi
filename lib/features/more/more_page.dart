import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/sync/sync_status.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../settings/settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.onFixedRoutes,
    this.onSessionHistory,
    this.onReports,
    this.onProductTrials,
    this.onReportSettings,
    this.onDataExports,
    this.onTasks,
    this.onManagementProposals,
    this.onCustomerOnboarding,
    this.onSettings,
    this.syncStatus = const AppSyncStatus.synced(),
    this.onRetrySync,
    this.onLogout,
  });

  final VoidCallback? onFixedRoutes;
  final VoidCallback? onSessionHistory;
  final VoidCallback? onReports;
  final VoidCallback? onProductTrials;
  final VoidCallback? onReportSettings;
  final VoidCallback? onDataExports;
  final VoidCallback? onTasks;
  final VoidCallback? onManagementProposals;
  final VoidCallback? onCustomerOnboarding;
  final VoidCallback? onSettings;
  final AppSyncStatus syncStatus;
  final VoidCallback? onRetrySync;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      if (onFixedRoutes != null)
        const _MoreItem(Icons.route_outlined, 'Tuyến cố định'),
      if (onSessionHistory != null)
        const _MoreItem(Icons.history, 'Lịch sử phiên'),
      if (onReports != null)
        const _MoreItem(Icons.assignment_outlined, 'Báo cáo'),
      if (onProductTrials != null)
        const _MoreItem(Icons.science_outlined, 'Kết quả thử sản phẩm'),
      if (onDataExports != null)
        const _MoreItem(Icons.file_download_outlined, 'Xuất dữ liệu'),
      if (onReportSettings != null)
        const _MoreItem(Icons.tune_rounded, 'Thiết lập báo cáo thị trường'),
      if (onTasks != null)
        const _MoreItem(Icons.task_alt_outlined, 'Kế hoạch & Công việc'),
      if (onManagementProposals != null)
        const _MoreItem(Icons.lightbulb_outline_rounded, 'Đề xuất'),
      if (onCustomerOnboarding != null)
        const _MoreItem(Icons.qr_code_scanner, 'Mở hoặc liên kết mã khách'),
      const _MoreItem(Icons.settings_outlined, 'Thiết lập'),
    ];

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
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            key: const Key('sync-status-card'),
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: syncStatus.canRetry ? onRetrySync : null,
                leading: _SyncStatusIcon(status: syncStatus),
                title: const Text('Đồng bộ dữ liệu'),
                subtitle: Text(syncStatus.message),
                trailing: syncStatus.canRetry && onRetrySync != null
                    ? IconButton(
                        key: const Key('sync-retry-button'),
                        tooltip: 'Đồng bộ lại',
                        onPressed: onRetrySync,
                        icon: const Icon(Icons.sync_rounded),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _MoreTile(
                    item: items[index],
                    onTap: switch (items[index].label) {
                      'Tuyến cố định' => onFixedRoutes,
                      'Lịch sử phiên' => onSessionHistory,
                      'Báo cáo' => onReports,
                      'Kết quả thử sản phẩm' => onProductTrials,
                      'Xuất dữ liệu' => onDataExports,
                      'Thiết lập báo cáo thị trường' => onReportSettings,
                      'Kế hoạch & Công việc' => onTasks,
                      'Đề xuất' => onManagementProposals,
                      'Mở hoặc liên kết mã khách' => onCustomerOnboarding,
                      'Thiết lập' => onSettings ?? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      _ => null,
                    },
                  ),
                  if (index < items.length - 1)
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

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.status});

  final AppSyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status.phase) {
      AppSyncPhase.syncing => const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      AppSyncPhase.waiting => const Icon(
          Icons.schedule_send_outlined,
          color: AppColors.textSecondary,
        ),
      AppSyncPhase.error => Icon(
          Icons.sync_problem_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
      AppSyncPhase.synced => const Icon(
          Icons.cloud_done_outlined,
          color: AppColors.primaryDark,
        ),
    };
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.item,
    this.onTap,
  });

  final _MoreItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: Key('more-${item.label}'),
        onTap: onTap,
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
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
