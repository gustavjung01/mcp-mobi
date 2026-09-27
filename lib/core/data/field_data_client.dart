import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_profile.dart';

class FieldDataFailure implements Exception {
  const FieldDataFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

class FieldRoute {
  const FieldRoute({
    required this.id,
    required this.name,
    required this.area,
    required this.salesOwner,
    required this.plannedCustomers,
    required this.visitedCustomers,
    required this.orderCount,
    required this.status,
  });

  final String id;
  final String name;
  final String area;
  final String salesOwner;
  final int plannedCustomers;
  final int visitedCustomers;
  final int orderCount;
  final String status;

  factory FieldRoute.fromJson(Map<String, dynamic> json) {
    return FieldRoute(
      id: _text(json['id']),
      name: _text(json['name'], fallback: 'Tuyến chưa có tên'),
      area: _text(json['area'], fallback: 'Chưa có khu vực'),
      salesOwner: _text(json['salesOwner']),
      plannedCustomers: _integer(json['plannedCustomers']),
      visitedCustomers: _integer(json['visitedCustomers']),
      orderCount: _integer(json['orderCount']),
      status: _text(json['status'], fallback: 'active'),
    );
  }
}

class FieldGps {
  const FieldGps({
    required this.lat,
    required this.lng,
    this.accuracyMeters,
    this.updatedAt,
  });

  final double lat;
  final double lng;
  final double? accuracyMeters;
  final String? updatedAt;

