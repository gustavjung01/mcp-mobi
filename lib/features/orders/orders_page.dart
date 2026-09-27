import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/order_data_client.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    this.orderClient,
    this.refreshToken = 0,
  });

  final OrderDataClient? orderClient;
  final int refreshToken;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _searchController = TextEditingController();
  List<FieldOrder> _orders = const [];
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderClient != widget.orderClient ||
        oldWidget.refreshToken != widget.refreshToken) {
      _loadOrders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final client = widget.orderClient;
    if (client == null) {
      setState(() {
        _orders = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final orders = await client.loadOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } on OrderDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _orders = const [];
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<FieldOrder> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _orders;
    return _orders.where((order) {
      return [
        order.number,
        order.customerCode,
        order.customerName,
      ].whereType<String>().any((value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  int get _todayCount {
    final now = DateTime.now();
    return _orders.where((order) {
      final created = DateTime.tryParse(order.createdAt ?? '')?.toLocal();
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return Scaffold(
      key: const Key('orders-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Đơn hàng',
            subtitle: 'Đơn MCP thuộc phạm vi phụ trách',
            trailing: IconButton(
              key: const Key('orders-refresh'),
              onPressed: _loading || widget.orderClient == null
                  ? null
                  : _loadOrders,
              color: Colors.white,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
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
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('orders-search'),
                    controller: _searchController,
                    enabled: !_loading,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo số đơn hoặc khách hàng',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (widget.orderClient == null)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Chưa kết nối dữ liệu đơn hàng',
                        message:
                            'Đăng nhập vào hệ thống để tải đơn MCP của bạn.',
                      ),
                    )
                  else if (orders.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Chưa có đơn hàng',
                        message:
                            'Đơn tạo từ điểm bán sẽ hiển thị tại đây.',
                      ),
                    )
                  else
                    ...orders.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: order,
                          onTap: () => _showOrderDetail(context, order),
                        ),
                      ),
                    ),
                ],
              ),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  final FieldOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('order-row-${order.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
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
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.number ?? 'Đơn MCP',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.customerName ??
                        order.customerCode ??
                        'Khách hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (order.total != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _money(order.total!),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(
                  label: _statusLabel(order.status),
                  backgroundColor: _statusColor(order.status).withValues(
                    alpha: 0.12,
                  ),
                  foregroundColor: _statusColor(order.status),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(order.updatedAt ?? order.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOrderDetail(
  BuildContext context,
  FieldOrder order,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.number ?? 'Chi tiết đơn MCP',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                label: 'Khách hàng',
                value:
                    order.customerName ?? order.customerCode ?? 'Chưa có',
              ),
              const Divider(),
              _DetailRow(
                label: 'Trạng thái',
                value: _statusLabel(order.status),
              ),
              const Divider(),
              _DetailRow(
                label: 'Giá trị',
                value: order.total == null
                    ? 'Theo xác nhận của Công Ty'
                    : _money(order.total!),
              ),
              const Divider(),
              _DetailRow(
                label: 'Cập nhật',
                value: _formatDateTime(order.updatedAt ?? order.createdAt),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'confirmed':
      return 'Đã xác nhận';
    case 'cancelled':
      return 'Đã hủy';
    case 'closed':
      return 'Hoàn tất';
    default:
      return 'Nháp';
  }
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'confirmed':
    case 'closed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.warning;
  }
}

String _formatDate(String? value) {
  final parsed = DateTime.tryParse((value ?? '').trim())?.toLocal();
  if (parsed == null) return '';
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatDateTime(String? value) {
  final parsed = DateTime.tryParse((value ?? '').trim())?.toLocal();
  if (parsed == null) return 'Chưa có';
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute · $day/$month/$year';
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '${buffer.toString()} đ';
}
