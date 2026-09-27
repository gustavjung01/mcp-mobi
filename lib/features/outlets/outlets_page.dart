import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class OutletsPage extends StatefulWidget {
  const OutletsPage({
    super.key,
    this.selectedRoute,
    this.workspace,
    this.loading = false,
    this.message,
    this.onOpenRoutes,
    this.onRefresh,
    this.onOpenOutlet,
  });

  final FieldRoute? selectedRoute;
  final FieldRouteWorkspace? workspace;
  final bool loading;
  final String? message;
  final VoidCallback? onOpenRoutes;
  final Future<void> Function()? onRefresh;
  final void Function(
    FieldRouteCustomer customer,
    FieldDayLine? line,
  )?
  onOpenOutlet;

  @override
  State<OutletsPage> createState() => _OutletsPageState();
}

class _OutletsPageState extends State<OutletsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers =
        widget.workspace?.customers ?? const <FieldRouteCustomer>[];
    final visible = customers
        .where((customer) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          return customer.accountName.toLowerCase().contains(query) ||
              customer.area.toLowerCase().contains(query) ||
              customer.accountId.toLowerCase().contains(query);
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
        if (widget.selectedRoute == null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                const EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Chưa chọn tuyến',
                  message: 'Chọn tuyến làm việc để xem danh sách điểm bán.',
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onOpenRoutes,
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Chọn tuyến'),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          TextField(
            key: const Key('outlet-search-field'),
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên, mã hoặc khu vực...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusPill(
                label: '${visible.length} điểm',
                icon: Icons.storefront_outlined,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: StatusPill(
                  label: widget.selectedRoute!.area,
                  icon: Icons.place_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Không có điểm bán phù hợp',
                message: 'Thử đổi từ khóa tìm kiếm hoặc chọn tuyến khác.',
              ),
            )
          else
            ...visible.map(
              (customer) {
                final line = _lineForCustomer(widget.workspace, customer.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _OutletRow(
                    customer: customer,
                    line: line,
                    onTap: widget.onOpenOutlet == null
                        ? null
                        : () => widget.onOpenOutlet!(customer, line),
                  ),
                );
              },
            ),
        ],
      ],
    );

    return Scaffold(
      key: const Key('outlets-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Điểm bán',
            subtitle:
                widget.selectedRoute?.name ?? 'Tra cứu và mở hồ sơ điểm bán',
            trailing: widget.selectedRoute == null
                ? null
                : StatusPill(
                    label: '${customers.length} điểm',
                    backgroundColor: const Color(0x26FFFFFF),
                    foregroundColor: Colors.white,
                  ),
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
    required this.customer,
    required this.line,
    this.onTap,
  });

  final FieldRouteCustomer customer;
  final FieldDayLine? line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final checkedIn = line?.checkedIn == true;
    final visited = line?.status == 'visited';

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('outlet-row-${customer.id}'),
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
                  color: checkedIn
                      ? AppColors.successSoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  checkedIn
                      ? Icons.location_on_rounded
                      : Icons.storefront_outlined,
                  color: checkedIn ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.accountName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _customerSubtitle(customer, line),
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
              Icon(
                visited
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: visited ? AppColors.success : AppColors.primary,
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

FieldDayLine? _lineForCustomer(
  FieldRouteWorkspace? workspace,
  String customerId,
) {
  for (final line in workspace?.day.lines ?? const <FieldDayLine>[]) {
    if (line.routeCustomerId == customerId) return line;
  }
  return null;
}

String _customerSubtitle(
  FieldRouteCustomer customer,
  FieldDayLine? line,
) {
  final phone = (line?.phone ?? '').trim();
  final status = line?.checkedIn == true
      ? 'Đã check-in'
      : line?.status == 'visited'
      ? 'Đã ghé'
      : 'Chưa ghé';
  final parts = <String>[customer.area, status];
  if (phone.isNotEmpty) parts.add(phone);
  return parts.join(' · ');
}
