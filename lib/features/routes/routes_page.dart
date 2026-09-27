import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
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
            subtitle: 'Theo dõi công việc theo tuyến',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa có dữ liệu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Thông tin tuyến sẽ hiển thị sau khi đồng bộ.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
