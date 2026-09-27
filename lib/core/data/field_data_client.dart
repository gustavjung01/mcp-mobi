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
    final base = profile.baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
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
    final data = await _get('/api/routes/data');
    return _objects(data['routes'])
        .map(FieldRoute.fromJson)
        .where((route) => route.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<FieldRouteWorkspace> loadRouteWorkspace({
    required FieldRoute route,
    required DateTime date,
  }) async {
    final results = await Future.wait([
      _get('/api/routes/customers/data', {'routeId': route.id}),
      _get('/api/mcp-day/data', {
        'routeId': route.id,
        'date': _dateOnly(date),
      }),
    ]);
    final customers = _objects(results[0]['customers'])
        .map(FieldRouteCustomer.fromJson)
        .where((customer) => customer.id.isNotEmpty)
        .toList(growable: false);
    return FieldRouteWorkspace(
      route: route,
      customers: customers,
      day: FieldDayData.fromJson(results[1]),
    );
  }
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
