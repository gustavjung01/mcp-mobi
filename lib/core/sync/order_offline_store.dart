import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/order_data_client.dart';
import '../idempotency/canonical_idempotency.dart';
import 'mutation_queue.dart';

const orderMutationOperation = 'mcp.sales-order.create';

enum OrderQueueState {
  waiting,
  failed,
  acknowledged,
}

class OrderDraftLine {
  const OrderDraftLine({
    required this.product,
    required this.quantity,
  });

  final OrderCatalogItem product;
  final int quantity;

  Map<String, Object?> toJson() => {
    'quantity': quantity,
    'product': {
      'productId': product.productId,
      'variantId': product.variantId,
      'name': product.name,
      if (product.brand != null) 'brand': product.brand,
      if (product.category != null) 'category': product.category,
      if (product.sku != null) 'sku': product.sku,
      if (product.variantName != null) 'variantName': product.variantName,
      if (product.sizeLabel != null) 'sizeLabel': product.sizeLabel,
      if (product.sellUnit != null) 'sellUnit': product.sellUnit,
      if (product.packUnit != null) 'packUnit': product.packUnit,
      if (product.packQuantity != null) 'packQuantity': product.packQuantity,
      if (product.price != null) 'price': product.price,
    },
  };

  static OrderDraftLine? fromJson(Object? value) {
    final json = _object(value);
    final productJson = _object(json['product']);
    final product = OrderCatalogItem.fromJson(productJson);
    final quantity = _integer(json['quantity']);
    if (product.variantId.isEmpty ||
        product.productId.isEmpty ||
        quantity <= 0) {
      return null;
    }
    return OrderDraftLine(product: product, quantity: quantity);
  }
}

class OrderDraft {
  const OrderDraft({
    required this.outletId,
    required this.customerId,
    required this.customerAddressId,
    required this.note,
    required this.lines,
    required this.updatedAt,
  });

  final String outletId;
  final String customerId;
  final String customerAddressId;
  final String note;
  final List<OrderDraftLine> lines;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'outletId': outletId,
    'customerId': customerId,
    'customerAddressId': customerAddressId,
    'note': note,
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static OrderDraft? fromJson(Object? value) {
    final json = _object(value);
    final outletId = _text(json['outletId']);
    final customerId = _text(json['customerId']);
    final customerAddressId = _text(json['customerAddressId']);
    final updatedAt = DateTime.tryParse(_text(json['updatedAt']));
    if (outletId.isEmpty ||
        customerId.isEmpty ||
        customerAddressId.isEmpty ||
        updatedAt == null) {
      return null;
    }
    final lines = _list(json['lines'])
        .map(OrderDraftLine.fromJson)
        .whereType<OrderDraftLine>()
        .toList(growable: false);
    return OrderDraft(
      outletId: outletId,
      customerId: customerId,
      customerAddressId: customerAddressId,
      note: _text(json['note']),
      lines: lines,
      updatedAt: updatedAt,
    );
  }
}

class QueuedOrderMutation {
  const QueuedOrderMutation({
    required this.idempotencyKey,
    required this.outletId,
    required this.outletName,
    required this.customerId,
    required this.customerAddressId,
    required this.note,
    required this.lines,
    required this.createdAt,
    this.state = OrderQueueState.waiting,
    this.retryCount = 0,
    this.retryable = true,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.serverOrderId,
    this.serverAcknowledgedAt,
  });

  final String idempotencyKey;
  final String outletId;
  final String outletName;
  final String customerId;
  final String customerAddressId;
  final String note;
  final List<OrderLineInput> lines;
  final DateTime createdAt;
  final OrderQueueState state;
  final int retryCount;
  final bool retryable;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final String? serverOrderId;
  final DateTime? serverAcknowledgedAt;

  bool get isOutstanding => state != OrderQueueState.acknowledged;

  QueuedOrderMutation failed(OrderDataFailure failure) {
    return QueuedOrderMutation(
      idempotencyKey: idempotencyKey,
      outletId: outletId,
      outletName: outletName,
      customerId: customerId,
      customerAddressId: customerAddressId,
      note: note,
      lines: lines,
      createdAt: createdAt,
      state: OrderQueueState.failed,
      retryCount: retryCount + 1,
      retryable: failure.retryable,
      lastErrorCode: failure.code,
      lastErrorMessage: failure.message,
    );
  }

