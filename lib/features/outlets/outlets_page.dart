import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

enum _CustomerDirectoryTab {
  outlets,
  company,
}

class OutletsPage extends StatefulWidget {
  const OutletsPage({
    super.key,
    this.outlets = const [],
    this.companyCustomers = const [],
    this.loading = false,
    this.companyLoading = false,
    this.message,
    this.companyMessage,
    this.onRefresh,
    this.onOpenOutlet,
  });

  final List<FieldOutlet> outlets;
  final List<CompanyCustomer> companyCustomers;
  final bool loading;
  final bool companyLoading;
  final String? message;
  final String? companyMessage;
  final Future<void> Function()? onRefresh;
  final void Function(FieldOutlet outlet)? onOpenOutlet;

  @override
  State<OutletsPage> createState() => _OutletsPageState();
}

class _OutletsPageState extends State<OutletsPage> {
  String _query = '';
  _CustomerDirectoryTab _tab = _CustomerDirectoryTab.outlets;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleOutlets = widget.outlets
        .where((outlet) {
          if (query.isEmpty) return true;
          return outlet.name.toLowerCase().contains(query) ||
              outlet.code.toLowerCase().contains(query) ||
              outlet.phone.toLowerCase().contains(query) ||
              outlet.address.toLowerCase().contains(query) ||
              outlet.area.toLowerCase().contains(query) ||
              outlet.routeName.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final visibleCompany = widget.companyCustomers
        .where((customer) {
          if (query.isEmpty) return true;
          return [
            customer.name,
            customer.customerCode,
            customer.phone,
            customer.email,
            customer.defaultAddressLine1,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);

    final loading = _tab == _CustomerDirectoryTab.outlets
        ? widget.loading
        : widget.companyLoading;
    final message = _tab == _CustomerDirectoryTab.outlets
        ? widget.message
        : widget.companyMessage;

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if ((message ?? '').isNotEmpty) ...[
          if (loading) const SizedBox(height: AppSpacing.sm),
          _Notice(message: message!),
        ],
        Row(
          children: [
            Expanded(
              child: _DirectoryTabButton(
                key: const Key('outlet-tab-outlets'),
                label: 'Điểm bán',
                count: widget.outlets.length,
                selected: _tab == _CustomerDirectoryTab.outlets,
                onTap: () {
                  setState(() {
                    _tab = _CustomerDirectoryTab.outlets;
                  });
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DirectoryTabButton(
                key: const Key('outlet-tab-company'),
                label: 'Khách Công Ty',
                count: widget.companyCustomers.length,
                selected: _tab == _CustomerDirectoryTab.company,
                onTap: () {
                  setState(() {
                    _tab = _CustomerDirectoryTab.company;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('outlet-search-field'),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
          decoration: InputDecoration(
            hintText: _tab == _CustomerDirectoryTab.outlets
                ? 'Tìm tên, mã, điện thoại hoặc địa chỉ...'
                : 'Tìm khách Công Ty theo tên, mã hoặc điện thoại...',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_tab == _CustomerDirectoryTab.outlets) ...[
          Row(
            children: [
              StatusPill(
                label: '${visibleOutlets.length} điểm bán',
                icon: Icons.storefront_outlined,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Flexible(
                child: StatusPill(
                  label: 'Danh bạ được phân công',
                  icon: Icons.people_alt_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!loading && visibleOutlets.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Chưa có điểm bán',
                message: 'Các điểm bán được phân công cho tài khoản sẽ hiển thị tại đây.',
              ),
            )
          else
            ...visibleOutlets.map(
              (outlet) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _OutletRow(
                  outlet: outlet,
                  onTap: widget.onOpenOutlet == null
                      ? null
                      : () => widget.onOpenOutlet!(outlet),
                ),
              ),
            ),
        ] else ...[
          Row(
            children: [
              StatusPill(
                label: '${visibleCompany.length} khách',
                icon: Icons.verified_outlined,
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Flexible(
                child: StatusPill(
                  label: 'Đã thuộc phạm vi phụ trách',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!loading && visibleCompany.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.badge_outlined,
                title: 'Chưa có khách Công Ty',
                message: 'Khách đã mở hoặc liên kết và thuộc phạm vi phụ trách sẽ hiển thị tại đây.',
              ),
            )
          else
            ...visibleCompany.map(
              (customer) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CompanyCustomerCard(customer: customer),
              ),
            ),
        ],
      ],
    );

    return Scaffold(
      key: const Key('outlets-screen'),
      body: Column(
        children: [
          const NavyPageHeader(
            title: 'Điểm bán',
            subtitle: 'Điểm bán và khách Công Ty được phân công',
          ),
          Expanded(
            child: widget.onRefresh == null
                ? list
                : RefreshIndicator(
                    onRefresh: widget.onRefresh!,
                    child: list,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryTabButton extends StatelessWidget {
  const _DirectoryTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.primarySoft : AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 13,
        ),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _OutletRow extends StatelessWidget {
  const _OutletRow({
    required this.outlet,
    this.onTap,
  });

  final FieldOutlet outlet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final routeLine = [
      if (outlet.routeName.isNotEmpty) outlet.routeName,
      if (outlet.area.isNotEmpty) outlet.area,
    ].join(' · ');
    final contactLine = [
      if (outlet.code.isNotEmpty) outlet.code,
      if (outlet.phone.isNotEmpty) outlet.phone,
      if (outlet.address.isNotEmpty) outlet.address,
    ].join(' · ');

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('outlet-row-${outlet.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outlet.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (routeLine.isNotEmpty) ...[
                      Text(
                        routeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      contactLine.isEmpty
                          ? 'Chưa có thông tin liên hệ'
                          : contactLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyCustomerCard extends StatelessWidget {
  const _CompanyCustomerCard({required this.customer});

  final CompanyCustomer customer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('company-customer-${customer.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                (customer.customerCode ?? '').isEmpty
                    ? 'Đã liên kết'
                    : customer.customerCode!,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
                  customer.phone,
                  customer.defaultAddressLine1,
                ]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
