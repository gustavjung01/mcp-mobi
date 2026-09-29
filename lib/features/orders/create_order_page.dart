import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/sync/order_offline_store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

enum OrderSubmitOutcome {
  created,
  queued,
}

enum _OrderPanel {
  catalog,
  cart,
  review,
  result,
}

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    required this.outlet,
    required this.orderClient,
    this.offlineStore,
    super.key,
  });

  final FieldOutlet outlet;
  final OrderDataClient orderClient;
  final OrderOfflineStore? offlineStore;

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
  bool _draftLoaded = false;
  bool _submitted = false;
  bool _refreshingPrices = false;
  int _productLoadGeneration = 0;
  _OrderPanel _panel = _OrderPanel.catalog;
  OrderSubmitOutcome? _resultOutcome;
  FieldOrder? _createdOrder;
  OrderDataFailure? _resultFailure;
  Timer? _searchTimer;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_scheduleDraftSave);
    _restoreDraft();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _draftTimer?.cancel();
    if (!_submitted) {
      unawaited(_saveDraft());
    }
    _noteController.removeListener(_scheduleDraftSave);
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final store = widget.offlineStore;
    if (store == null) {
      _draftLoaded = true;
      return;
    }

    try {
      final draft = await store.readDraft(widget.outlet.id);
      if (!mounted) return;
      final customerId = (widget.outlet.coreCustomerId ?? '').trim();
      final addressId = (widget.outlet.coreCustomerAddressId ?? '').trim();
      if (draft != null &&
          draft.customerId == customerId &&
          draft.customerAddressId == addressId) {
        _noteController.text = draft.note;
        for (final line in draft.lines) {
          _cart[line.product.variantId] = _CartItem(
            product: line.product,
            quantity: line.quantity,
          );
        }
      } else if (draft != null) {
        await store.deleteDraft(widget.outlet.id);
      }
    } catch (_) {
      // A storage problem must not block online order creation.
    }
    _draftLoaded = true;
    if (mounted) {
      setState(() {});
      if (_cart.isNotEmpty) {
        unawaited(_loadProducts());
      }
    }
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded || _submitted || widget.offlineStore == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    final store = widget.offlineStore;
    if (store == null || !_draftLoaded || _submitted) return;

    final customerId = (widget.outlet.coreCustomerId ?? '').trim();
    final addressId = (widget.outlet.coreCustomerAddressId ?? '').trim();
    if (customerId.isEmpty || addressId.isEmpty) return;

    final items = _cart.values.toList(growable: false)
      ..sort(
        (left, right) =>
            left.product.variantId.compareTo(right.product.variantId),
      );
    final note = _noteController.text.trim();
    try {
      if (items.isEmpty && note.isEmpty) {
        await store.deleteDraft(widget.outlet.id);
        return;
      }
      await store.saveDraft(
        OrderDraft(
          outletId: widget.outlet.id,
          customerId: customerId,
          customerAddressId: addressId,
          note: note,
          lines: items
              .map(
                (item) => OrderDraftLine(
                  product: item.product,
                  quantity: item.quantity,
                ),
              )
              .toList(growable: false),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      // Draft persistence is best effort. Submission still uses the API contract.
    }
  }

  void _scheduleSearch(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), _loadProducts);
  }

  Future<void> _loadProducts() async {
    final generation = ++_productLoadGeneration;
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
      if (!mounted || generation != _productLoadGeneration) return;
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

      final priceClient = widget.orderClient;
      if (priceClient is OrderCatalogPriceClient) {
        final priceSource = priceClient as OrderCatalogPriceClient;
        setState(() => _refreshingPrices = true);
        try {
          final prices = await priceSource.loadFreshPrices(
            query: _searchController.text,
            category: _category,
            brand: _brand,
          );
          if (!mounted || generation != _productLoadGeneration) return;
          setState(() {
            _products = _products
                .map(
                  (product) => prices.containsKey(product.variantId)
                      ? product.withPrice(prices[product.variantId])
                      : product,
                )
                .toList(growable: false);
            for (final entry in _cart.entries.toList(growable: false)) {
              if (!prices.containsKey(entry.key)) continue;
              _cart[entry.key] = _CartItem(
                product: entry.value.product.withPrice(prices[entry.key]),
                quantity: entry.value.quantity,
              );
            }
          });
          _scheduleDraftSave();
        } on OrderDataFailure {
          if (mounted && generation == _productLoadGeneration) {
            setState(() {
              _message =
                  'Đang dùng giá tham khảo gần nhất. Công Ty sẽ xác định giá khi gửi đơn.';
            });
          }
        } finally {
          if (mounted && generation == _productLoadGeneration) {
            setState(() => _refreshingPrices = false);
          }
        }
      }
    } on OrderDataFailure catch (failure) {
      if (!mounted || generation != _productLoadGeneration) return;
      setState(() {
        _products = const [];
        _message = failure.message;
      });
    } finally {
      if (mounted && generation == _productLoadGeneration) {
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
    _scheduleDraftSave();
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
    _scheduleDraftSave();
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
        _resultFailure = const OrderDataFailure(
          code: 'CORE_CUSTOMER_REFERENCE_REQUIRED',
          message:
              'Điểm bán chưa liên kết đủ khách Công Ty và địa chỉ giao hàng để ra đơn.',
        );
        _resultOutcome = null;
        _createdOrder = null;
        _panel = _OrderPanel.result;
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
        _panel = _OrderPanel.catalog;
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

    final orderLines = items
        .map(
          (item) => OrderLineInput(
            variantId: item.product.variantId,
            quantity: item.quantity,
            note:
                [
                      item.product.name,
                      item.product.variantName,
                      item.product.sizeLabel,
                      item.product.sellUnit,
                      item.product.sku,
                    ]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .toSet()
                    .join(' · '),
          ),
        )
        .toList(growable: false);
    final mutation = QueuedOrderMutation(
      idempotencyKey: _submissionKey!,
      outletId: widget.outlet.id,
      outletName: widget.outlet.name,
      customerId: customerId,
      customerAddressId: addressId,
      note: _noteController.text.trim(),
      lines: orderLines,
      createdAt: DateTime.now().toUtc(),
    );

    setState(() {
      _saving = true;
      _message = null;
      _resultFailure = null;
    });

    var mutationPersisted = false;
    final store = widget.offlineStore;
    if (store != null) {
      try {
        await store.saveMutation(mutation);
        mutationPersisted = true;
      } catch (_) {
        mutationPersisted = false;
      }
    }

    try {
      final order = await widget.orderClient.createOrder(
        customerId: customerId,
        customerAddressId: addressId,
        note: mutation.note,
        lines: orderLines,
        idempotencyKey: mutation.idempotencyKey,
      );
      if (mutationPersisted) {
        try {
          await store!.saveMutation(mutation.acknowledged(order));
        } catch (_) {
          // Công Ty đã nhận đúng thao tác; xác nhận local có thể cập nhật sau.
        }
      }
      if (store != null) {
        try {
          await store.deleteDraft(widget.outlet.id);
        } catch (_) {
          // Đơn thành công nên draft cũ không được biến thành lỗi người dùng.
        }
      }
      _submitted = true;
      _submissionFingerprint = null;
      _submissionKey = null;
      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _resultOutcome = OrderSubmitOutcome.created;
        _resultFailure = null;
        _panel = _OrderPanel.result;
      });
    } on OrderDataFailure catch (failure) {
      if (mutationPersisted && failure.retryable) {
        try {
          await store!.saveMutation(mutation.failed(failure));
          try {
            await store.deleteDraft(widget.outlet.id);
          } catch (_) {
            // Mutation đã lưu bền vững và là nguồn tiếp tục gửi.
          }
          _submitted = true;
          if (!mounted) return;
          setState(() {
            _createdOrder = null;
            _resultOutcome = OrderSubmitOutcome.queued;
            _resultFailure = failure;
            _panel = _OrderPanel.result;
          });
          return;
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _createdOrder = null;
            _resultOutcome = null;
            _resultFailure = const OrderDataFailure(
              code: 'LOCAL_QUEUE_WRITE_FAILED',
              message:
                  'Chưa lưu được đơn chờ gửi. Giữ màn hình này và thử gửi lại.',
            );
            _panel = _OrderPanel.result;
          });
          return;
        }
      }

      if (mutationPersisted) {
        try {
          await store!.saveMutation(mutation.failed(failure));
        } catch (_) {
          // Giữ intent đã ghi nếu thiết bị chưa cập nhật được trạng thái.
        }
        try {
          await store!.removeMutation(mutation.idempotencyKey);
        } catch (_) {
          // Nếu không xóa được, trạng thái failed sẽ chặn tự gửi lại lỗi nghiệp vụ.
        }
      }
      if (!mounted) return;
      setState(() {
        _createdOrder = null;
        _resultOutcome = null;
        _resultFailure = failure;
        _panel = _OrderPanel.result;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showCart() {
    if (_cart.isEmpty) {
      setState(() => _message = 'Chọn ít nhất một sản phẩm.');
      return;
    }
    setState(() {
      _message = null;
      _panel = _OrderPanel.cart;
    });
  }

  void _showReview() {
    if (_cart.isEmpty) {
      setState(() {
        _message = 'Chọn ít nhất một sản phẩm.';
        _panel = _OrderPanel.catalog;
      });
      return;
    }
    setState(() {
      _message = null;
      _panel = _OrderPanel.review;
    });
  }

  void _handleBack() {
    if (_saving) return;
    switch (_panel) {
      case _OrderPanel.catalog:
        Navigator.of(context).pop();
        return;
      case _OrderPanel.cart:
        setState(() => _panel = _OrderPanel.catalog);
        return;
      case _OrderPanel.review:
        setState(() => _panel = _OrderPanel.cart);
        return;
      case _OrderPanel.result:
        if (_resultOutcome != null) {
          Navigator.of(context).pop(_resultOutcome);
        } else {
          setState(() {
            _resultFailure = null;
            _panel = _OrderPanel.review;
          });
        }
        return;
    }
  }

  void _runPrimaryAction() {
    switch (_panel) {
      case _OrderPanel.catalog:
        _showCart();
        return;
      case _OrderPanel.cart:
        _showReview();
        return;
      case _OrderPanel.review:
        unawaited(_submit());
        return;
      case _OrderPanel.result:
        if (_resultOutcome != null) {
          Navigator.of(context).pop(_resultOutcome);
        } else {
          setState(() {
            _resultFailure = null;
            _panel = _OrderPanel.review;
          });
        }
        return;
    }
  }

  String get _primaryLabel {
    return switch (_panel) {
      _OrderPanel.catalog => 'Xem giỏ (${_cart.length})',
      _OrderPanel.cart => 'Rà đơn',
      _OrderPanel.review => _saving ? 'Đang gửi...' : 'Gửi đơn hàng',
      _OrderPanel.result =>
        _resultOutcome != null ? 'Hoàn tất' : 'Quay lại rà đơn',
    };
  }

  double get _estimatedTotal => _cart.values.fold<double>(
    0,
    (sum, item) => sum + (item.product.price ?? 0) * item.quantity,
  );

  bool get _hasUnknownPrice =>
      _cart.values.any((item) => item.product.price == null);

  Widget _customerCard() {
    return AppCard(
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
                    widget.outlet.coreCustomerCode ?? widget.outlet.code,
                    widget.outlet.address,
                  ].where((value) => value.trim().isNotEmpty).join(' · '),
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
    );
  }

  Widget _messageCard() {
    if ((_message ?? '').isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
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
    );
  }

  Widget _catalogPanel(
    List<_ProductGroup> groups,
    List<String> categories,
    List<String> brands,
  ) {
    return ListView(
      key: const Key('order-catalog-panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        120,
      ),
      children: [
        _customerCard(),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Sản phẩm',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Chọn đúng quy cách bán. Giá hiển thị là giá tham khảo từ Công Ty.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
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
                  decoration: const InputDecoration(labelText: 'Ngành hàng'),
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
                            _category = (value ?? '').isEmpty ? null : value;
                          });
                          unawaited(_loadProducts());
                        },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('order-brand-filter'),
                  initialValue: _brand ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nhãn hàng'),
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
                            _brand = (value ?? '').isEmpty ? null : value;
                          });
                          unawaited(_loadProducts());
                        },
                ),
              ),
            ],
          ),
        ],
        if (_refreshingPrices) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Đang cập nhật giá tham khảo từ Công Ty...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
        _messageCard(),
        const SizedBox(height: AppSpacing.sm),
        if (_loadingProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (groups.isEmpty)
          const AppCard(
            child: Text(
              'Không tìm thấy sản phẩm phù hợp.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ProductGroupCard(
                group: group,
                selectedQuantity: (variantId) =>
                    _cart[variantId]?.quantity ?? 0,
                onAdd: _saving ? null : _addProduct,
              ),
            ),
          ),
      ],
    );
  }

  Widget _cartPanel() {
    final items = _cart.values.toList(growable: false);
    return ListView(
      key: const Key('order-cart-panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        120,
      ),
      children: [
        _customerCard(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Giỏ hàng',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${items.length} dòng',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          const AppCard(
            child: Text(
              'Giỏ hàng chưa có sản phẩm.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _CartRow(
                    item: items[index],
                    enabled: !_saving,
                    onQuantityChanged: _changeQuantity,
                  ),
                  if (index < items.length - 1)
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
        _messageCard(),
      ],
    );
  }

  Widget _reviewPanel() {
    final items = _cart.values.toList(growable: false);
    return ListView(
      key: const Key('order-review-panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        120,
      ),
      children: [
        _customerCard(),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Rà đơn trước khi gửi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Kiểm tra khách, quy cách và số lượng. Giá cuối cùng do Công Ty xác định khi tạo đơn.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.product.secondaryLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Số lượng: ${item.quantity}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.product.price == null
                        ? 'Công Ty xác định'
                        : _money(item.product.price! * item.quantity),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppCard(
          child: Column(
            children: [
              _ReviewRow(
                label: 'Tạm tính tham khảo',
                value: _cart.isEmpty ? '0 đ' : _money(_estimatedTotal),
              ),
              _ReviewRow(
                label: 'Ghi chú',
                value: _noteController.text.trim().isEmpty
                    ? 'Không có'
                    : _noteController.text.trim(),
              ),
              if (_hasUnknownPrice)
                const _ReviewRow(
                  label: 'Giá chưa có',
                  value: 'Công Ty xác định khi gửi',
                ),
            ],
          ),
        ),
        _messageCard(),
      ],
    );
  }

  Widget _resultPanel() {
    final failure = _resultFailure;
    final created = _resultOutcome == OrderSubmitOutcome.created;
    final queued = _resultOutcome == OrderSubmitOutcome.queued;
    return ListView(
      key: const Key('order-result-panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        120,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              Icon(
                created
                    ? Icons.check_circle_rounded
                    : queued
                    ? Icons.cloud_upload_rounded
                    : Icons.error_outline_rounded,
                size: 54,
                color: created
                    ? AppColors.success
                    : queued
                    ? AppColors.warning
                    : AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                created
                    ? 'Đã gửi đơn đến Công Ty'
                    : queued
                    ? 'Đã lưu đơn chờ gửi'
                    : 'Chưa gửi được đơn',
                key: Key(
                  created
                      ? 'order-result-created'
                      : queued
                      ? 'order-result-queued'
                      : 'order-result-failed',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (created)
                Text(
                  _createdOrder?.number ?? _createdOrder?.id ?? 'Đơn hàng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (queued)
                const Text(
                  'Ứng dụng sẽ tự gửi lại. Không cần tạo thêm một đơn mới.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              if (!created && failure != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failure.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!queued) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _orderRecoveryHint(failure.code),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _knownCategories.toList()..sort();
    final brands = _knownBrands.toList()..sort();
    final groups = _groupProducts(_products);

    return Scaffold(
      key: const Key('create-order-screen'),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Tạo đơn hàng',
            subtitle: widget.outlet.name,
            leading: IconButton(
              key: const Key('create-order-back'),
              onPressed: _saving ? null : _handleBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          _OrderStageBar(panel: _panel),
          Expanded(
            child: switch (_panel) {
              _OrderPanel.catalog => _catalogPanel(groups, categories, brands),
              _OrderPanel.cart => _cartPanel(),
              _OrderPanel.review => _reviewPanel(),
              _OrderPanel.result => _resultPanel(),
            },
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
              if (_panel != _OrderPanel.result)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tạm tính tham khảo',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
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
                          'Có giá do Công Ty xác định',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: _panel == _OrderPanel.result ? 190 : 170,
                child: FilledButton(
                  key: const Key('order-primary-action'),
                  onPressed: _saving ||
                          ((_panel == _OrderPanel.catalog ||
                                  _panel == _OrderPanel.cart ||
                                  _panel == _OrderPanel.review) &&
                              _cart.isEmpty)
                      ? null
                      : _runPrimaryAction,
                  child: Text(_primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStageBar extends StatelessWidget {
  const _OrderStageBar({required this.panel});

  final _OrderPanel panel;

  int get _activeStep => switch (panel) {
    _OrderPanel.catalog => 1,
    _OrderPanel.cart => 2,
    _OrderPanel.review => 3,
    _OrderPanel.result => 3,
  };

  @override
  Widget build(BuildContext context) {
    const labels = ['Khách', 'Sản phẩm', 'Giỏ hàng', 'Rà đơn'];
    return Container(
      key: const Key('order-stage-bar'),
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index <= _activeStep
                          ? AppColors.primary
                          : AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: index < _activeStep
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 15,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index == _activeStep
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[index],
                    maxLines: 1,
                    style: TextStyle(
                      color: index == _activeStep
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: index == _activeStep
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (index < labels.length - 1)
              Container(
                width: 10,
                height: 1,
                color: index < _activeStep
                    ? AppColors.primary
                    : AppColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGroup {
  const _ProductGroup({
    required this.productId,
    required this.name,
    required this.variants,
    this.brand,
    this.category,
  });

  final String productId;
  final String name;
  final String? brand;
  final String? category;
  final List<OrderCatalogItem> variants;
}

List<_ProductGroup> _groupProducts(List<OrderCatalogItem> products) {
  final groups = <String, List<OrderCatalogItem>>{};
  for (final product in products) {
    groups.putIfAbsent(product.productId, () => []).add(product);
  }
  final result = groups.entries.map((entry) {
    final variants = [...entry.value]
      ..sort((left, right) {
        final unit = left.purchaseUnitLabel.compareTo(right.purchaseUnitLabel);
        if (unit != 0) return unit;
        return left.purchaseUnitDetail.compareTo(right.purchaseUnitDetail);
      });
    final first = variants.first;
    return _ProductGroup(
      productId: entry.key,
      name: first.name,
      brand: first.brand,
      category: first.category,
      variants: variants,
    );
  }).toList(growable: false)
    ..sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
  return result;
}

class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    required this.group,
    required this.selectedQuantity,
    required this.onAdd,
  });

  final _ProductGroup group;
  final int Function(String variantId) selectedQuantity;
  final void Function(OrderCatalogItem product)? onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('order-product-card-${group.productId}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ([group.brand, group.category]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [group.brand, group.category]
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
              ],
            ),
          ),
          for (var index = 0; index < group.variants.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            Builder(
              builder: (context) {
                final product = group.variants[index];
                final quantity = selectedQuantity(product.variantId);
                return InkWell(
                  key: Key('order-add-${product.variantId}'),
                  onTap: onAdd == null ? null : () => onAdd!(product),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            product.purchaseUnitLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 10,
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
                                product.purchaseUnitDetail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                product.price == null
                                    ? 'Công Ty xác định giá'
                                    : _money(product.price!),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          constraints: const BoxConstraints(minWidth: 54),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: quantity > 0
                                ? AppColors.primary
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            quantity > 0 ? 'Đã chọn ×$quantity' : 'Thêm',
                            style: TextStyle(
                              color: quantity > 0
                                  ? Colors.white
                                  : AppColors.primaryDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
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

String _orderRecoveryHint(String code) {
  switch (code.trim().toUpperCase()) {
    case 'CORE_CUSTOMER_ADDRESS_NOT_AVAILABLE':
    case 'CORE_CUSTOMER_NOT_OWNED':
    case 'CUSTOMER_NOT_FOUND':
    case 'CUSTOMER_INACTIVE':
      return 'Cập nhật lại khách Công Ty rồi tạo lại đơn.';
    case 'BASE_PRICE_NOT_FOUND':
    case 'SALES_PRICE_CHANGED':
      return 'Cập nhật danh mục và giá, sau đó rà lại đơn.';
    case 'VARIANT_NOT_FOUND':
    case 'VARIANT_INACTIVE':
    case 'VARIANT_NOT_PRICEABLE':
    case 'VARIANT_UNIT_MISSING':
      return 'Quay lại giỏ hàng, bỏ sản phẩm không còn phù hợp và chọn lại.';
    case 'WAREHOUSE_SCOPE_DENIED':
      return 'Liên hệ quản lý để kiểm tra quyền và phạm vi kho.';
    case 'CORE_SALES_NOT_CONFIGURED':
      return 'Liên hệ quản lý hệ thống để kiểm tra kết nối bán hàng Công Ty.';
    default:
      return 'Quay lại rà đơn, cập nhật dữ liệu cần thiết rồi gửi lại.';
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
