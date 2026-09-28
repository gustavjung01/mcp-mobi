import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDataFailure implements Exception {
  const LocalDataFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class LocalDataScope {
  const LocalDataScope({
    required this.installationKey,
    required this.employeeId,
  });

  final String installationKey;
  final String employeeId;

  String get key => base64Url
      .encode(utf8.encode('$installationKey|$employeeId'))
      .replaceAll('=', '');
}

class CatalogCacheState {
  const CatalogCacheState({
    required this.count,
    this.refreshedAt,
  });

  final int count;
  final DateTime? refreshedAt;

  bool isStale(Duration maxAge, {DateTime? now}) {
    final refreshed = refreshedAt;
    if (count <= 0 || refreshed == null) return true;
    return (now ?? DateTime.now().toUtc()).difference(refreshed.toUtc()) >
        maxAge;
  }
}

class LocalDataStore {
  LocalDataStore({
    DatabaseFactory? factory,
    String? databasePath,
  })  : _factory = factory ?? databaseFactory,
        _databasePath = databasePath;

  static final LocalDataStore shared = LocalDataStore();

  static const _schemaVersion = 1;
  static const _databaseFileName = 'mcp_field_local_v1.db';
  static const _catalogRefreshedKey = 'catalog_refreshed_at';

  final DatabaseFactory _factory;
  final String? _databasePath;
  Future<Database>? _databaseFuture;

  Future<Database> _database() {
    return _databaseFuture ??= _open();
  }

  Future<Database> _open() async {
    final path = _databasePath ??
        p.join(await getDatabasesPath(), _databaseFileName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE local_metadata (
  scope TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (scope, key)
)
''');
    await db.execute('''
CREATE TABLE mutation_queue (
  scope TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  operation TEXT NOT NULL,
  state TEXT NOT NULL,
  created_at TEXT NOT NULL,
  record_json TEXT NOT NULL,
  PRIMARY KEY (scope, idempotency_key)
)
''');
    await db.execute(
      'CREATE INDEX mutation_queue_scope_operation '
      'ON mutation_queue(scope, operation, created_at)',
    );
    await db.execute(
      'CREATE INDEX mutation_queue_scope_state '
      'ON mutation_queue(scope, state, created_at)',
    );
    await db.execute('''
CREATE TABLE order_drafts (
  scope TEXT NOT NULL,
  outlet_id TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  record_json TEXT NOT NULL,
  PRIMARY KEY (scope, outlet_id)
)
''');
    await db.execute('''
CREATE TABLE route_selection (
  scope TEXT PRIMARY KEY NOT NULL,
  route_id TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE catalog_items (
  scope TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  sku TEXT,
  search_text TEXT NOT NULL,
  brand_search TEXT NOT NULL,
  category_search TEXT NOT NULL,
  refreshed_at TEXT NOT NULL,
  record_json TEXT NOT NULL,
  PRIMARY KEY (scope, variant_id)
)
''');
    await db.execute(
      'CREATE INDEX catalog_items_scope_search '
      'ON catalog_items(scope, search_text)',
    );
    await db.execute(
      'CREATE INDEX catalog_items_scope_filters '
      'ON catalog_items(scope, category_search, brand_search)',
    );
  }

  Future<void> dispose() async {
    final future = _databaseFuture;
    _databaseFuture = null;
    if (future != null) {
      final db = await future;
      await db.close();
    }
  }

  Future<String?> readMetadata({
    required LocalDataScope scope,
    required String key,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'local_metadata',
      columns: const ['value'],
      where: 'scope = ? AND key = ?',
      whereArgs: [scope.key, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.single['value'] ?? '').toString();
  }

  Future<void> writeMetadata({
    required LocalDataScope scope,
    required String key,
    required String value,
  }) async {
    final db = await _database();
    await db.insert(
      'local_metadata',
      {
        'scope': scope.key,
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> loadMutationRecords({
    required LocalDataScope scope,
    Set<String>? operations,
  }) async {
    final db = await _database();
    final operationList = operations?.where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    final where = <String>['scope = ?'];
    final args = <Object?>[scope.key];
    if (operationList != null && operationList.isNotEmpty) {
      where.add(
        'operation IN (${List.filled(operationList.length, '?').join(',')})',
      );
      args.addAll(operationList);
    }
    final rows = await db.query(
      'mutation_queue',
      columns: const ['record_json'],
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at ASC',
    );
    return rows
        .map((row) => _decodeRecord(row['record_json'], 'LOCAL_QUEUE_CORRUPT'))
        .toList(growable: false);
  }

  Future<void> saveMutationRecord({
    required LocalDataScope scope,
    required String idempotencyKey,
    required String operation,
    required String state,
    required DateTime createdAt,
    required Map<String, Object?> record,
  }) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert(
        'mutation_queue',
        {
          'scope': scope.key,
          'idempotency_key': idempotencyKey,
          'operation': operation,
          'state': state,
          'created_at': createdAt.toUtc().toIso8601String(),
          'record_json': jsonEncode(record),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final acknowledged = await txn.query(
        'mutation_queue',
        columns: const ['idempotency_key'],
        where: 'scope = ? AND state = ?',
        whereArgs: [scope.key, 'acknowledged'],
        orderBy: 'created_at DESC',
      );
      if (acknowledged.length > 30) {
        final stale = acknowledged.skip(30);
        final batch = txn.batch();
        for (final row in stale) {
          batch.delete(
            'mutation_queue',
            where: 'scope = ? AND idempotency_key = ?',
            whereArgs: [scope.key, row['idempotency_key']],
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> removeMutation({
    required LocalDataScope scope,
    required String idempotencyKey,
  }) async {
    final db = await _database();
    await db.delete(
      'mutation_queue',
      where: 'scope = ? AND idempotency_key = ?',
      whereArgs: [scope.key, idempotencyKey],
    );
  }

  Future<Map<String, dynamic>?> readDraft({
    required LocalDataScope scope,
    required String outletId,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'order_drafts',
      columns: const ['record_json'],
      where: 'scope = ? AND outlet_id = ?',
      whereArgs: [scope.key, outletId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeRecord(rows.single['record_json'], 'LOCAL_DRAFT_CORRUPT');
  }

  Future<void> saveDraft({
    required LocalDataScope scope,
    required String outletId,
    required DateTime updatedAt,
    required Map<String, Object?> record,
  }) async {
    final db = await _database();
    await db.insert(
      'order_drafts',
      {
        'scope': scope.key,
        'outlet_id': outletId,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'record_json': jsonEncode(record),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDraft({
    required LocalDataScope scope,
    required String outletId,
  }) async {
    final db = await _database();
    await db.delete(
      'order_drafts',
      where: 'scope = ? AND outlet_id = ?',
      whereArgs: [scope.key, outletId],
    );
  }

  Future<String?> loadRouteSelection(LocalDataScope scope) async {
    final db = await _database();
    final rows = await db.query(
      'route_selection',
      columns: const ['route_id'],
      where: 'scope = ?',
      whereArgs: [scope.key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final routeId = (rows.single['route_id'] ?? '').toString().trim();
    return routeId.isEmpty ? null : routeId;
  }

  Future<void> saveRouteSelection({
    required LocalDataScope scope,
    required String routeId,
  }) async {
    final value = routeId.trim();
    if (value.isEmpty) {
      await clearRouteSelection(scope);
      return;
    }
    final db = await _database();
    await db.insert(
      'route_selection',
      {
        'scope': scope.key,
        'route_id': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRouteSelection(LocalDataScope scope) async {
    final db = await _database();
    await db.delete(
      'route_selection',
      where: 'scope = ?',
      whereArgs: [scope.key],
    );
  }

  Future<void> replaceCatalog({
    required LocalDataScope scope,
    required List<Map<String, Object?>> records,
    required DateTime refreshedAt,
  }) async {
    final db = await _database();
    final timestamp = refreshedAt.toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'catalog_items',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      final batch = txn.batch();
      for (final record in records) {
        final variantId = _text(record['variantId']);
        final productId = _text(record['productId']);
        final name = _text(record['name']);
        if (variantId.isEmpty || productId.isEmpty || name.isEmpty) {
          throw const LocalDataFailure(
            code: 'LOCAL_CATALOG_INVALID',
            message: 'Danh mục sản phẩm có dữ liệu chưa hợp lệ.',
          );
        }
        final brand = _nullableText(record['brand']);
        final category = _nullableText(record['category']);
        final sku = _nullableText(record['sku']);
        final searchText = normalizeLocalSearch(
          [
            name,
            sku,
            brand,
            category,
            _nullableText(record['variantName']),
            _nullableText(record['sellUnit']),
          ].whereType<String>().join(' '),
        );
        batch.insert(
          'catalog_items',
          {
            'scope': scope.key,
            'variant_id': variantId,
            'product_id': productId,
            'name': name,
            'brand': brand,
            'category': category,
            'sku': sku,
            'search_text': searchText,
            'brand_search': normalizeLocalSearch(brand ?? ''),
            'category_search': normalizeLocalSearch(category ?? ''),
            'refreshed_at': timestamp,
            'record_json': jsonEncode(record),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      await txn.insert(
        'local_metadata',
        {
          'scope': scope.key,
          'key': _catalogRefreshedKey,
          'value': timestamp,
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<CatalogCacheState> catalogState(LocalDataScope scope) async {
    final db = await _database();
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS item_count FROM catalog_items WHERE scope = ?',
      [scope.key],
    );
    final count = _intValue(countRows.single['item_count']);
    final refreshed = await readMetadata(
      scope: scope,
      key: _catalogRefreshedKey,
    );
    return CatalogCacheState(
      count: count,
      refreshedAt: DateTime.tryParse(refreshed ?? ''),
    );
  }

  Future<List<Map<String, dynamic>>> searchCatalog({
    required LocalDataScope scope,
    required String query,
    String? category,
    String? brand,
    int limit = 100,
  }) async {
    final db = await _database();
    final where = <String>['scope = ?'];
    final args = <Object?>[scope.key];

    final normalizedQuery = normalizeLocalSearch(query);
    if (normalizedQuery.isNotEmpty) {
      where.add('search_text LIKE ?');
      args.add('%$normalizedQuery%');
    }
    final normalizedCategory = normalizeLocalSearch(category ?? '');
    if (normalizedCategory.isNotEmpty) {
      where.add('category_search = ?');
      args.add(normalizedCategory);
    }
    final normalizedBrand = normalizeLocalSearch(brand ?? '');
    if (normalizedBrand.isNotEmpty) {
      where.add('brand_search = ?');
      args.add(normalizedBrand);
    }

    final rows = await db.query(
      'catalog_items',
      columns: const ['record_json'],
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC, sku COLLATE NOCASE ASC',
      limit: limit.clamp(1, 500) as int,
    );
    return rows
        .map((row) => _decodeRecord(row['record_json'], 'LOCAL_CATALOG_CORRUPT'))
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeRecord(Object? value, String code) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) {
      throw LocalDataFailure(
        code: code,
        message: 'Dữ liệu lưu trên thiết bị bị thiếu.',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, item) => MapEntry(key.toString(), item),
        );
      }
    } on FormatException catch (error) {
      throw LocalDataFailure(
        code: code,
        message: 'Dữ liệu lưu trên thiết bị bị hỏng.',
        cause: error,
      );
    }
    throw LocalDataFailure(
      code: code,
      message: 'Dữ liệu lưu trên thiết bị không đúng định dạng.',
    );
  }
}

String normalizeLocalSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp('[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp('[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim();
}

String _text(Object? value) => (value ?? '').toString().trim();

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}
