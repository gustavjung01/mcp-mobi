import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class OutletsPage extends StatefulWidget {
  const OutletsPage({
    super.key,
    this.outlets = const [],
    this.loading = false,
    this.message,
    this.onRefresh,
    this.onOpenOutlet,
  });

  final List<FieldOutlet> outlets;
  final bool loading;
  final String? message;
  final Future<void> Function()? onRefresh;
  final void Function(FieldOutlet outlet)? onOpenOutlet;

  @override
  State<OutletsPage> createState() => _OutletsPageState();
}

class _OutletsPageState extends State<OutletsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.outlets
        .where((outlet) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          return outlet.name.toLowerCase().contains(query) ||
              outlet.code.toLowerCase().contains(query) ||
              outlet.phone.toLowerCase().contains(query) ||
              outlet.address.toLowerCase().contains(query) ||
              outlet.area.toLowerCase().contains(query) ||
              outlet.routeName.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (widget.loading) const LinearProgressIndicator(minHeight: 2),
        if ((widget.message ?? '').isNotEmpty) ...[
          if (widget.loading) const SizedBox(height: AppSpacing.sm),
          _Notice(message: widget.message!),
        ],
        TextField(
          key: const Key('outlet-search-field'),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Tìm theo tên, mã, điện thoại hoặc địa chỉ...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            StatusPill(
              label: '${visible.length} điểm bán',
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
        if (!widget.loading && visible.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Chưa có điểm bán',
              message: 'Các điểm bán được phân công cho tài khoản sẽ hiển thị tại đây.',
            ),
          )
        else
          ...visible.map(
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
      ],
    );

    return Scaffold(
      key: const Key('outlets-screen'),
      body: Column(
        children: [
          const NavyPageHeader(
            title: 'Điểm bán',
            subtitle: 'Danh bạ điểm bán được phân công',
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

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
          ),
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
