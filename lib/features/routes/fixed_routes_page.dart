import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/sync/route_management_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class FixedRoutesPage extends StatefulWidget {
  const FixedRoutesPage({
    required this.routes,
    super.key,
    this.initialRoute,
    this.dataClient,
    this.managementService,
    this.canManageRoutes = false,
    this.canManageCustomers = false,
  });

  final List<FieldRoute> routes;
  final FieldRoute? initialRoute;
  final FieldDataClient? dataClient;
  final RouteManagementSubmissionService? managementService;
  final bool canManageRoutes;
  final bool canManageCustomers;

  @override
  State<FixedRoutesPage> createState() => _FixedRoutesPageState();
}

class _FixedRoutesPageState extends State<FixedRoutesPage> {
  late List<FieldRoute> _routes;
  FieldRoute? _selectedRoute;
  FieldRouteWorkspace? _workspace;
  bool _loading = false;
  bool _busy = false;
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
    }
  }

  Future<void> _refresh({String? selectRouteId}) async {
    final client = widget.dataClient;
    if (client == null) return;
    setState(() => _loading = true);
    try {
      final routes = await client.loadRoutes();
      if (!mounted) return;
      final currentId = selectRouteId ?? _selectedRoute?.id;
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
        _loading = selected != null;
      });
      if (selected != null) {
        await _loadWorkspace(selected);
      } else if (mounted) {
        setState(() {
          _workspace = null;
          _loading = false;
          _message = null;
        });
      }
    } on FieldDataFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
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

  Future<void> _createRoute() async {
    final service = widget.managementService;
    if (!widget.canManageRoutes || service == null || _busy) return;
    final input = await _showRouteForm(context);
    if (input == null || !mounted) return;
    await _runManagement(
      () => service.createRoute(
        routeName: input.name,
        area: input.area,
        weekday: input.weekday,
        note: input.note,
      ),
      success: 'Đã tạo tuyến.',
      queued: 'Đã lưu tuyến chờ gửi.',
      refreshRoutes: true,
    );
  }

  Future<void> _editRoute(FieldRoute route) async {
    final service = widget.managementService;
    if (!widget.canManageRoutes || service == null || _busy) return;
    final input = await _showRouteForm(context, route: route);
    if (input == null || !mounted) return;
    await _runManagement(
      () => service.updateRoute(
        routeId: route.id,
        routeName: input.name,
        area: input.area,
        weekday: input.weekday,
        note: input.note,
      ),
      success: 'Đã cập nhật tuyến.',
      queued: 'Đã lưu thay đổi tuyến chờ gửi.',
      refreshRoutes: true,
      selectRouteId: route.id,
    );
  }

  Future<void> _archiveRoute(FieldRoute route) async {
    final service = widget.managementService;
    if (!widget.canManageRoutes || service == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngừng sử dụng tuyến?'),
        content: Text(
          'Tuyến “${route.name}” sẽ không còn dùng cho phiên mới. Dữ liệu cũ vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ngừng sử dụng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runManagement(
      () => service.archiveRoute(
        routeId: route.id,
        routeName: route.name,
      ),
      success: 'Đã ngừng sử dụng tuyến.',
      queued: 'Đã lưu yêu cầu ngừng tuyến chờ gửi.',
      refreshRoutes: true,
    );
  }

  Future<void> _addCustomer(FieldRoute route) async {
    final service = widget.managementService;
    if (!widget.canManageCustomers || service == null || _busy) return;
    final input = await _showCustomerForm(context);
    if (input == null || !mounted) return;
    final activeDay = _workspace?.day;
    final includeActive =
        activeDay?.sessionOpened == true &&
        _isActiveStatus(activeDay!.run.status);
    await _runManagement(
      () => service.addRouteCustomer(
        routeId: route.id,
        customerName: input.name,
        phone: input.phone,
        area: input.area,
        address: input.address,
        sortOrder: input.sortOrder,
        note: input.note,
        includeActiveSession: includeActive,
        activeSessionId: includeActive ? activeDay.run.id : null,
      ),
      success: includeActive
          ? 'Đã thêm điểm bán vào tuyến và phiên đang đi.'
          : 'Đã thêm điểm bán vào tuyến.',
      queued: 'Đã lưu điểm bán chờ gửi.',
      refreshWorkspace: true,
    );
  }

  Future<void> _editCustomer(FieldRouteCustomer customer) async {
    final service = widget.managementService;
    if (!widget.canManageCustomers || service == null || _busy) return;
    final input = await _showCustomerForm(context, customer: customer);
    if (input == null || !mounted) return;
    await _runManagement(
      () => service.updateRouteCustomer(
        routeCustomerId: customer.id,
        customerName: input.name,
        phone: input.phone,
        area: input.area,
        address: input.address,
        sortOrder: input.sortOrder,
        note: input.note,
      ),
      success: 'Đã cập nhật điểm bán.',
      queued: 'Đã lưu thay đổi điểm bán chờ gửi.',
      refreshWorkspace: true,
    );
  }

  Future<void> _archiveCustomer(FieldRouteCustomer customer) async {
    final service = widget.managementService;
    if (!widget.canManageCustomers || service == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loại khỏi tuyến cố định?'),
        content: Text(
          '“${customer.accountName}” sẽ được loại khỏi danh sách tuyến cố định. Lịch sử cũ vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Loại khỏi tuyến'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runManagement(
      () => service.archiveRouteCustomer(
        routeCustomerId: customer.id,
        customerName: customer.accountName,
      ),
      success: 'Đã loại điểm bán khỏi tuyến.',
      queued: 'Đã lưu yêu cầu loại điểm bán chờ gửi.',
      refreshWorkspace: true,
    );
  }

  Future<void> _runManagement(
    Future<RouteManagementSubmitStatus> Function() action, {
    required String success,
    required String queued,
    bool refreshRoutes = false,
    bool refreshWorkspace = false,
    String? selectRouteId,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _message = result == RouteManagementSubmitStatus.completed
            ? success
            : queued;
      });
      if (result == RouteManagementSubmitStatus.completed) {
        if (refreshRoutes) {
          await _refresh(selectRouteId: selectRouteId);
        } else if (refreshWorkspace && _selectedRoute != null) {
          await _loadWorkspace(_selectedRoute!);
        }
      }
    } on FieldDataFailure catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final customers = _workspace?.customers ?? const <FieldRouteCustomer>[];
    final normalized = _query.trim().toLowerCase();
    final visibleCustomers = customers.where((customer) {
      if (normalized.isEmpty) return true;
      return customer.accountName.toLowerCase().contains(normalized) ||
          customer.area.toLowerCase().contains(normalized) ||
          customer.phone.toLowerCase().contains(normalized) ||
          customer.address.toLowerCase().contains(normalized) ||
          customer.accountId.toLowerCase().contains(normalized);
    }).toList(growable: false);

    return Scaffold(
      key: const Key('fixed-routes-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Tuyến cố định',
            subtitle: widget.canManageRoutes || widget.canManageCustomers
                ? 'Quản lý tuyến và điểm bán theo quyền được cấp'
                : 'Tuyến và điểm bán được Công Ty phân công',
            leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: widget.canManageRoutes
                ? IconButton(
                    key: const Key('fixed-route-create'),
                    tooltip: 'Thêm tuyến',
                    onPressed: _busy ? null : _createRoute,
                    icon: const Icon(Icons.add_rounded),
                  )
                : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  if (_loading || _busy)
                    const LinearProgressIndicator(minHeight: 2),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Notice(message: _message!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (route == null)
                    AppCard(
                      child: EmptyState(
                        icon: Icons.route_outlined,
                        title: 'Chưa có tuyến cố định',
                        message: widget.canManageRoutes
                            ? 'Bấm dấu + để tạo tuyến đầu tiên.'
                            : 'Công Ty chưa phân công tuyến cho tài khoản này.',
                      ),
                    )
                  else ...[
                    _RouteSummaryCard(
                      route: route,
                      onChangeRoute:
                          _routes.length > 1 ? _showRoutePicker : null,
                      onEdit:
                          widget.canManageRoutes ? () => _editRoute(route) : null,
                      onArchive: widget.canManageRoutes
                          ? () => _archiveRoute(route)
                          : null,
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
                        if (widget.canManageCustomers)
                          TextButton.icon(
                            key: const Key('fixed-route-add-customer'),
                            onPressed: _busy ? null : () => _addCustomer(route),
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Thêm'),
                          )
                        else
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
                    if (!_loading && customers.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Tuyến chưa có điểm bán',
                          message: 'Danh sách điểm bán cố định hiện đang trống.',
                        ),
                      )
                    else if (visibleCustomers.isEmpty && customers.isNotEmpty)
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
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CustomerCard(
                            customer: customer,
                            canManage: widget.canManageCustomers,
                            onEdit: () => _editCustomer(customer),
                            onArchive: () => _archiveCustomer(customer),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
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
    this.onEdit,
    this.onArchive,
  });

  final FieldRoute route;
  final VoidCallback? onChangeRoute;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onArchive != null)
                PopupMenuButton<String>(
                  key: const Key('fixed-route-actions'),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'archive') onArchive?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Chỉnh sửa tuyến'),
                      ),
                    if (onArchive != null)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Ngừng sử dụng tuyến'),
                      ),
                  ],
                ),
            ],
          ),
          if (onChangeRoute != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const Key('fixed-route-change'),
              onPressed: onChangeRoute,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Đổi tuyến'),
            ),
          ],
          const Divider(height: 24),
          _InfoRow(label: 'Điểm tuyến', value: route.plannedCustomers.toString()),
          _InfoRow(
            label: 'Ngày cố định',
            value: _weekdayLabel(route.weekday),
          ),
          _InfoRow(
            label: 'Ghi chú',
            value: route.note.isEmpty ? 'Không có' : route.note,
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.canManage,
    required this.onEdit,
    required this.onArchive,
  });

  final FieldRouteCustomer customer;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('fixed-route-customer-${customer.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primaryDark,
            child: Text(customer.sortOrder > 0
                ? customer.sortOrder.toString()
                : '•'),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    customer.area,
                    if (customer.phone.isNotEmpty) customer.phone,
                    if (customer.address.isNotEmpty) customer.address,
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              key: Key('fixed-route-customer-actions-${customer.id}'),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'archive') onArchive();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Chỉnh sửa điểm bán'),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text('Loại khỏi tuyến'),
                ),
              ],
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
          const Icon(Icons.info_outline_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
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
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
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

class _RouteFormInput {
  const _RouteFormInput({
    required this.name,
    required this.area,
    required this.weekday,
    required this.note,
  });

  final String name;
  final String area;
  final int? weekday;
  final String note;
}

Future<_RouteFormInput?> _showRouteForm(
  BuildContext context, {
  FieldRoute? route,
}) {
  final name = TextEditingController(text: route?.name ?? '');
  final area = TextEditingController(text: route?.area ?? '');
  final note = TextEditingController(text: route?.note ?? '');
  int? weekday = route?.weekday;
  return showDialog<_RouteFormInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(route == null ? 'Thêm tuyến cố định' : 'Chỉnh sửa tuyến'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('route-form-name'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên tuyến *'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: area,
                decoration: const InputDecoration(labelText: 'Khu vực'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int?>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Ngày cố định'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Không cố định')),
                  DropdownMenuItem(value: 1, child: Text('Thứ Hai')),
                  DropdownMenuItem(value: 2, child: Text('Thứ Ba')),
                  DropdownMenuItem(value: 3, child: Text('Thứ Tư')),
                  DropdownMenuItem(value: 4, child: Text('Thứ Năm')),
                  DropdownMenuItem(value: 5, child: Text('Thứ Sáu')),
                  DropdownMenuItem(value: 6, child: Text('Thứ Bảy')),
                  DropdownMenuItem(value: 0, child: Text('Chủ Nhật')),
                ],
                onChanged: (value) => setState(() => weekday = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.of(context).pop(
                _RouteFormInput(
                  name: name.text.trim(),
                  area: area.text.trim(),
                  weekday: weekday,
                  note: note.text.trim(),
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}

class _CustomerFormInput {
  const _CustomerFormInput({
    required this.name,
    required this.phone,
    required this.area,
    required this.address,
    required this.sortOrder,
    required this.note,
  });

  final String name;
  final String phone;
  final String area;
  final String address;
  final int sortOrder;
  final String note;
}

Future<_CustomerFormInput?> _showCustomerForm(
  BuildContext context, {
  FieldRouteCustomer? customer,
}) {
  final name = TextEditingController(text: customer?.accountName ?? '');
  final phone = TextEditingController(text: customer?.phone ?? '');
  final area = TextEditingController(text: customer?.area ?? '');
  final address = TextEditingController(text: customer?.address ?? '');
  final sortOrder = TextEditingController(
    text: customer == null || customer.sortOrder <= 0
        ? ''
        : customer.sortOrder.toString(),
  );
  final note = TextEditingController(text: customer?.note ?? '');
  return showDialog<_CustomerFormInput>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(customer == null ? 'Thêm điểm bán' : 'Chỉnh sửa điểm bán'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('route-customer-form-name'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên điểm bán *'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Điện thoại'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: area,
              decoration: const InputDecoration(labelText: 'Khu vực'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thứ tự ghé'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            final parsed = int.tryParse(sortOrder.text.trim()) ?? 0;
            if (parsed < 0) return;
            Navigator.of(context).pop(
              _CustomerFormInput(
                name: name.text.trim(),
                phone: phone.text.trim(),
                area: area.text.trim(),
                address: address.text.trim(),
                sortOrder: parsed,
                note: note.text.trim(),
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}

bool _isActiveStatus(String value) {
  return const {'active', 'opened', 'open', 'in_progress'}
      .contains(value.trim().toLowerCase());
}

String _weekdayLabel(int? weekday) {
  return switch (weekday) {
    0 => 'Chủ Nhật',
    1 => 'Thứ Hai',
    2 => 'Thứ Ba',
    3 => 'Thứ Tư',
    4 => 'Thứ Năm',
    5 => 'Thứ Sáu',
    6 => 'Thứ Bảy',
    _ => 'Không cố định',
  };
}