  factory FieldGps.fromJson(Map<String, dynamic> json) {
    return FieldGps(
      lat: _double(json['lat']),
      lng: _double(json['lng']),
      accuracyMeters: _optionalDouble(json['accuracyMeters']),
      updatedAt: _nullableText(json['updatedAt']),
    );
  }
}

class FieldRouteCustomer {
  const FieldRouteCustomer({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.accountId,
    required this.accountName,
    required this.contactName,
    required this.area,
    required this.sortOrder,
    required this.status,
    required this.note,
    this.gps,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String accountId;
  final String accountName;
  final String contactName;
  final String area;
  final int sortOrder;
  final String status;
  final String note;
  final FieldGps? gps;

  factory FieldRouteCustomer.fromJson(Map<String, dynamic> json) {
    final gpsJson = _object(json['gps']);
    return FieldRouteCustomer(
      id: _text(json['id']),
      routeId: _text(json['routeId']),
      routeName: _text(json['routeName']),
      accountId: _text(json['accountId']),
      accountName: _text(json['accountName'], fallback: 'Điểm bán'),
      contactName: _text(json['contactName']),
      area: _text(json['area'], fallback: 'Chưa có khu vực'),
      sortOrder: _integer(json['sortOrder']),
      status: _text(json['status'], fallback: 'active'),
      note: _text(json['note']),
      gps: gpsJson.isEmpty ? null : FieldGps.fromJson(gpsJson),
    );
  }
}

class FieldDayRun {
  const FieldDayRun({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.date,
    required this.owner,
    required this.status,
    required this.openedAt,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String date;
  final String owner;
  final String status;
  final String openedAt;

  factory FieldDayRun.fromJson(Map<String, dynamic> json) {
    return FieldDayRun(
      id: _text(json['id']),
      routeId: _text(json['routeId']),
      routeName: _text(json['routeName'], fallback: 'Tuyến làm việc'),
      date: _text(json['date']),
      owner: _text(json['owner']),
      status: _text(json['status'], fallback: 'cancelled'),
      openedAt: _text(json['openedAt']),
    );
  }
}

class FieldDayLine {
  const FieldDayLine({
    required this.id,
    required this.sortOrder,
    required this.accountName,
    required this.area,
    required this.source,
    required this.status,
    required this.note,
    required this.hasOrder,
    required this.hasTest,
    required this.hasReport,
    required this.followupCount,
    required this.checkedIn,
    this.sessionCustomerId,
    this.routeCustomerId,
    this.phone,
    this.address,
    this.checkinAt,
    this.checkinLat,
    this.checkinLng,
    this.checkinAccuracy,
  });

  final String id;
  final String? sessionCustomerId;
  final String? routeCustomerId;
  final int sortOrder;
  final String accountName;
  final String? phone;
  final String? address;
  final String area;
  final String source;
  final String status;
  final String note;
  final bool hasOrder;
  final bool hasTest;
  final bool hasReport;
  final int followupCount;
  final bool checkedIn;
  final String? checkinAt;
  final double? checkinLat;
  final double? checkinLng;
  final double? checkinAccuracy;

  factory FieldDayLine.fromJson(Map<String, dynamic> json) {
    return FieldDayLine(
      id: _text(json['id']),
      sessionCustomerId: _nullableText(json['sessionCustomerId']),
      routeCustomerId: _nullableText(json['routeCustomerId']),
      sortOrder: _integer(json['sortOrder']),
      accountName: _text(json['accountName'], fallback: 'Điểm bán'),
      phone: _nullableText(json['phone']),
      address: _nullableText(json['address']),
      area: _text(json['area'], fallback: 'Chưa có khu vực'),
      source: _text(json['source'], fallback: 'planned'),
      status: _text(json['status'], fallback: 'pending'),
      note: _text(json['note']),
      hasOrder: _boolean(json['hasOrder']),
      hasTest: _boolean(json['hasTest']),
      hasReport: _boolean(json['hasReport']),
      followupCount: _integer(json['followupCount']),
      checkedIn: _boolean(json['checkedIn']),
      checkinAt: _nullableText(json['checkinAt']),
      checkinLat: _optionalDouble(json['checkinLat']),
      checkinLng: _optionalDouble(json['checkinLng']),
      checkinAccuracy: _optionalDouble(json['checkinAccuracy']),
    );
  }
}

class FieldDayData {
  const FieldDayData({
    required this.sessionOpened,
    required this.run,
    required this.lines,
  });

  final bool sessionOpened;
  final FieldDayRun run;
  final List<FieldDayLine> lines;

  factory FieldDayData.fromJson(Map<String, dynamic> json) {
    return FieldDayData(
      sessionOpened: _boolean(json['sessionOpened']),
      run: FieldDayRun.fromJson(_object(json['run'])),
      lines: _objects(json['lines'])
          .map(FieldDayLine.fromJson)
          .where((line) => line.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class FieldRouteWorkspace {
  const FieldRouteWorkspace({
    required this.route,
    required this.customers,
    required this.day,
  });

  final FieldRoute route;
  final List<FieldRouteCustomer> customers;
  final FieldDayData day;
}

abstract interface class FieldDataClient {
  Future<List<FieldRoute>> loadRoutes();

  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  });
}

class HttpFieldDataClient implements FieldDataClient {
  HttpFieldDataClient({
    required this.profile,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final InstallationProfile profile;
  final String token;
  final http.Client _client;
  final Duration timeout;

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final base = profile.fieldBaseUrl.toString().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse(base + path);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  String _requestId() {
    return 'mobile_data_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    http.Response response;
    try {
      response = await _client
          .get(
            _endpoint(path, query),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'X-Request-Id': _requestId(),
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FieldDataFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const FieldDataFailure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Không tải được dữ liệu. Kiểm tra mạng và thử lại.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FieldDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
        retryable: true,
      );
    }

    final payload = _object(decoded);
    if (response.statusCode >= 400) {
      final error = _object(payload['error']);
      final code = _text(error['code'], fallback: 'REQUEST_FAILED');
      final serverMessage = _text(error['message']);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw FieldDataFailure(
          code: code,
          message: 'Phiên đăng nhập không còn hiệu lực.',
        );
      }
      throw FieldDataFailure(
        code: code,
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Không tải được dữ liệu. Vui lòng thử lại.',
        retryable: response.statusCode >= 500 || error['retryable'] == true,
      );
    }

    if (payload['data'] is! Map) {
      throw const FieldDataFailure(
        code: 'RESPONSE_INVALID',
        message: 'Hệ thống trả về dữ liệu không hợp lệ.',
        retryable: true,
      );
    }
    return _object(payload['data']);
  }

  @override
  Future<List<FieldRoute>> loadRoutes() async {
    final shell = await _get('/api/local-read/mcp-shell');
    final snapshot = _object(shell['snapshot']);
    return _routesFromShellSnapshot(snapshot);
  }

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) async {
    final results = await Future.wait([
      _get('/api/local-read/mcp-shell'),
      _get('/api/mcp-day/data', {
        'routeId': route.id,
        'date': _dateOnly(date),
      }),
    ]);
    final snapshot = _object(results[0]['snapshot']);
    final customers = _routeCustomersFromShellSnapshot(
      snapshot,
      routeId: route.id,
    );
    return FieldRouteWorkspace(
      route: route,
      customers: customers,
      day: FieldDayData.fromJson(results[1]),
    );
  }
}

List<FieldRoute> _routesFromShellSnapshot(
  Map<String, dynamic> snapshot,
) {
  final routeRows = _objects(snapshot['routes']);
  final customerRows = _objects(snapshot['routeCustomers']);
  final latestSessionRows = _objects(snapshot['latestSessions']);

  final customerCountByRoute = <String, int>{};
  for (final customer in customerRows) {
    if (!_boolean(customer['active'])) continue;
    final routeId = _text(customer['route_id']);
    if (routeId.isEmpty) continue;
    customerCountByRoute[routeId] = (customerCountByRoute[routeId] ?? 0) + 1;
  }

  final latestSessionByRoute = <String, Map<String, dynamic>>{};
  for (final session in latestSessionRows) {
    final routeId = _text(session['route_id']);
    if (routeId.isNotEmpty) latestSessionByRoute[routeId] = session;
  }

  return routeRows
      .where((row) => _boolean(row['active']))
      .map((row) {
        final routeId = _text(row['id']);
        final session = latestSessionByRoute[routeId] ?? const {};
        return FieldRoute(
          id: routeId,
          name: _text(
            row['route_name'],
            fallback: 'Tuyến chưa có tên',
          ),
          area: _text(row['area'], fallback: 'Chưa có khu vực'),
          salesOwner: _text(row['sales']),
          plannedCustomers: _integer(session['planned_customers']) > 0
              ? _integer(session['planned_customers'])
              : customerCountByRoute[routeId] ?? 0,
          visitedCustomers: _integer(session['visited_customers']),
          orderCount: _integer(session['order_count']),
          status: 'active',
        );
      })
      .where((route) => route.id.isNotEmpty)
      .toList(growable: false);
}

List<FieldRouteCustomer> _routeCustomersFromShellSnapshot(
  Map<String, dynamic> snapshot, {
  required String routeId,
}) {
  final routeNames = <String, String>{};
  for (final route in _objects(snapshot['routes'])) {
    final id = _text(route['id']);
    if (id.isEmpty) continue;
    routeNames[id] = _text(
      route['route_name'],
      fallback: 'Tuyến làm việc',
    );
  }

  return _objects(snapshot['routeCustomers'])
      .where(
        (row) =>
            _text(row['route_id']) == routeId &&
            _boolean(row['active']),
      )
      .map((row) {
        final lat = _optionalDouble(row['geo_lat']);
        final lng = _optionalDouble(row['geo_lng']);
        final gps = lat == null || lng == null
            ? null
            : FieldGps(
                lat: lat,
                lng: lng,
                accuracyMeters: _optionalDouble(row['geo_accuracy']),
                updatedAt: _nullableText(row['geo_captured_at']),
              );
        return FieldRouteCustomer(
          id: _text(row['id']),
          routeId: _text(row['route_id']),
          routeName: routeNames[_text(row['route_id'])] ?? 'Tuyến làm việc',
          accountId: _text(row['customer_id']),
          accountName: _text(
            row['customer_name'],
            fallback: 'Điểm bán',
          ),
          contactName: '',
          area: _text(row['area'], fallback: 'Chưa có khu vực'),
          sortOrder: _integer(row['sort_order']),
          status: 'active',
          note: _text(row['note']),
          gps: gps,
        );
      })
      .where((customer) => customer.id.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_object)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value)) ?? 0;
}

double? _optionalDouble(Object? value) {
  if (value == null || _text(value).isEmpty) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  final normalized = _text(value).toLowerCase();
  return normalized == 'true' || normalized == '1';
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
