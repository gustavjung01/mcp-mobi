import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    required this.outlet,
    required this.orderClient,
    super.key,
  });

  final FieldOutlet outlet;
  final OrderDataClient orderClient;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, _CartItem> _cart = {};
  List<OrderCatalogItem> _products = const [];
  Set<String> _knownCategories = {};
  Set<String> _knownBrands = {};
  String? _category;
  String? _brand;
  String? _message;
  String? _submissionFingerprint;
  String? _submissionKey;
  bool _loadingProducts = true;
  bool _saving = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), _loadProducts);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _message = null;
    });
    try {
      final products = await widget.orderClient.searchProducts(
        query: _searchController.text,
        category: _category,
        brand: _brand,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _knownCategories = {
          ..._knownCategories,
          ...products.map((item) => item.category).whereType<String>(),
        };
        _knownBrands = {
          ..._knownBrands,
          ...products.map((item) => item.brand).whereType<String>(),
        };
      });
    } on OrderDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
        });
      }
    }
  }

  void _addProduct(OrderCatalogItem product) {
    setState(() {
      final current = _cart[product.variantId];
      _cart[product.variantId] = _CartItem(
        product: product,
        quantity: (current?.quantity ?? 0) + 1,
      );
      _message = null;
    });
  }

  void _changeQuantity(OrderCatalogItem product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(product.variantId);
      } else {
        _cart[product.variantId] = _CartItem(
          product: product,
          quantity: quantity,
        );
      }
      _message = null;
    });
  }

  String _fingerprint(List<_CartItem> items) {
    return jsonEncode({
      'customerId': widget.outlet.coreCustomerId,
      'customerAddressId': widget.outlet.coreCustomerAddressId,
      'note': _noteController.text.trim(),
      'lines': items
          .map(
            (item) => {
              'variantId': item.product.variantId,
              'quantity': item.quantity,
            },
          )
          .toList(growable: false),
    });
  }

  Future<void> _submit() async {
    final customerId = (widget.outlet.coreCustomerId ?? '').trim();
    final addressId = (widget.outlet.coreCustomerAddressId ?? '').trim();
    if (customerId.isEmpty || addressId.isEmpty) {
      setState(() {
        _message = 'Điểm bán chưa liên kết đủ khách Công Ty và địa chỉ giao hàng để ra đơn.';
      });
      return;
    }

    final items = _cart.values.toList(growable: false)
      ..sort(
        (left, right) =>
            left.product.variantId.compareTo(right.product.variantId),
      );
    if (items.isEmpty) {
      setState(() {
        _message = 'Chọn ít nhất một sản phẩm.';
      });
      return;
    }

    final fingerprint = _fingerprint(items);
    if (_submissionFingerprint != fingerprint || _submissionKey == null) {
      _submissionFingerprint = fingerprint;
      _submissionKey = CanonicalIdempotencyKey.create(
        'mcp.sales-order.create',
      );
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.orderClient.createOrder(
        customerId: customerId,
        customerAddressId: addressId,
        note: _noteController.text,
        lines: items
            .map(
              (item) => OrderLineInput(
                variantId: item.product.variantId,
                quantity: item.quantity,
                note:
                    [
                          item.product.name,
                          item.product.variantName,
                          item.product.sku,
                        ]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(
                          ' · ',
                        ),
              ),
            )
            .toList(growable: false),
        idempotencyKey: _submissionKey!,
      );
      _submissionFingerprint = null;
      _submissionKey = null;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OrderDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  double get _estimatedTotal => _cart.values.fold<double>(
    0,
    (sum, item) => sum + (item.product.price ?? 0) * item.quantity,
  );

  bool get _hasUnknownPrice =>
      _cart.values.any((item) => item.product.price == null);

  @override
  Widget build(BuildContext context) {
    final categories = _knownCategories.toList()..sort();
    final brands = _knownBrands.toList()..sort();

    return Scaffold(
      key: const Key('create-order-screen'),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Tạo đơn hàng',
            subtitle: 'Giá và chính sách thương mại do Công Ty xác định',
            leading: IconButton(
              key: const Key('create-order-back'),
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                120,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.outlet.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                    widget.outlet.coreCustomerCode ??
                                        widget.outlet.code,
                                    widget.outlet.address,
                                  ]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(
                                    ' · ',
                                  ),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Sản phẩm',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('order-product-search'),
                  controller: _searchController,
                  enabled: !_saving,
                  onChanged: _scheduleSearch,
                  decoration: const InputDecoration(
                    hintText: 'Tìm tên hoặc SKU',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                if (categories.isNotEmpty || brands.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('order-category-filter'),
                          initialValue: _category ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ngành hàng',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả'),
                            ),
                            ...categories.map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _category = (value ?? '').isEmpty
                                        ? null
                                        : value;
                                  });
                                  _loadProducts();
                                },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('order-brand-filter'),
                          initialValue: _brand ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Nhãn hàng',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả'),
                            ),
                            ...brands.map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _brand = (value ?? '').isEmpty
                                        ? null
                                        : value;
                                  });
                                  _loadProducts();
                                },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_loadingProducts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_products.isEmpty)
                  const AppCard(
                    child: Text(
                      'Không tìm thấy sản phẩm phù hợp.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ..._products.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ProductRow(
                        product: product,
                        selectedQuantity:
                            _cart[product.variantId]?.quantity ?? 0,
                        onAdd: _saving ? null : () => _addProduct(product),
                      ),
                    ),
                  ),
                if (_cart.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Đơn đang tạo',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_cart.length} SKU',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      children: [
                        for (var index = 0; index < _cart.length; index++) ...[
                          _CartRow(
                            item: _cart.values.elementAt(index),
                            enabled: !_saving,
                            onQuantityChanged: _changeQuantity,
                          ),
                          if (index < _cart.length - 1)
                            const Divider(height: AppSpacing.lg),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('order-note'),
                    controller: _noteController,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú đơn',
                      hintText: 'Thông tin cần Công Ty lưu ý',
                    ),
                  ),
                ],
                if ((_message ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    key: const Key('order-message'),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tạm tính',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _cart.isEmpty ? '0 đ' : _money(_estimatedTotal),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_hasUnknownPrice)
                      const Text(
                        'Có giá sẽ do Công Ty xác định',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 160,
                child: FilledButton(
                  key: const Key('order-submit'),
                  onPressed: _saving || _cart.isEmpty ? null : _submit,
                  child: Text(_saving ? 'Đang gửi...' : 'Gửi đơn hàng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.selectedQuantity,
    required this.onAdd,
  });

  final OrderCatalogItem product;
  final int selectedQuantity;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.secondaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.price == null
                      ? 'Công Ty xác định giá'
                      : _money(product.price!),
                  style: TextStyle(
                    color: product.price == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            key: Key('order-add-${product.variantId}'),
            onPressed: onAdd,
            tooltip: 'Thêm sản phẩm',
            icon: selectedQuantity > 0
                ? Text(
                    '+$selectedQuantity',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  )
                : const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _CartItem {
  const _CartItem({
    required this.product,
    required this.quantity,
  });

  final OrderCatalogItem product;
  final int quantity;
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.enabled,
    required this.onQuantityChanged,
  });

  final _CartItem item;
  final bool enabled;
  final void Function(OrderCatalogItem product, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('order-cart-${item.product.variantId}'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.product.price == null
                    ? 'Công Ty xác định giá'
                    : _money(item.product.price! * item.quantity),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: Key('order-minus-${item.product.variantId}'),
          onPressed: enabled
              ? () => onQuantityChanged(
                  item.product,
                  item.quantity - 1,
                )
              : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          alignment: Alignment.center,
          child: Text(
            item.quantity.toString(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          key: Key('order-plus-${item.product.variantId}'),
          onPressed: enabled
              ? () => onQuantityChanged(
                  item.product,
                  item.quantity + 1,
                )
              : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
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