  QueuedOrderMutation acknowledged(FieldOrder order) {
    return QueuedOrderMutation(
      idempotencyKey: idempotencyKey,
      outletId: outletId,
      outletName: outletName,
      customerId: customerId,
      customerAddressId: customerAddressId,
      note: note,
      lines: lines,
      createdAt: createdAt,
      state: OrderQueueState.acknowledged,
      retryCount: retryCount,
      retryable: false,
      serverOrderId: order.id,
      serverAcknowledgedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'idempotencyKey': idempotencyKey,
    'outletId': outletId,
    'outletName': outletName,
    'customerId': customerId,
    'customerAddressId': customerAddressId,
    'note': note,
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
    'retryCount': retryCount,
    'retryable': retryable,
    if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
    if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
    if (serverOrderId != null) 'serverOrderId': serverOrderId,
    if (serverAcknowledgedAt != null)
      'serverAcknowledgedAt': serverAcknowledgedAt!.toUtc().toIso8601String(),
  };

  static QueuedOrderMutation? fromJson(Object? value) {
    final json = _object(value);
    final key = _text(json['idempotencyKey']);
    final outletId = _text(json['outletId']);
    final customerId = _text(json['customerId']);
    final customerAddressId = _text(json['customerAddressId']);
    final createdAt = DateTime.tryParse(_text(json['createdAt']));
    if (!CanonicalIdempotencyKey.isValid(key) ||
        outletId.isEmpty ||
        customerId.isEmpty ||
        customerAddressId.isEmpty ||
        createdAt == null) {
      return null;
    }

    final lines = _list(json['lines'])
        .map(_lineFromJson)
        .whereType<OrderLineInput>()
        .toList(growable: false);
    if (lines.isEmpty) return null;

    final stateName = _text(json['state']);
    final state = OrderQueueState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => OrderQueueState.waiting,
    );

    return QueuedOrderMutation(
      idempotencyKey: key,
      outletId: outletId,
      outletName: _text(json['outletName'], fallback: 'Điểm bán'),
      customerId: customerId,
      customerAddressId: customerAddressId,
      note: _text(json['note']),
      lines: lines,
      createdAt: createdAt,
      state: state,
      retryCount: _integer(json['retryCount']),
      retryable: json['retryable'] != false,
      lastErrorCode: _nullableText(json['lastErrorCode']),
      lastErrorMessage: _nullableText(json['lastErrorMessage']),
      serverOrderId: _nullableText(json['serverOrderId']),
      serverAcknowledgedAt: DateTime.tryParse(
        _text(json['serverAcknowledgedAt']),
      ),
    );
  }
}

abstract interface class OrderOfflineStore {
  Future<OrderDraft?> readDraft(String outletId);

  Future<void> saveDraft(OrderDraft draft);

  Future<void> deleteDraft(String outletId);

  Future<List<QueuedOrderMutation>> loadMutations();

  Future<void> saveMutation(QueuedOrderMutation mutation);

  Future<void> removeMutation(String idempotencyKey);
}

