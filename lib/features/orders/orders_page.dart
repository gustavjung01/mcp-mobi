import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('orders-screen'),
      body: Column(
        children: [
          const NavyPageHeader(
            title: 'Đơn hàng',
            subtitle: 'Theo dõi đơn đã tạo và trạng thái gửi',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                Row(
                  children: [
                    Expanded(
                      child: _OrderSummary(
                        value: '0',
                        label: 'Hôm nay',
                        icon: Icons.today_outlined,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _OrderSummary(
                        value: '0',
                        label: 'Chờ gửi',
                        icon: Icons.cloud_upload_outlined,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Tìm đơn hàng',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                AppCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có đơn hàng',
                    message:
                        'Đơn đã tạo sẽ hiển thị tại đây cùng trạng thái xử lý.',
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

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
