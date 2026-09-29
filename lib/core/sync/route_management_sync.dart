import 'dart:convert';

import '../data/field_data_client.dart';
import '../data/route_management_client.dart';
import '../idempotency/canonical_idempotency.dart';
import 'mutation_queue.dart';

enum RouteManagementSubmitStatus {
  completed,
  queued,
}

class RouteManagementSubmissionService {
  const RouteManagementSubmissionService({
    required this.client,
    required this.queue,
  });

  final RouteManagementClient client;
  final MutationQueueStore queue;

  Future<RouteManagementSubmitStatus> createRoute({
    required String routeName,
    required String area,
    int? weekday,
    String note = '',
  }) {
    final payload = <String, Object?>{
      'routeName': routeName.trim(),
      'area': area.trim(),
      'note': note.trim(),
    };
    if (weekday != null) payload['weekday'] = weekday;
    return _submit(
      operation: 'mcp.route.create',
      entityType: 'route',
      entityLabel: routeName.trim().isEmpty ? 'Tuyến cố định' : routeName.trim(),
      payload: payload,
      send: (mutation) => client.createRoute(
        routeName: _text(mutation.payload['routeName']),
        area: _text(mutation.payload['area']),
        weekday: _optionalInt(mutation.payload['weekday']),
        note: _text(mutation.payload['note']),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> updateRoute({
    required String routeId,
    required String routeName,
    required String area,
    int? weekday,
    String note = '',
  }) {
    final payload = <String, Object?>{
      'routeId': routeId.trim(),
      'routeName': routeName.trim(),
      'area': area.trim(),
      'note': note.trim(),
    };
    if (weekday != null) payload['weekday'] = weekday;
    return _submit(
      operation: 'mcp.route.update',
      entityType: 'route',
      entityLabel: routeName.trim().isEmpty ? 'Tuyến cố định' : routeName.trim(),
      payload: payload,
      send: (mutation) => client.updateRoute(
        routeId: _required(mutation.payload['routeId'], 'ROUTE_REQUIRED'),
        routeName: _text(mutation.payload['routeName']),
        area: _text(mutation.payload['area']),
        weekday: _optionalInt(mutation.payload['weekday']),
        note: _text(mutation.payload['note']),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> archiveRoute({
    required String routeId,
    required String routeName,
  }) {
    final payload = <String, Object?>{'routeId': routeId.trim()};
    return _submit(
      operation: 'mcp.route.archive',
      entityType: 'route',
      entityLabel: routeName.trim().isEmpty ? 'Tuyến cố định' : routeName.trim(),
      payload: payload,
      send: (mutation) => client.archiveRoute(
        routeId: _required(mutation.payload['routeId'], 'ROUTE_REQUIRED'),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> addRouteCustomer({
    required String routeId,
    required String customerName,
    String phone = '',
    String area = '',
    String address = '',
    int? sortOrder,
    String note = '',
    bool includeActiveSession = false,
    String? activeSessionId,
  }) {
    final payload = <String, Object?>{
      'routeId': routeId.trim(),
      'customerName': customerName.trim(),
      'phone': phone.trim(),
      'area': area.trim(),
      'address': address.trim(),
      'note': note.trim(),
      'includeActiveSession': includeActiveSession,
    };
    if (sortOrder != null) payload['sortOrder'] = sortOrder;
    if ((activeSessionId ?? '').trim().isNotEmpty) {
      payload['activeSessionId'] = activeSessionId!.trim();
    }
    return _submit(
      operation: 'mcp.route-customer.create',
      entityType: 'route_customer',
      entityLabel: customerName.trim().isEmpty ? 'Điểm bán' : customerName.trim(),
      payload: payload,
      send: (mutation) => client.addRouteCustomer(
        routeId: _required(mutation.payload['routeId'], 'ROUTE_REQUIRED'),
        customerName: _required(
          mutation.payload['customerName'],
          'CUSTOMER_NAME_REQUIRED',
        ),
        phone: _text(mutation.payload['phone']),
        area: _text(mutation.payload['area']),
        address: _text(mutation.payload['address']),
        sortOrder: _optionalInt(mutation.payload['sortOrder']),
        note: _text(mutation.payload['note']),
        includeActiveSession: mutation.payload['includeActiveSession'] == true,
        activeSessionId: _nullableText(mutation.payload['activeSessionId']),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> updateRouteCustomer({
    required String routeCustomerId,
    required String customerName,
    required String phone,
    required String area,
    required String address,
    required int sortOrder,
    required String note,
  }) {
    final payload = <String, Object?>{
      'routeCustomerId': routeCustomerId.trim(),
      'customerName': customerName.trim(),
      'phone': phone.trim(),
      'area': area.trim(),
      'address': address.trim(),
      'sortOrder': sortOrder,
      'note': note.trim(),
    };
    return _submit(
      operation: 'mcp.route-customer.update',
      entityType: 'route_customer',
      entityLabel: customerName.trim().isEmpty ? 'Điểm bán' : customerName.trim(),
      payload: payload,
      send: (mutation) => client.updateRouteCustomer(
        routeCustomerId: _required(
          mutation.payload['routeCustomerId'],
          'ROUTE_CUSTOMER_REQUIRED',
        ),
        customerName: _text(mutation.payload['customerName']),
        phone: _text(mutation.payload['phone']),
        area: _text(mutation.payload['area']),
        address: _text(mutation.payload['address']),
        sortOrder: _optionalInt(mutation.payload['sortOrder']) ?? 0,
        note: _text(mutation.payload['note']),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> archiveRouteCustomer({
    required String routeCustomerId,
    required String customerName,
  }) {
    final payload = <String, Object?>{
      'routeCustomerId': routeCustomerId.trim(),
    };
    return _submit(
      operation: 'mcp.route-customer.archive',
      entityType: 'route_customer',
      entityLabel: customerName.trim().isEmpty ? 'Điểm bán' : customerName.trim(),
      payload: payload,
      send: (mutation) => client.archiveRouteCustomer(
        routeCustomerId: _required(
          mutation.payload['routeCustomerId'],
          'ROUTE_CUSTOMER_REQUIRED',
        ),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> cancelSession({
    required String sessionId,
    required String routeName,
    String note = '',
  }) {
    final payload = <String, Object?>{
      'sessionId': sessionId.trim(),
      'status': 'cancelled',
      'note': note.trim(),
    };
    return _submit(
      operation: 'mcp.session.update',
      entityType: 'route_session',
      entityLabel: routeName.trim().isEmpty ? 'Phiên đi tuyến' : routeName.trim(),
      payload: payload,
      send: (mutation) => client.updateSession(
        sessionId: _required(mutation.payload['sessionId'], 'SESSION_REQUIRED'),
        status: _text(mutation.payload['status']),
        note: _text(mutation.payload['note']),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> deleteEmptySession({
    required String sessionId,
    required String routeName,
  }) {
    final payload = <String, Object?>{'sessionId': sessionId.trim()};
    return _submit(
      operation: 'mcp.session.delete-empty',
      entityType: 'route_session',
      entityLabel: routeName.trim().isEmpty ? 'Phiên đi tuyến' : routeName.trim(),
      payload: payload,
      send: (mutation) => client.deleteEmptySession(
        sessionId: _required(mutation.payload['sessionId'], 'SESSION_REQUIRED'),
        idempotencyKey: mutation.idempotencyKey,
      ),
    );
  }

  Future<RouteManagementSubmitStatus> _submit({
    required String operation,
    required String entityType,
    required String entityLabel,
    required Map<String, Object?> payload,
    required Future<void> Function(QueuedMutation mutation) send,
  }) async {
    final existing = await _findOutstanding(operation, payload);
    final mutation = existing ??
        QueuedMutation(
          idempotencyKey: CanonicalIdempotencyKey.create(operation),
          operation: operation,
          entityType: entityType,
          entityLabel: entityLabel,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        );
    if (existing == null) await _save(mutation);

    try {
      await send(mutation);
      await _acknowledge(mutation);
      return RouteManagementSubmitStatus.completed;
    } on FieldDataFailure catch (failure) {
      if (!failure.retryable) {
        try {
          await queue.remove(mutation.idempotencyKey);
        } catch (_) {}
        rethrow;
      }
      try {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: true,
          ),
        );
      } catch (_) {
        throw const FieldDataFailure(
          code: 'LOCAL_QUEUE_UNAVAILABLE',
          message: 'Chưa lưu được thao tác chờ gửi trên thiết bị.',
        );
      }
      return RouteManagementSubmitStatus.queued;
    }
  }

  Future<QueuedMutation?> _findOutstanding(
    String operation,
    Map<String, Object?> payload,
  ) async {
    try {
      final rows = await queue.load(operations: {operation});
      final expected = jsonEncode(payload);
      for (final row in rows) {
        if (!row.isOutstanding) continue;
        if (jsonEncode(row.payload) == expected) return row;
      }
      return null;
    } catch (_) {
      throw const FieldDataFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không đọc được thao tác chờ gửi trên thiết bị.',
      );
    }
  }

  Future<void> _save(QueuedMutation mutation) async {
    try {
      await queue.save(mutation);
    } catch (_) {
      throw const FieldDataFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không lưu được thao tác trên thiết bị.',
      );
    }
  }

  Future<void> _acknowledge(QueuedMutation mutation) async {
    try {
      await queue.save(mutation.acknowledged(null));
    } catch (_) {
      // Server already accepted this canonical intent; replay remains safe.
    }
  }
}

class RouteManagementSyncService {
  const RouteManagementSyncService({
    required this.client,
    required this.queue,
  });

  final RouteManagementClient client;
  final MutationQueueStore queue;

  static const operations = <String>{
    'mcp.route.create',
    'mcp.route.update',
    'mcp.route.archive',
    'mcp.route-customer.create',
    'mcp.route-customer.update',
    'mcp.route-customer.archive',
    'mcp.session.update',
    'mcp.session.delete-empty',
  };

  Future<int> syncPending() async {
    final rows = await queue.load(operations: operations);
    var sent = 0;
    for (final mutation in rows) {
      if (!mutation.isOutstanding) continue;
      if (mutation.state == MutationQueueState.failed && !mutation.retryable) {
        continue;
      }
      try {
        await _replay(mutation);
        await queue.save(mutation.acknowledged(null));
        sent += 1;
      } on FieldDataFailure catch (failure) {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: failure.retryable,
          ),
        );
      }
    }
    return sent;
  }

  Future<void> _replay(QueuedMutation mutation) async {
    final p = mutation.payload;
    switch (mutation.operation) {
      case 'mcp.route.create':
        await client.createRoute(
          routeName: _required(p['routeName'], 'ROUTE_NAME_REQUIRED'),
          area: _text(p['area']),
          weekday: _optionalInt(p['weekday']),
          note: _text(p['note']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.route.update':
        await client.updateRoute(
          routeId: _required(p['routeId'], 'ROUTE_REQUIRED'),
          routeName: _text(p['routeName']),
          area: _text(p['area']),
          weekday: _optionalInt(p['weekday']),
          note: _text(p['note']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.route.archive':
        await client.archiveRoute(
          routeId: _required(p['routeId'], 'ROUTE_REQUIRED'),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.route-customer.create':
        await client.addRouteCustomer(
          routeId: _required(p['routeId'], 'ROUTE_REQUIRED'),
          customerName: _required(p['customerName'], 'CUSTOMER_NAME_REQUIRED'),
          phone: _text(p['phone']),
          area: _text(p['area']),
          address: _text(p['address']),
          sortOrder: _optionalInt(p['sortOrder']),
          note: _text(p['note']),
          includeActiveSession: p['includeActiveSession'] == true,
          activeSessionId: _nullableText(p['activeSessionId']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.route-customer.update':
        await client.updateRouteCustomer(
          routeCustomerId: _required(
            p['routeCustomerId'],
            'ROUTE_CUSTOMER_REQUIRED',
          ),
          customerName: _text(p['customerName']),
          phone: _text(p['phone']),
          area: _text(p['area']),
          address: _text(p['address']),
          sortOrder: _optionalInt(p['sortOrder']) ?? 0,
          note: _text(p['note']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.route-customer.archive':
        await client.archiveRouteCustomer(
          routeCustomerId: _required(
            p['routeCustomerId'],
            'ROUTE_CUSTOMER_REQUIRED',
          ),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.session.update':
        await client.updateSession(
          sessionId: _required(p['sessionId'], 'SESSION_REQUIRED'),
          status: _text(p['status']),
          note: _text(p['note']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

      case 'mcp.session.delete-empty':
        await client.deleteEmptySession(
          sessionId: _required(p['sessionId'], 'SESSION_REQUIRED'),
          idempotencyKey: mutation.idempotencyKey,
        );
        return;

    }
  }
}

String _required(Object? value, String code) {
  final normalized = _text(value);
  if (normalized.isEmpty) {
    throw FieldDataFailure(
      code: code,
      message: 'Dữ liệu thao tác chờ gửi chưa đầy đủ.',
    );
  }
  return normalized;
}

String _text(Object? value) => (value ?? '').toString().trim();

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int? _optionalInt(Object? value) {
  if (value == null || _text(value).isEmpty) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}
