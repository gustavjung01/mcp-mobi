import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class FixedRoutesPage extends StatefulWidget {
  const FixedRoutesPage({
    required this.routes,
    super.key,
    this.initialRoute,
    this.dataClient,
  });

  final List<FieldRoute> routes;
  final FieldRoute? initialRoute;
  final FieldDataClient? dataClient;

  @override
  State<FixedRoutesPage> createState() => _FixedRoutesPageState();
}

class _FixedRoutesPageState extends State<FixedRoutesPage> {
  late List<FieldRoute> _routes;
  FieldRoute? _selectedRoute;
  FieldRouteWorkspace? _workspace;
  bool _loading = false;
  String? _message;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _routes = List<FieldRoute>.from(widget.routes);
    _selectedRoute = _initialRoute();
    if (_selectedRoute != null) {
      Future<void>.microtask(() => _loadWorkspace(_selectedRoute!));
    }
  }

  FieldRoute? _initialRoute() {
    final initialId = widget.initialRoute?.id;
    if (initialId != null) {
      for (final route in _routes) {
        if (route.id == initialId) return route;
      }
    }
    return _routes.isEmpty ? null : _routes.first;
  }

  Future<void> _loadWorkspace(FieldRoute route) async {
    final client = widget.dataClient;
    setState(() {
      _selectedRoute = route;
      _loading = client != null;
      _message = null;
      _workspace = null;
      _query = '';
    });
    if (client == null) return;

    try {
      final workspace = await client.loadRouteWorkspace(
        route: route,
        date: DateTime.now(),
      );
      if (!mounted || _selectedRoute?.id != route.id) return;
      setState(() {
        _workspace = workspace;
        _loading = false;
      });
    } on FieldDataFailure catch (error) {
      if (!mounted || _selectedRoute?.id != route.id) return;
      setState(() {
        _loading = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted || _selectedRoute?.id != route.id) return;
      setState(() {
        _loading = false;
        _message = 'Không tải được dữ liệu tuyến. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _refresh() async {
    final client = widget.dataClient;
    if (client == null) return;

    try {
      final routes = await client.loadRoutes();
      if (!mounted) return;
      final currentId = _selectedRoute?.id;
      FieldRoute? selected;
      for (final route in routes) {
        if (route.id == currentId) {
          selected = route;
          break;
        }
      }
      selected ??= routes.isEmpty ? null : routes.first;
      setState(() {
        _routes = routes;
        _selectedRoute = selected;
      });
      if (selected != null) {
        await _loadWorkspace(selected);
      } else {
        setState(() {
          _workspace = null;
          _message = null;
        });
      }
    } on FieldDataFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
      });
    }
  }

  Future<void> _showRoutePicker() async {
    if (_routes.isEmpty) return;
    final route = await showModalBottomSheet<FieldRoute>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          shrinkWrap: true,
          itemCount: _routes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final route = _routes[index];
            return ListTile(
              key: Key('fixed-route-choice-${route.id}'),
              leading: const Icon(Icons.route_outlined),
              title: Text(route.name),
              subtitle: Text(route.area),
              trailing: route.id == _selectedRoute?.id
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(route),
            );
          },
        ),
      ),
    );
    if (route != null) await _loadWorkspace(route);
  }

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final customers = _workspace?.customers ?? const <FieldRouteCustomer>[];
    final normalized = _query.trim().toLowerCase();
    final visibleCustomers = customers
        .where((customer) {
          if (normalized.isEmpty) return true;
          return customer.accountName.toLowerCase().contains(normalized) ||
              customer.area.toLowerCase().contains(normalized) ||
              customer.accountId.toLowerCase().contains(normalized) ||
              customer.note.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if ((_message ?? '').isNotEmpty) ...[
          if (_loading) const SizedBox(height: AppSpacing.sm),
          _RouteNotice(message: _message!),
          const SizedBox(height: AppSpacing.md),
        ],
        if (route == null)
          const AppCard(
            child: EmptyState(
              icon: Icons.route_outlined,
              title: 'Chưa có tuyến cố định',
              message: 'Công Ty chưa phân công tuyến cho tài khoản này.',
            ),
          )
        else ...[
          _RouteSummaryCard(
            route: route,
            onChangeRoute: _routes.length > 1 ? _showRoutePicker : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách điểm bán',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${customers.length} điểm',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('fixed-route-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Tìm điểm bán trong tuyến...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading && customers.isEmpty)
            const SizedBox.shrink()
          else if (customers.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Tuyến chưa có điểm bán',
                message: 'Danh sách điểm bán cố định hiện đang trống.',
              ),
            )
          else if (visibleCustomers.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy điểm bán',
                message: 'Thử đổi từ khóa tìm kiếm.',
              ),
            )
          else
            ...visibleCustomers.map(
              (customer) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FixedCustomerCard(customer: customer),
              ),
            ),
        ],
      ],
    );

    return Scaffold(
      key: const Key('fixed-routes-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Tuyến cố định',
            subtitle: 'Tuyến và điểm bán được Công Ty phân công',
            leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.route,
    this.onChangeRoute,
  });

  final FieldRoute route;
  final VoidCallback? onChangeRoute;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      route.area,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onChangeRoute != null)
                TextButton.icon(
                  key: const Key('fixed-route-change'),
                  onPressed: onChangeRoute,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Đổi tuyến'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Điểm tuyến',
                  value: route.plannedCustomers.toString(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  label: 'Đã ghé',
                  value: route.visitedCustomers.toString(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  label: 'Đơn hàng',
                  value: route.orderCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: 'Phụ trách',
            value: route.salesOwner.isEmpty
                ? 'Chưa phân công'
                : route.salesOwner,
          ),
          _InfoRow(
            label: 'Lần ghé gần nhất',
            value: _displayDate(route.lastVisitDate),
          ),
          _InfoRow(
            label: 'Trạng thái',
            value: _routeStatusLabel(route.status),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _FixedCustomerCard extends StatelessWidget {
  const _FixedCustomerCard({required this.customer});

  final FieldRouteCustomer customer;

  @override
  Widget build(BuildContext context) {
    final gps = customer.gps;
    return AppCard(
      key: Key('fixed-route-customer-${customer.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              customer.sortOrder > 0 ? customer.sortOrder.toString() : '•',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  customer.area,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (customer.contactName.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Liên hệ: ${customer.contactName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  gps == null
                      ? 'Vị trí: Chưa định vị'
                      : 'Vị trí: ${gps.lat.toStringAsFixed(5)}, ${gps.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if ((gps?.updatedAt ?? '').trim().isNotEmpty)
                  Text(
                    'Cập nhật vị trí: ${_displayDate(gps!.updatedAt!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                if (customer.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ghi chú: ${customer.note}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _customerStatusLabel(customer.status),
            style: TextStyle(
              color: customer.status == 'needs_gps'
                  ? AppColors.warning
                  : AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteNotice extends StatelessWidget {
  const _RouteNotice({required this.message});

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

String _routeStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'active' => 'Đang chạy',
    'watch' => 'Theo dõi',
    'paused' => 'Tạm dừng',
    _ => 'Đang chạy',
  };
}

String _customerStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'needs_gps' => 'Cần định vị',
    'hidden' => 'Đang ẩn',
    _ => 'Đang trong tuyến',
  };
}

String _displayDate(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized == '-') return 'Chưa có';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}
