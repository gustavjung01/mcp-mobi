import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../selection/route_selection_store.dart';
import '../sync/mutation_queue.dart';
import '../sync/order_offline_store.dart';
import 'local_data_store.dart';

class LegacyStorageMigrationFailure implements Exception {
  const LegacyStorageMigrationFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class LegacySecureKeyStore {
  Future<String?> read(String key);

  Future<void> delete(String key);
}

class FlutterSecureLegacyKeyStore implements LegacySecureKeyStore {
  const FlutterSecureLegacyKeyStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class LegacySecureStorageMigrator {
  LegacySecureStorageMigrator({
    required this.database,
    required this.scope,
    LegacySecureKeyStore? secureStore,
    this.ioTimeout = const Duration(seconds: 5),
  }) : _secureStore = secureStore ?? const FlutterSecureLegacyKeyStore(),
       _queue = LocalMutationQueueStore(database: database, scope: scope),
       _orderStore = LocalOrderOfflineStore(
         database: database,
         scope: scope,
         mutationQueueStore: LocalMutationQueueStore(
           database: database,
           scope: scope,
         ),
       ),
       _routeSelection = LocalRouteSelectionStore(
         database: database,
         scope: scope,
       );

  static const migrationMetadataKey = 'legacy_secure_storage_migration_v1';

  final LocalDataStore database;
  final LocalDataScope scope;
  final Duration ioTimeout;
  final LegacySecureKeyStore _secureStore;
  final LocalMutationQueueStore _queue;
  final LocalOrderOfflineStore _orderStore;
  final LocalRouteSelectionStore _routeSelection;

  String get _sharedQueueKey => 'mcp.mutation_queue.${scope.key}';
  String get _legacyOrderQueueKey => 'mcp.orders.mutations.${scope.key}';
  String get _draftsKey => 'mcp.orders.drafts.${scope.key}';
  String get _routeSelectionKey => 'mcp.selected_route.${scope.key}';

  Future<void> run() async {
    final completed = await database.readMetadata(
      scope: scope,
      key: migrationMetadataKey,
    );
    if (completed == 'done') return;

    final raw = <String, String?>{};
    try {
      for (final key in _legacyKeys) {
        raw[key] = await _secureStore.read(key).timeout(ioTimeout);
      }
    } catch (error) {
      throw LegacyStorageMigrationFailure(
        'Không đọc được dữ liệu chờ gửi của phiên bản cũ. '
        'Dữ liệu cũ vẫn được giữ nguyên để tránh mất thao tác.',
        cause: error,
      );
    }

    final sharedMutations = _parseSharedMutations(raw[_sharedQueueKey]);
    final legacyOrders = _parseLegacyOrders(raw[_legacyOrderQueueKey]);
    final drafts = _parseDrafts(raw[_draftsKey]);
    final routeId = (raw[_routeSelectionKey] ?? '').trim();

    try {
      for (final mutation in sharedMutations) {
        await _queue.save(mutation);
      }
      for (final mutation in legacyOrders) {
        await _orderStore.saveMutation(mutation);
      }
      for (final draft in drafts) {
        await _orderStore.saveDraft(draft);
      }
      if (routeId.isNotEmpty) {
        await _routeSelection.save(routeId);
      }
    } catch (error) {
      throw LegacyStorageMigrationFailure(
        'Chưa chuyển được dữ liệu chờ gửi sang bộ nhớ mới. '
        'Dữ liệu phiên bản cũ chưa bị xóa.',
        cause: error,
      );
    }

    try {
      for (final key in _legacyKeys) {
        if ((raw[key] ?? '').isNotEmpty) {
          await _secureStore.delete(key).timeout(ioTimeout);
        }
      }
    } catch (error) {
      throw LegacyStorageMigrationFailure(
        'Đã sao chép dữ liệu chờ gửi nhưng chưa dọn được bộ nhớ cũ. '
        'Ứng dụng sẽ thử lại để bảo đảm không mất dữ liệu.',
        cause: error,
      );
    }

    await database.writeMetadata(
      scope: scope,
      key: migrationMetadataKey,
      value: 'done',
    );
  }

  List<String> get _legacyKeys => [
    _sharedQueueKey,
    _legacyOrderQueueKey,
    _draftsKey,
    _routeSelectionKey,
  ];

  List<QueuedMutation> _parseSharedMutations(String? raw) {
    final decoded = _decodeOptionalList(raw, 'hàng chờ gửi');
    return decoded.map((value) {
      final mutation = QueuedMutation.fromJson(value);
      if (mutation == null) {
        throw const LegacyStorageMigrationFailure(
          'Dữ liệu hàng chờ gửi của phiên bản cũ không hợp lệ. '
          'Ứng dụng chưa xóa dữ liệu cũ.',
        );
      }
      return mutation;
    }).toList(growable: false);
  }

  List<QueuedOrderMutation> _parseLegacyOrders(String? raw) {
    final decoded = _decodeOptionalList(raw, 'đơn chờ gửi');
    return decoded.map((value) {
      final mutation = QueuedOrderMutation.fromJson(value);
      if (mutation == null) {
        throw const LegacyStorageMigrationFailure(
          'Dữ liệu đơn chờ gửi của phiên bản cũ không hợp lệ. '
          'Ứng dụng chưa xóa dữ liệu cũ.',
        );
      }
      return mutation;
    }).toList(growable: false);
  }

  List<OrderDraft> _parseDrafts(String? raw) {
    if ((raw ?? '').trim().isEmpty) return const [];
    final decoded = _decodeJson(raw!, 'đơn đang soạn');
    if (decoded is! Map) {
      throw const LegacyStorageMigrationFailure(
        'Dữ liệu đơn đang soạn của phiên bản cũ không đúng định dạng.',
      );
    }
    final drafts = <OrderDraft>[];
    for (final value in decoded.values) {
      final draft = OrderDraft.fromJson(value);
      if (draft == null) {
        throw const LegacyStorageMigrationFailure(
          'Có đơn đang soạn của phiên bản cũ không hợp lệ. '
          'Ứng dụng chưa xóa dữ liệu cũ.',
        );
      }
      drafts.add(draft);
    }
    return drafts;
  }

  List<Object?> _decodeOptionalList(String? raw, String label) {
    if ((raw ?? '').trim().isEmpty) return const [];
    final decoded = _decodeJson(raw!, label);
    if (decoded is! List) {
      throw LegacyStorageMigrationFailure(
        'Dữ liệu $label của phiên bản cũ không đúng định dạng.',
      );
    }
    return decoded.cast<Object?>();
  }

  Object? _decodeJson(String raw, String label) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw LegacyStorageMigrationFailure(
        'Dữ liệu $label của phiên bản cũ bị hỏng. '
        'Ứng dụng chưa xóa dữ liệu cũ.',
        cause: error,
      );
    }
  }
}
