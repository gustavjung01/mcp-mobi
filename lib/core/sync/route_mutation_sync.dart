import '../data/field_data_client.dart';
import '../idempotency/canonical_idempotency.dart';
import '../location/field_location.dart';
import 'mutation_queue.dart';

enum RouteMutationSubmitStatus {
  completed,
  queued,
}

class RouteMutationSubmitResult {
  const RouteMutationSubmitResult({
    required this.status,
    this.addedCustomer,
  });

  final RouteMutationSubmitStatus status;
  final FieldAddedCustomer? addedCustomer;
}

class RouteMutationSubmissionService {
  const RouteMutationSubmissionService({
    required this.client,
    required this.queue,
  });

  final FieldActionClient client;
  final MutationQueueStore queue;

  Future<RouteMutationSubmitResult> openSession({
    required String routeId,
    required DateTime date,
    required String owner,
    required String routeName,
  }) async {
    final normalizedRouteId = routeId.trim();
    if (normalizedRouteId.isEmpty) {
      throw const FieldDataFailure(
        code: 'ROUTE_REQUIRED',
        message: 'Chưa xác định được tuyến cần bắt đầu.',
      );
    }

    final existing = await _findOutstanding(
      operation: 'route-session.open',
      matches: (payload) {
        if (_text(payload['routeId']) != normalizedRouteId) return false;
        final queuedDate = DateTime.tryParse(_text(payload['date']));
        if (queuedDate == null) return false;
        return queuedDate.year == date.year &&
            queuedDate.month == date.month &&
            queuedDate.day == date.day;
      },
    );
    final mutation = existing ??
        QueuedMutation(
          idempotencyKey: CanonicalIdempotencyKey.create('route-session.open'),
          operation: 'route-session.open',
          entityType: 'route_session',
          entityLabel:
              routeName.trim().isEmpty ? 'Tuyến làm việc' : routeName.trim(),
          payload: <String, Object?>{
            'routeId': normalizedRouteId,
            'date': date.toIso8601String(),
            'owner': owner.trim(),
          },
          createdAt: DateTime.now().toUtc(),
        );
    if (existing == null) await _saveInitial(mutation);

    final queuedDate =
        DateTime.tryParse(_text(mutation.payload['date'])) ?? date;
    final queuedOwner = _text(mutation.payload['owner']).isEmpty
        ? owner
        : _text(mutation.payload['owner']);
    try {
      await client.openRouteSession(
        routeId: normalizedRouteId,
        date: queuedDate,
        owner: queuedOwner,
        idempotencyKey: mutation.idempotencyKey,
      );
      await _acknowledgeBestEffort(mutation, normalizedRouteId);
      return const RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<RouteMutationSubmitResult> finishSession({
    required String sessionId,
    required String routeName,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const FieldDataFailure(
        code: 'SESSION_REQUIRED',
        message: 'Chưa xác định được phiên cần kết thúc.',
      );
    }

    final existing = await _findOutstanding(
      operation: 'route-session.update',
      matches: (payload) =>
          _text(payload['sessionId']) == normalizedSessionId &&
          _text(payload['status']) == 'done',
    );
    final mutation = existing ??
        QueuedMutation(
          idempotencyKey:
              CanonicalIdempotencyKey.create('route-session.update'),
          operation: 'route-session.update',
          entityType: 'route_session',
          entityLabel:
              routeName.trim().isEmpty ? 'Tuyến làm việc' : routeName.trim(),
          payload: <String, Object?>{
            'sessionId': normalizedSessionId,
            'status': 'done',
          },
          createdAt: DateTime.now().toUtc(),
        );
    if (existing == null) await _saveInitial(mutation);

    try {
      await client.finishRouteSession(
        sessionId: normalizedSessionId,
        idempotencyKey: mutation.idempotencyKey,
      );
      await _acknowledgeBestEffort(mutation, normalizedSessionId);
      return const RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<RouteMutationSubmitResult> updateLocation({
    required String routeCustomerId,
    required String customerName,
    required FieldLocation location,
  }) async {
    final normalizedId = routeCustomerId.trim();
    if (normalizedId.isEmpty) {
      throw const FieldDataFailure(
        code: 'ROUTE_CUSTOMER_REQUIRED',
        message: 'Chưa xác định được điểm bán cần cập nhật vị trí.',
      );
    }

    final key = CanonicalIdempotencyKey.create('route-customer.update');
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: 'route-customer.update',
      entityType: 'route_customer',
      entityLabel: customerName.trim().isEmpty ? 'Điểm bán' : customerName.trim(),
      payload: <String, Object?>{
        'routeCustomerId': normalizedId,
        'geoLat': location.latitude,
        'geoLng': location.longitude,
        'geoAccuracy': location.accuracy,
      },
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      await client.updateRouteCustomerLocation(
        routeCustomerId: normalizedId,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        idempotencyKey: key,
      );
      await _acknowledgeBestEffort(mutation, normalizedId);
      return const RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<RouteMutationSubmitResult> setCheckIn({
    required FieldDayLine line,
    required bool checkedIn,
    FieldLocation? location,
  }) async {
    final sessionCustomerId = (line.sessionCustomerId ?? '').trim();
    if (sessionCustomerId.isEmpty) {
      throw const FieldDataFailure(
        code: 'SESSION_CUSTOMER_REQUIRED',
        message: 'Điểm bán chưa thuộc phiên đi tuyến hiện tại.',
      );
    }
    if (checkedIn && location == null) {
      throw const FieldDataFailure(
        code: 'LOCATION_REQUIRED',
        message: 'Cần lấy vị trí hiện tại để check-in điểm bán.',
      );
    }

    final key = CanonicalIdempotencyKey.create(
      'session-customer.checkin.set',
    );
    final payload = <String, Object?>{
      'sessionCustomerId': sessionCustomerId,
      'checkedIn': checkedIn,
      if (checkedIn) 'geoLat': location!.latitude,
      if (checkedIn) 'geoLng': location!.longitude,
      if (checkedIn) 'geoAccuracy': location!.accuracy,
    };
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: 'session-customer.checkin.set',
      entityType: 'checkin',
      entityLabel: line.accountName,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      await client.setSessionCustomerCheckIn(
        sessionCustomerId: sessionCustomerId,
        checkedIn: checkedIn,
        latitude: checkedIn ? location!.latitude : null,
        longitude: checkedIn ? location!.longitude : null,
        accuracy: checkedIn ? location!.accuracy : null,
        idempotencyKey: key,
      );
      await _acknowledgeBestEffort(mutation, sessionCustomerId);
      return const RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<RouteMutationSubmitResult> skip({
    required FieldDayLine line,
    required String reason,
    String note = '',
  }) async {
    final sessionCustomerId = (line.sessionCustomerId ?? '').trim();
    final normalizedReason = reason.trim();
    if (sessionCustomerId.isEmpty) {
      throw const FieldDataFailure(
        code: 'SESSION_CUSTOMER_REQUIRED',
        message: 'Điểm bán chưa thuộc phiên đi tuyến hiện tại.',
      );
    }
    if (normalizedReason.isEmpty) {
      throw const FieldDataFailure(
        code: 'STATUS_REASON_REQUIRED',
        message: 'Cần nhập lý do bỏ qua điểm bán.',
      );
    }

    final key = CanonicalIdempotencyKey.create(
      'session-customer.status.update',
    );
    final normalizedNote = note.trim();
    final payload = <String, Object?>{
      'sessionCustomerId': sessionCustomerId,
      'visitStatus': 'skipped',
      'statusReason': normalizedReason,
      if (normalizedNote.isNotEmpty) 'note': normalizedNote,
    };
    final mutation = QueuedMutation(
      idempotencyKey: key,
      operation: 'session-customer.status.update',
      entityType: 'visit_status',
      entityLabel: line.accountName,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      await client.setSessionCustomerStatus(
        sessionCustomerId: sessionCustomerId,
        visitStatus: 'skipped',
        statusReason: normalizedReason,
        note: normalizedNote,
        idempotencyKey: key,
      );
      await _acknowledgeBestEffort(mutation, sessionCustomerId);
      return const RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<RouteMutationSubmitResult> addCustomer({
    required String sessionId,
    required String customerName,
    required String phone,
    required String area,
    required String address,
    required String note,
    FieldLocation? location,
    required String idempotencyKey,
  }) async {
    final normalizedName = customerName.trim();
    if (normalizedName.isEmpty) {
      throw const FieldDataFailure(
        code: 'CUSTOMER_NAME_REQUIRED',
        message: 'Cần nhập tên điểm bán.',
      );
    }

    final payload = <String, Object?>{
      'sessionId': sessionId,
      'customerName': normalizedName,
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (area.trim().isNotEmpty) 'area': area.trim(),
      if (address.trim().isNotEmpty) 'address': address.trim(),
      if (note.trim().isNotEmpty) 'note': note.trim(),
      if (location != null) 'geoLat': location.latitude,
      if (location != null) 'geoLng': location.longitude,
      if (location != null) 'geoAccuracy': location.accuracy,
    };
    final mutation = QueuedMutation(
      idempotencyKey: idempotencyKey,
      operation: 'session-customer.add',
      entityType: 'route_customer',
      entityLabel: normalizedName,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await _saveInitial(mutation);

    try {
      final added = await client.addSessionCustomer(
        sessionId: sessionId,
        customerName: normalizedName,
        phone: phone,
        area: area,
        address: address,
        note: note,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
        idempotencyKey: idempotencyKey,
      );
      await _acknowledgeBestEffort(mutation, added.sessionCustomerId);
      return RouteMutationSubmitResult(
        status: RouteMutationSubmitStatus.completed,
        addedCustomer: added,
      );
    } on FieldDataFailure catch (failure) {
      return _handleFailure(mutation, failure);
    }
  }

  Future<QueuedMutation?> _findOutstanding({
    required String operation,
    required bool Function(Map<String, Object?> payload) matches,
  }) async {
    try {
      final rows = await queue.load(operations: {operation});
      for (final row in rows) {
        if (!row.isOutstanding) continue;
        if (matches(row.payload)) return row;
      }
      return null;
    } catch (_) {
      throw const FieldDataFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không đọc được thao tác chờ gửi trên thiết bị.',
      );
    }
  }

  Future<void> _saveInitial(QueuedMutation mutation) async {
    try {
      await queue.save(mutation);
    } catch (_) {
      throw const FieldDataFailure(
        code: 'LOCAL_QUEUE_UNAVAILABLE',
        message: 'Không lưu được thao tác trên thiết bị. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _acknowledgeBestEffort(
    QueuedMutation mutation,
    String? reference,
  ) async {
    try {
      await queue.save(mutation.acknowledged(reference));
    } catch (_) {
      // Máy chủ đã nhận canonical intent; replay cùng key vẫn an toàn.
    }
  }

  Future<RouteMutationSubmitResult> _handleFailure(
    QueuedMutation mutation,
    FieldDataFailure failure,
  ) async {
    if (!failure.retryable) {
      try {
        await queue.remove(mutation.idempotencyKey);
      } catch (_) {
        // Không thay đổi quyết định từ chối của máy chủ.
      }
      throw failure;
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
        message: 'Chưa lưu được thao tác chờ gửi. Vui lòng thử lại.',
      );
    }
    return const RouteMutationSubmitResult(
      status: RouteMutationSubmitStatus.queued,
    );
  }
}

class RouteMutationSyncResult {
  const RouteMutationSyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int remaining;
}

class RouteMutationSyncService {
  const RouteMutationSyncService({
    required this.client,
    required this.queue,
  });

  final FieldActionClient client;
  final MutationQueueStore queue;

  static const operations = <String>{
    'route-session.open',
    'route-session.update',
    'route-customer.update',
    'session-customer.checkin.set',
    'session-customer.status.update',
    'session-customer.add',
  };

  Future<RouteMutationSyncResult> syncPending() async {
    final mutations = await queue.load(operations: operations);
    var sent = 0;
    var failed = 0;

    for (final mutation in mutations) {
      if (!mutation.isOutstanding) continue;
      if (mutation.state == MutationQueueState.failed && !mutation.retryable) {
        continue;
      }

      try {
        final reference = await _replay(mutation);
        await queue.save(mutation.acknowledged(reference));
        sent += 1;
      } on FieldDataFailure catch (failure) {
        await queue.save(
          mutation.failed(
            code: failure.code,
            message: failure.message,
            retryable: failure.retryable,
          ),
        );
        failed += 1;
      }
    }

    final remaining = (await queue.load(operations: operations))
        .where((item) => item.isOutstanding)
        .length;
    return RouteMutationSyncResult(
      sent: sent,
      failed: failed,
      remaining: remaining,
    );
  }

  Future<String?> _replay(QueuedMutation mutation) async {
    final payload = mutation.payload;
    switch (mutation.operation) {
      case 'route-session.open':
        final routeId = _requiredText(payload['routeId'], 'ROUTE_REQUIRED');
        final dateValue = _requiredText(payload['date'], 'SESSION_DATE_REQUIRED');
        final date = DateTime.tryParse(dateValue);
        if (date == null) {
          throw const FieldDataFailure(
            code: 'SESSION_DATE_INVALID',
            message: 'Ngày bắt đầu tuyến chờ gửi chưa hợp lệ.',
          );
        }
        await client.openRouteSession(
          routeId: routeId,
          date: date,
          owner: _text(payload['owner']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return routeId;
      case 'route-session.update':
        final sessionId = _requiredText(payload['sessionId'], 'SESSION_REQUIRED');
        await client.finishRouteSession(
          sessionId: sessionId,
          idempotencyKey: mutation.idempotencyKey,
        );
        return sessionId;
      case 'route-customer.update':
        final routeCustomerId = _requiredText(
          payload['routeCustomerId'],
          'ROUTE_CUSTOMER_REQUIRED',
        );
        await client.updateRouteCustomerLocation(
          routeCustomerId: routeCustomerId,
          latitude: _requiredDouble(payload['geoLat']),
          longitude: _requiredDouble(payload['geoLng']),
          accuracy: _requiredDouble(payload['geoAccuracy']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return routeCustomerId;
      case 'session-customer.checkin.set':
        final sessionCustomerId = _requiredText(
          payload['sessionCustomerId'],
          'SESSION_CUSTOMER_REQUIRED',
        );
        final checkedIn = payload['checkedIn'] == true;
        final latitude = checkedIn ? _requiredDouble(payload['geoLat']) : null;
        final longitude = checkedIn ? _requiredDouble(payload['geoLng']) : null;
        final accuracy = checkedIn
            ? _requiredDouble(payload['geoAccuracy'])
            : null;
        await client.setSessionCustomerCheckIn(
          sessionCustomerId: sessionCustomerId,
          checkedIn: checkedIn,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          idempotencyKey: mutation.idempotencyKey,
        );
        return sessionCustomerId;
      case 'session-customer.status.update':
        final sessionCustomerId = _requiredText(
          payload['sessionCustomerId'],
          'SESSION_CUSTOMER_REQUIRED',
        );
        await client.setSessionCustomerStatus(
          sessionCustomerId: sessionCustomerId,
          visitStatus: _requiredText(
            payload['visitStatus'],
            'VISIT_STATUS_REQUIRED',
          ),
          statusReason: _nullableText(payload['statusReason']),
          note: _nullableText(payload['note']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return sessionCustomerId;
      case 'session-customer.add':
        final added = await client.addSessionCustomer(
          sessionId: _requiredText(payload['sessionId'], 'SESSION_REQUIRED'),
          customerName: _requiredText(
            payload['customerName'],
            'CUSTOMER_NAME_REQUIRED',
          ),
          phone: _text(payload['phone']),
          area: _text(payload['area']),
          address: _text(payload['address']),
          note: _text(payload['note']),
          latitude: _optionalDouble(payload['geoLat']),
          longitude: _optionalDouble(payload['geoLng']),
          accuracy: _optionalDouble(payload['geoAccuracy']),
          idempotencyKey: mutation.idempotencyKey,
        );
        return added.sessionCustomerId;
      default:
        throw const FieldDataFailure(
          code: 'LOCAL_QUEUE_INVALID',
          message: 'Thao tác chờ gửi không hợp lệ.',
        );
    }
  }
}

String _text(Object? value) => (value ?? '').toString().trim();

String? _nullableText(Object? value) {
  final valueText = _text(value);
  return valueText.isEmpty ? null : valueText;
}

String _requiredText(Object? value, String code) {
  final valueText = _text(value);
  if (valueText.isEmpty) {
    throw FieldDataFailure(
      code: code,
      message: 'Dữ liệu thao tác chờ gửi chưa đầy đủ.',
    );
  }
  return valueText;
}

double _requiredDouble(Object? value) {
  final parsed = _optionalDouble(value);
  if (parsed == null) {
    throw const FieldDataFailure(
      code: 'LOCATION_REQUIRED',
      message: 'Dữ liệu vị trí chờ gửi chưa đầy đủ.',
    );
  }
  return parsed;
}

double? _optionalDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}