class SecureOrderOfflineStore implements OrderOfflineStore {
  SecureOrderOfflineStore({
    required String installationKey,
    required String employeeId,
    FlutterSecureStorage? storage,
    MutationQueueStore? mutationQueueStore,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _scope = base64Url
           .encode(utf8.encode('$installationKey|$employeeId'))
           .replaceAll('=', ''),
       _mutationQueue =
           mutationQueueStore ??
           SecureMutationQueueStore(
             installationKey: installationKey,
             employeeId: employeeId,
             storage: storage,
           );

  final FlutterSecureStorage _storage;
  final String _scope;
  final MutationQueueStore _mutationQueue;

  String get _draftsKey => 'mcp.orders.drafts.$_scope';

  String get _legacyMutationsKey => 'mcp.orders.mutations.$_scope';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _readDraftMap() async {
    final raw = await _read(_draftsKey);
    if ((raw ?? '').isEmpty) return <String, Object?>{};
    try {
      return _object(jsonDecode(raw!)).map(
        (key, value) => MapEntry(key, value),
      );
    } on FormatException {
      return <String, Object?>{};
    }
  }

  @override
  Future<OrderDraft?> readDraft(String outletId) async {
    final drafts = await _readDraftMap();
    return OrderDraft.fromJson(drafts[outletId]);
  }

  @override
  Future<void> saveDraft(OrderDraft draft) async {
    final drafts = await _readDraftMap();
    drafts[draft.outletId] = draft.toJson();
    await _storage.write(key: _draftsKey, value: jsonEncode(drafts));
  }

  @override
  Future<void> deleteDraft(String outletId) async {
    final drafts = await _readDraftMap();
    if (drafts.remove(outletId) == null) return;
    await _storage.write(key: _draftsKey, value: jsonEncode(drafts));
  }

  Future<List<QueuedOrderMutation>> _loadLegacyMutations() async {
    final raw = await _read(_legacyMutationsKey);
    if ((raw ?? '').isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw!);
      if (decoded is! List) return const [];
      return decoded
          .map(QueuedOrderMutation.fromJson)
          .whereType<QueuedOrderMutation>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<List<QueuedOrderMutation>> loadMutations() async {
    final shared = await _mutationQueue.load(
      operations: const {orderMutationOperation},
    );
    if (shared.isNotEmpty) {
      return shared
          .map(_orderMutationFromShared)
          .whereType<QueuedOrderMutation>()
          .toList(growable: false);
    }

    final legacy = await _loadLegacyMutations();
    if (legacy.isEmpty) return const [];
    for (final mutation in legacy) {
      await _mutationQueue.save(_orderMutationToShared(mutation));
    }
    try {
      await _storage.delete(key: _legacyMutationsKey);
    } catch (_) {
      // The migrated shared queue is authoritative.
    }
    return legacy;
  }

  @override
  Future<void> saveMutation(QueuedOrderMutation mutation) {
    return _mutationQueue.save(_orderMutationToShared(mutation));
  }

  @override
  Future<void> removeMutation(String idempotencyKey) {
    return _mutationQueue.remove(idempotencyKey);
  }
}

QueuedMutation _orderMutationToShared(QueuedOrderMutation mutation) {
  return QueuedMutation(
    idempotencyKey: mutation.idempotencyKey,
    operation: orderMutationOperation,
    entityType: 'order',
    entityLabel: mutation.outletName,
    payload: {
      'outletId': mutation.outletId,
      'customerId': mutation.customerId,
      'customerAddressId': mutation.customerAddressId,
      'note': mutation.note,
      'lines': mutation.lines
          .map((line) => line.toJson())
          .toList(growable: false),
    },
    createdAt: mutation.createdAt,
    state: switch (mutation.state) {
      OrderQueueState.waiting => MutationQueueState.waiting,
      OrderQueueState.failed => MutationQueueState.failed,
      OrderQueueState.acknowledged => MutationQueueState.acknowledged,
    },
    retryCount: mutation.retryCount,
    retryable: mutation.retryable,
    lastErrorCode: mutation.lastErrorCode,
    lastErrorMessage: mutation.lastErrorMessage,
    serverReference: mutation.serverOrderId,
    acknowledgedAt: mutation.serverAcknowledgedAt,
  );
}

QueuedOrderMutation? _orderMutationFromShared(QueuedMutation mutation) {
  if (mutation.operation != orderMutationOperation) return null;
  final payload = _object(mutation.payload);
  final lines = _list(payload['lines'])
      .map(_lineFromJson)
      .whereType<OrderLineInput>()
      .toList(growable: false);
  final outletId = _text(payload['outletId']);
  final customerId = _text(payload['customerId']);
  final addressId = _text(payload['customerAddressId']);
  if (outletId.isEmpty ||
      customerId.isEmpty ||
      addressId.isEmpty ||
      lines.isEmpty) {
    return null;
  }
  return QueuedOrderMutation(
    idempotencyKey: mutation.idempotencyKey,
    outletId: outletId,
    outletName: mutation.entityLabel,
    customerId: customerId,
    customerAddressId: addressId,
    note: _text(payload['note']),
    lines: lines,
    createdAt: mutation.createdAt,
    state: switch (mutation.state) {
      MutationQueueState.waiting => OrderQueueState.waiting,
      MutationQueueState.failed => OrderQueueState.failed,
      MutationQueueState.acknowledged => OrderQueueState.acknowledged,
    },
    retryCount: mutation.retryCount,
    retryable: mutation.retryable,
    lastErrorCode: mutation.lastErrorCode,
    lastErrorMessage: mutation.lastErrorMessage,
    serverOrderId: mutation.serverReference,
    serverAcknowledgedAt: mutation.acknowledgedAt,
  );
}

class OrderSyncResult {
  const OrderSyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class OrderSyncService {
  const OrderSyncService({
    required this.client,
    required this.store,
  });

  final OrderDataClient client;
  final OrderOfflineStore store;

  Future<OrderSyncResult> syncPending({String? idempotencyKey}) async {
    final mutations = await store.loadMutations();
    var sent = 0;
    var failed = 0;

    for (final mutation in mutations) {
      if (!mutation.isOutstanding) continue;
      if (idempotencyKey != null && mutation.idempotencyKey != idempotencyKey) {
        continue;
      }
      if (idempotencyKey == null &&
          mutation.state == OrderQueueState.failed &&
          !mutation.retryable) {
        continue;
      }

      try {
        final order = await client.createOrder(
          customerId: mutation.customerId,
          customerAddressId: mutation.customerAddressId,
          lines: mutation.lines,
          idempotencyKey: mutation.idempotencyKey,
          note: mutation.note,
        );
        await store.saveMutation(mutation.acknowledged(order));
        sent += 1;
      } on OrderDataFailure catch (failure) {
        await store.saveMutation(mutation.failed(failure));
        failed += 1;
      }
    }

    final remaining = (await store.loadMutations())
        .where((item) => item.isOutstanding)
        .length;
    return OrderSyncResult(sent: sent, failed: failed, remaining: remaining);
  }
}

OrderLineInput? _lineFromJson(Object? value) {
  final json = _object(value);
  final variantId = _text(json['variantId']);
  final quantity = _integer(json['quantity']);
  if (variantId.isEmpty || quantity <= 0) return null;
  return OrderLineInput(
    variantId: variantId,
    quantity: quantity,
    note: _nullableText(json['note']),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> _list(Object? value) {
  if (value is List) return value.cast<Object?>();
  return const [];
}

String _text(Object? value, {String fallback = ''}) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}
