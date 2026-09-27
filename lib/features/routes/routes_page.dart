import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/screen_header.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('routes-screen'),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.xs),
          const ScreenHeader(
            title: 'Đi tuyến',
            subtitle: 'Theo dõi tuyến và tiến độ ghé điểm bán',
            trailing: StatusPill(
              label: 'Chưa bắt đầu',
              icon: Icons.schedule_outlined,
              backgroundColor: AppColors.warningSoft,
              foregroundColor: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuyến làm việc',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Chưa có tuyến được giao',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Tiến độ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '0 / 0 điểm',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
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
          const TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Tìm điểm bán trong tuyến',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              StatusPill(label: 'Tất cả'),
              SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: 'Chưa ghé',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: 'Đã ghé',
                backgroundColor: AppColors.successSoft,
                foregroundColor: AppColors.success,
              ),
            ],
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
    );
  }
}
