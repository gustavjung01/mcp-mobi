import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/screen_header.dart';

class OutletsPage extends StatelessWidget {
  const OutletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('outlets-screen'),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          SizedBox(height: AppSpacing.xs),
          ScreenHeader(
            title: 'Điểm bán',
            subtitle: 'Tra cứu và mở hồ sơ khách hàng',
          ),
          SizedBox(height: AppSpacing.xl),
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc mã khách hàng',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppCard(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Chưa có dữ liệu điểm bán',
              message: 'Danh sách sẽ hiển thị sau khi đồng bộ dữ liệu.',
            ),
          ),
        ],
      ),
    );
  }
}
