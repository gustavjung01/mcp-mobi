import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class CompanyCustomerDetailPage extends StatelessWidget {
  const CompanyCustomerDetailPage({
    required this.customer,
    super.key,
    this.onCreateOrder,
  });

  final CompanyCustomer customer;
  final Future<void> Function()? onCreateOrder;

  @override
  Widget build(BuildContext context) {
    final address = [
      customer.defaultAddressLabel,
      customer.defaultAddressLine1,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    final active = customer.status.trim().toLowerCase() == 'active';

    return Scaffold(
      key: const Key('company-customer-detail-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: customer.name,
            subtitle: (customer.customerCode ?? '').trim().isEmpty
                ? 'Khách Công Ty'
                : 'Mã ${customer.customerCode}',
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Trạng thái',
                        value: active ? 'Đang hoạt động' : customer.status,
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Điện thoại',
                        value: (customer.phone ?? '').trim().isEmpty
                            ? 'Chưa có'
                            : customer.phone!,
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Email',
                        value: (customer.email ?? '').trim().isEmpty
                            ? 'Chưa có'
                            : customer.email!,
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Địa chỉ giao hàng',
                        value: address.isEmpty ? 'Chưa có' : address,
                      ),
                    ],
                  ),
                ),
                if (onCreateOrder != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('company-customer-create-order'),
                      onPressed: active &&
                              (customer.defaultAddressId ?? '').trim().isNotEmpty
                          ? () => onCreateOrder!()
                          : null,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ra đơn hàng'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
