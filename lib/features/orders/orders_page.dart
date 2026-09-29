import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/sync/order_offline_store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

enum _OrderPeriod {
  days7('7 ngày', 7),
  days30('30 ngày', 30),
  days90('90 ngày', 90),
  all('Tất cả', null);

  const _OrderPeriod(this.label, this.days);

  final String label;
  final int? days;
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    this.orderClient,
    this.offlineStore,
    this.companyCustomers = const [],
    this.onCreateOrder,
    this.onCustomerOnboarding,
    this.refreshToken = 0,
  });

  final OrderDataClient? orderClient;
  final OrderOfflineStore? offlineStore;
  final List<CompanyCustomer> companyCustomers;
  final Future<void> Function(CompanyCustomer customer)? onCreateOrder;
  final Future<void> Function()? onCustomerOnboarding;
  final int refreshToken;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _searchController = TextEditingController();
  List<FieldOrder> _orders = const [];
  List<QueuedOrderMutation> _pending = const [];
  _OrderPeriod _period = _OrderPeriod.days30;
  String _status = '';
  bool _loading = false;
  bool _syncing = false;
  bool _creating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAll());
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderClient != widget.orderClient ||
        oldWidget.offlineStore != widget.offlineStore ||
        oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_refreshAll());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll({bool syncPending = false}) async {
    if (syncPending) await _syncPending();
    await Future.wait([_loadPending(), _loadOrders()]);
  }

  Future<void> _loadPending() async {
    final store = widget.offlineStore;
    if (store == null) {
      if (mounted) setState(() => _pending = const []);
      return;
    }
    try {
      final pending = (await store.loadMutations())
          .where((item) => item.isOutstanding)
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _pending = pending);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Chưa đọc được các đơn đang chờ gửi.');
    }
  }

  Future<void> _syncPending({String? idempotencyKey}) async {
    final store = widget.offlineStore;
    final client = widget.orderClient;
    if (store == null || client == null || _syncing) return;

    setState(() => _syncing = true);
    try {
      await OrderSyncService(
        client: client,
        store: store,
      ).syncPending(idempotencyKey: idempotencyKey);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Chưa đồng bộ được đơn đang chờ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _retryQueued(String idempotencyKey) async {
    await _syncPending(idempotencyKey: idempotencyKey);
    await Future.wait([_loadPending(), _loadOrders()]);
  }

  Future<void> _loadOrders() async {
    final client = widget.orderClient;
    if (client == null) {
      if (mounted) {
        setState(() {
          _orders = const [];
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final orders = await client.loadOrders();
      if (!mounted) return;
      setState(() => _orders = orders);
    } on OrderDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _orders = const [];
        _message = failure.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CompanyCustomer> get _eligibleCustomers {
    final customers = widget.companyCustomers
        .where(
          (customer) =>
              customer.status.trim().toLowerCase() == 'active' &&
              (customer.defaultAddressId ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
    customers.sort(
      (left, right) => left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      ),
    );
    return customers;
  }

  Future<void> _startDirectOrder() async {
    final create = widget.onCreateOrder;
    if (create == null || _creating) return;

    final customers = _eligibleCustomers;
    if (customers.isEmpty) {
      final onboarding = widget.onCustomerOnboarding;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chưa có khách sẵn sàng ra đơn'),
          content: const Text(
            'Chưa có khách Công Ty đang hoạt động và có địa chỉ giao hàng trong phạm vi phụ trách. '
            'Nếu đây là điểm bán chưa có mã, hãy mở hoặc liên kết mã trước.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Đóng'),
            ),
            if (onboarding != null)
              FilledButton(
                key: const Key('orders-open-onboarding'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Mở / liên kết mã'),
              ),
          ],
        ),
      );
      if (open == true && onboarding != null) await onboarding();
      return;
    }

    final customer = await showModalBottomSheet<CompanyCustomer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _OrderCustomerPicker(customers: customers),
    );
    if (customer == null || !mounted) return;

    setState(() => _creating = true);
    try {
      await create(customer);
      if (mounted) await _refreshAll();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  DateTime? _orderDate(FieldOrder order) {
    final value = order.createdAt ?? order.currentVersion?.createdAt;
    return DateTime.tryParse(value ?? '')?.toLocal();
  }

  DateTime? get _latestOrderDate {
    DateTime? latest;
    for (final order in _orders) {
      final date = _orderDate(order);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    return latest;
  }

  bool _matchesPeriod(FieldOrder order) {
    final days = _period.days;
    final latest = _latestOrderDate;
    if (days == null || latest == null) return true;
    final date = _orderDate(order);
    if (date == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    final first = latest.subtract(Duration(days: days - 1));
    return !day.isBefore(first) && !day.isAfter(latest);
  }

  List<FieldOrder> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders
        .where((order) {
          if (!_matchesPeriod(order)) return false;
          if (_status.isNotEmpty && order.status != _status) return false;
          if (query.isEmpty) return true;
          return [
            order.number,
            order.customerCode,
            order.customerName,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
  }

  int get _todayCount {
    final now = DateTime.now();
    return _orders.where((order) {
      final created = _orderDate(order);
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
  }

  Future<void> _showOrderDetail(FieldOrder order) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _OrderDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    final statuses = _orders.map((order) => order.status).toSet().toList()
      ..sort();

    return Scaffold(
      key: const Key('orders-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Đơn hàng',
            subtitle: 'Đơn MCP thuộc phạm vi phụ trách',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onCreateOrder != null)
                  IconButton(
                    key: const Key('orders-create'),
                    tooltip: 'Tạo đơn hàng',
                    onPressed: _creating ? null : _startDirectOrder,
                    color: Colors.white,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                IconButton(
                  key: const Key('orders-refresh'),
                  onPressed: _loading || _syncing || widget.orderClient == null
                      ? null
                      : () => _refreshAll(syncPending: true),
                  color: Colors.white,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshAll(syncPending: true),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _OrderSummary(
                          value: _todayCount.toString(),
                          label: 'Hôm nay',
                          icon: Icons.today_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _OrderSummary(
                          value: _orders.length.toString(),
                          label: 'Đơn MCP',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Chờ đồng bộ',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._pending.map(
                      (mutation) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _QueuedOrderCard(
                          mutation: mutation,
                          syncing: _syncing,
                          onRetry: mutation.retryable
                              ? () => _retryQueued(mutation.idempotencyKey)
                              : null,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('orders-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã đơn hoặc khách hàng',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _OrderPeriod.values
                        .map(
                          (period) => ChoiceChip(
                            key: Key('orders-period-${period.name}'),
                            label: Text(period.label),
                            selected: _period == period,
                            onSelected: (_) => setState(() => _period = period),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const Key('orders-status-filter'),
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Tất cả trạng thái'),
                      ),
                      ...statuses.map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value ?? ''),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Text(
                        _message!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Center(child: CircularProgressIndicator()),
                  ] else if (orders.isEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Không có đơn phù hợp',
                        message:
                            'Thử đổi khoảng ngày, trạng thái hoặc từ khóa.',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Danh sách đơn',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${orders.length} đơn',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...orders.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: order,
                          onTap: () => _showOrderDetail(order),
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

class _OrderCustomerPicker extends StatefulWidget {
  const _OrderCustomerPicker({required this.customers});

  final List<CompanyCustomer> customers;

  @override
  State<_OrderCustomerPicker> createState() => _OrderCustomerPickerState();
}

class _OrderCustomerPickerState extends State<_OrderCustomerPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final customers = widget.customers
        .where(
          (customer) =>
              query.isEmpty ||
              customer.name.toLowerCase().contains(query) ||
              (customer.customerCode ?? '').toLowerCase().contains(query) ||
              (customer.phone ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chọn khách Công Ty',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              key: const Key('orders-customer-search'),
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Tìm tên, mã hoặc số điện thoại',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: customers.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy khách phù hợp.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: AppSpacing.xs,
                    ),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            key: Key('orders-customer-${customer.id}'),
                            leading: const CircleAvatar(
                              child: Icon(Icons.storefront_outlined),
                            ),
                            title: Text(
                              customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              [
                                    customer.customerCode,
                                    customer.defaultAddressLine1 ??
                                        customer.defaultAddressLabel,
                                  ]
                                  .whereType<String>()
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(customer),
                          ),
                        ),
                      );
                    },
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
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
        ],
      ),
    );
  }
}

class _QueuedOrderCard extends StatelessWidget {
  const _QueuedOrderCard({
    required this.mutation,
    required this.syncing,
    required this.onRetry,
  });

  final QueuedOrderMutation mutation;
  final bool syncing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mutation.outletName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${mutation.lines.length} dòng · ${_dateTimeLabel(mutation.createdAt.toIso8601String())}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if ((mutation.lastErrorMessage ?? '').isNotEmpty)
                  Text(
                    mutation.lastErrorMessage!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: syncing ? null : onRetry,
              child: const Text('Gửi lại'),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final FieldOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final version = order.currentVersion;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('order-row-${order.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.number ?? order.id,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerName ?? 'Khách Công Ty',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _dateTimeLabel(order.createdAt),
                        if ((order.currentVersionNumber ?? '').isNotEmpty)
                          'Phiên bản ${order.currentVersionNumber}',
                        if (version != null) '${version.lines.length} dòng',
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(order.total ?? version?.total),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final FieldOrder order;

  @override
  Widget build(BuildContext context) {
    final version = order.currentVersion;
    final lines = version?.lines ?? const <FieldOrderLine>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('order-detail-sheet'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết đơn hàng',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      order.number ?? order.id,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  label: 'Khách hàng',
                  value: order.customerName ?? 'Khách Công Ty',
                ),
                _DetailRow(
                  label: 'Ngày đơn',
                  value: _dateTimeLabel(order.createdAt),
                ),
                _DetailRow(
                  label: 'Phiên bản',
                  value: order.currentVersionNumber ?? '1',
                ),
                if ((order.sourceType ?? '').isNotEmpty)
                  _DetailRow(label: 'Nguồn đơn', value: order.sourceType!),
                if ((order.note ?? '').isNotEmpty)
                  _DetailRow(label: 'Ghi chú', value: order.note!),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sản phẩm',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${lines.length} dòng',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (lines.isEmpty)
            const AppCard(
              child: Text(
                'Đơn này chưa có chi tiết dòng hàng.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.itemName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ([line.sku, line.unitLabel, line.note]
                          .whereType<String>()
                          .where((value) => value.trim().isNotEmpty)
                          .isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [line.sku, line.unitLabel, line.note]
                              .whereType<String>()
                              .where((value) => value.trim().isNotEmpty)
                              .toSet()
                              .join(' · '),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_quantity(line.quantity)}${line.unitLabel.isEmpty ? '' : ' ${line.unitLabel}'} × ${_money(line.unitPrice)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            _money(line.lineTotal),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (version != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  _AmountRow(label: 'Tạm tính', value: version.subtotal),
                  if (version.discountTotal > 0)
                    _AmountRow(
                      label: 'Giảm giá',
                      value: -version.discountTotal,
                    ),
                  if (version.taxTotal > 0)
                    _AmountRow(label: 'Thuế', value: version.taxTotal),
                  const Divider(),
                  _AmountRow(
                    label: 'Tổng cộng',
                    value: version.total,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ],
          if (order.versions.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Lịch sử phiên bản',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...order.versions.reversed.map(
              (history) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _OrderVersionCard(
                  version: history,
                  current:
                      history.versionNumber == order.currentVersionNumber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderVersionCard extends StatelessWidget {
  const _OrderVersionCard({
    required this.version,
    required this.current,
  });

  final FieldOrderVersion version;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('order-version-${version.versionNumber}'),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        title: Text(
          'Phiên bản ${version.versionNumber}${current ? ' · Hiện tại' : ''}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          [
            _statusLabel(version.status),
            _dateTimeLabel(version.createdAt),
          ].where((value) => value.isNotEmpty).join(' · '),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        trailing: Text(
          _money(version.total),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          if (version.lines.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Phiên bản này chưa có chi tiết dòng hàng.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            )
          else
            ...version.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.itemName} · ${_quantity(line.quantity)}${line.unitLabel.isEmpty ? '' : ' ${line.unitLabel}'}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _money(line.lineTotal),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          _AmountRow(label: 'Tạm tính', value: version.subtotal),
          if (version.discountTotal > 0)
            _AmountRow(
              label: 'Giảm giá',
              value: -version.discountTotal,
            ),
          if (version.taxTotal > 0)
            _AmountRow(label: 'Thuế', value: version.taxTotal),
          _AmountRow(
            label: 'Tổng cộng',
            value: version.total,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'draft':
      return 'Nháp';
    case 'confirmed':
      return 'Đã chốt';
    case 'delivered':
      return 'Đã giao';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return status.isEmpty ? 'Chưa xác định' : status;
  }
}

String _dateTimeLabel(String? value) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _quantity(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\\.$'), '');
}

String _money(double? value) {
  if (value == null) return 'Công Ty xác định';
  final negative = value < 0;
  final rounded = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '${negative ? '-' : ''}${buffer.toString()} đ';
}
