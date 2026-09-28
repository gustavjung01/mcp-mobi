import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RouteSelectionStore {
  Future<String?> load();

  Future<void> save(String routeId);

  Future<void> clear();
}

class SecureRouteSelectionStore implements RouteSelectionStore {
  SecureRouteSelectionStore({
    required String installationKey,
    required String employeeId,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _scope = base64Url
           .encode(utf8.encode('$installationKey|$employeeId'))
           .replaceAll('=', '');

  final FlutterSecureStorage _storage;
  final String _scope;

  String get _key => 'mcp.selected_route.$_scope';

  @override
  Future<String?> load() async {
    try {
      final value = (await _storage.read(key: _key) ?? '').trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String routeId) async {
    final value = routeId.trim();
    if (value.isEmpty) {
      await clear();
      return;
    }
    await _storage.write(key: _key, value: value);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
