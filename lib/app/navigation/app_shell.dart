import 'package:flutter/material.dart';

import '../../core/auth/mobile_auth_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/installation/installation_profile.dart';
import '../../core/location/field_location.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../features/more/more_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/outlets/outlet_detail_page.dart';
import '../../features/outlets/outlets_page.dart';
import '../../features/routes/add_route_customer_page.dart';
import '../../features/routes/routes_page.dart';
import '../../features/today/today_page.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.session,
    this.fieldDataClient,
    this.fieldLocationProvider,
    this.outletMediaClient,
    this.outletPhotoPicker,
    this.onLogout,
  });

  final InstallationProfile? profile;
  final MobileSession? session;
  final FieldDataClient? fieldDataClient;
  final FieldLocationProvider? fieldLocationProvider;
  final OutletMediaClient? outletMediaClient;
  final OutletPhotoPicker? outletPhotoPicker;
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  FieldDataClient? _fieldDataClient;
  OutletMediaClient? _outletMediaClient;
  late final FieldLocationProvider _locationProvider;
  late final OutletPhotoPicker _photoPicker;
  final Map<String, String> _mutationKeys = {};
  final Map<String, _PendingCheckIn> _pendingCheckIns = {};
  List<FieldRoute> _routes = const [];
  List<FieldOutlet> _outlets = const [];
  FieldRoute? _selectedRoute;
  FieldRouteWorkspace? _workspace;
  bool _loadingRoutes = false;
  bool _loadingOutlets = false;
  bool _loadingWorkspace = false;
  bool _routeActionBusy = false;
  String? _fieldMessage;
  String? _outletMessage;
  int _workspaceLoadGeneration = 0;

  FieldActionClient? get _fieldActions {
    final client = _fieldDataClient;
    return client is FieldActionClient ? client as FieldActionClient : null;
  }

  @override
  void initState() {
    super.initState();
    _fieldDataClient = widget.fieldDataClient ?? _defaultFieldDataClient();
    _outletMediaClient =
        widget.outletMediaClient ?? _defaultOutletMediaClient();
    _locationProvider =
        widget.fieldLocationProvider ?? const DeviceFieldLocationProvider();
    _photoPicker = widget.outletPhotoPicker ?? DeviceOutletPhotoPicker();
    if (_fieldDataClient != null) {
      _loadingRoutes = true;
      _loadingOutlets = true;
      _loadRoutes();
      _loadOutlets();
    }
  }

  FieldDataClient? _defaultFieldDataClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpFieldDataClient(
      profile: profile,
      token: session.token,
    );
  }

  OutletMediaClient? _defaultOutletMediaClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpOutletMediaClient(
      profile: profile,
      token: session.token,
    );
  }

  String _mutationKey(String signature, String operation) {
    return _mutationKeys.putIfAbsent(
      signature,
      () => CanonicalIdempotencyKey.create(operation),
    );
  }

  void _openTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _loadRoutes() async {
    final client = _fieldDataClient;
    if (client == null) return;

    try {
      final routes = await client.loadRoutes();
      if (!mounted) return;

      FieldRoute? selectedRoute;
      final currentId = _selectedRoute?.id;
      if (currentId != null) {
        for (final route in routes) {
          if (route.id == currentId) {
            selectedRoute = route;
            break;
          }
        }
      }
      if (selectedRoute == null && routes.length == 1) {
        selectedRoute = routes.single;
      }

      setState(() {
        _routes = routes;
        _selectedRoute = selectedRoute;
        _loadingRoutes = false;
        _fieldMessage = null;
        if (selectedRoute == null) _workspace = null;
      });

      if (selectedRoute != null) {
        await _loadWorkspace(selectedRoute);
      }
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadingRoutes = false;
        _fieldMessage = failure.message;
      });
    }
  }

  Future<void> _loadOutlets() async {
    final client = _fieldDataClient;
    if (client == null) return;

    try {
      final outlets = await client.loadOutlets();
      if (!mounted) return;
      setState(() {
        _outlets = outlets;
        _loadingOutlets = false;
        _outletMessage = null;
      });
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadingOutlets = false;
        _outletMessage = failure.message;
      });
    }
  }

  Future<void> _loadWorkspace(FieldRoute route) async {
    final client = _fieldDataClient;
    if (client == null) return;
    final generation = ++_workspaceLoadGeneration;

    setState(() {
      _selectedRoute = route;
      _workspace = null;
      _loadingWorkspace = true;
      _fieldMessage = null;
    });

    try {
      final workspace = await client.loadRouteWorkspace(
        route: route,
        date: DateTime.now(),
      );
      if (!mounted || generation != _workspaceLoadGeneration) return;
      setState(() {
        _workspace = workspace;
        _loadingWorkspace = false;
      });
    } on FieldDataFailure catch (failure) {
      if (!mounted || generation != _workspaceLoadGeneration) return;
      setState(() {
        _loadingWorkspace = false;
        _fieldMessage = failure.message;
      });
    }
  }

  Future<void> _refreshFieldData() async {
    final route = _selectedRoute;
    if (route == null) {
      setState(() {
        _loadingRoutes = true;
      });
      await _loadRoutes();
      return;
    }
    await _loadWorkspace(route);
  }

  Future<void> _refreshOutlets() async {
    setState(() {
      _loadingOutlets = true;
    });
    await _loadOutlets();
  }

  Future<void> _startRoute() async {
    final route = _selectedRoute;
    final actions = _fieldActions;
    if (route == null || actions == null || _routeActionBusy) return;

    final now = DateTime.now();
    final signature = 'route-session.open:${route.id}:${_dateOnly(now)}';
    final key = _mutationKey(signature, 'route-session.open');
    final displayName = (widget.session?.displayName ?? '').trim();
    final owner = displayName.isNotEmpty ? displayName : route.salesOwner;

    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      await actions.openRouteSession(
        routeId: route.id,
        date: now,
        owner: owner,
        idempotencyKey: key,
      );
      _mutationKeys.remove(signature);
      await _loadWorkspace(route);
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _fieldMessage = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _routeActionBusy = false;
        });
      }
    }
  }

  Future<void> _finishRoute() async {
    final route = _selectedRoute;
    final day = _workspace?.day;
    final actions = _fieldActions;
    if (route == null ||
        day?.sessionOpened != true ||
        actions == null ||
        _routeActionBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc tuyến hôm nay?'),
        content: const Text(
          'Sau khi kết thúc, phiên hôm nay sẽ chuyển sang chỉ xem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final signature = 'route-session.update:${day!.run.id}:done';
    final key = _mutationKey(signature, 'route-session.update');
    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      await actions.finishRouteSession(
        sessionId: day.run.id,
        idempotencyKey: key,
      );
      _mutationKeys.remove(signature);
      await _loadWorkspace(route);
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _fieldMessage = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _routeActionBusy = false;
        });
      }
    }
  }

  Future<void> _checkIn(FieldDayLine line) async {
    final actions = _fieldActions;
    final route = _selectedRoute;
    final sessionCustomerId = line.sessionCustomerId;
    if (actions == null || route == null || sessionCustomerId == null) {
      throw const FieldDataFailure(
        code: 'CHECKIN_UNAVAILABLE',
        message: 'Bắt đầu tuyến trước khi check-in điểm bán.',
      );
    }

    var pending = _pendingCheckIns[sessionCustomerId];
    if (pending == null) {
      try {
        final location = await _locationProvider.current();
        pending = _PendingCheckIn(
          key: CanonicalIdempotencyKey.create(
            'session-customer.checkin.set',
          ),
          location: location,
        );
        _pendingCheckIns[sessionCustomerId] = pending;
      } on FieldLocationFailure catch (failure) {
        throw FieldDataFailure(
          code: 'LOCATION_UNAVAILABLE',
          message: failure.message,
        );
      }
    }

    await actions.setSessionCustomerCheckIn(
      sessionCustomerId: sessionCustomerId,
      latitude: pending.location.latitude,
      longitude: pending.location.longitude,
      accuracy: pending.location.accuracy,
      idempotencyKey: pending.key,
    );
    _pendingCheckIns.remove(sessionCustomerId);
    await _loadWorkspace(route);
  }

  Future<void> _openAddRouteCustomer() async {
    final route = _selectedRoute;
    final day = _workspace?.day;
    final actions = _fieldActions;
    if (route == null || day?.sessionOpened != true || actions == null) return;

    final status = day!.run.status.trim().toLowerCase();
    if (const {'done', 'completed', 'cancelled', 'closed'}.contains(status)) {
      setState(() {
        _fieldMessage =
            'Phiên hôm nay đã kết thúc nên không thể thêm điểm bán.';
      });
      return;
    }

    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => AddRouteCustomerPage(
          routeName: route.name,
          sessionId: day.run.id,
          actionClient: actions,
          locationProvider: _locationProvider,
        ),
      ),
    );
    if (added != true || !mounted) return;

    setState(() {
      _loadingWorkspace = true;
      _loadingOutlets = true;
    });
    await Future.wait([
      _loadWorkspace(route),
      _loadOutlets(),
    ]);
  }

  void _openRouteOutlet(
    FieldRouteCustomer? customer,
    FieldDayLine line,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OutletDetailPage(
          routeName: _selectedRoute?.name ?? customer?.routeName ?? 'Đi tuyến',
          customer: customer,
          line: line,
          sessionId: _workspace?.day.sessionOpened == true
              ? _workspace?.day.run.id
              : null,
          mediaClient: _outletMediaClient,
          photoPicker: _photoPicker,
          onCheckIn: _fieldActions == null ? null : _checkIn,
        ),
      ),
    );
  }

  void _openDirectoryOutlet(FieldOutlet outlet) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OutletDetailPage(
          routeName: outlet.routeName.isEmpty ? 'Điểm bán' : outlet.routeName,
          outlet: outlet,
          mediaClient: _outletMediaClient,
          photoPicker: _photoPicker,
        ),
      ),
    );
  }

  FieldRouteCustomer? _customerForLine(FieldDayLine line) {
    final routeCustomerId = line.routeCustomerId;
    if (routeCustomerId == null) return null;
    for (final customer
        in _workspace?.customers ?? const <FieldRouteCustomer>[]) {
      if (customer.id == routeCustomerId) return customer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingRoutes || _loadingWorkspace;
    final pages = <Widget>[
      TodayPage(
        displayName: widget.session?.displayName,
        selectedRoute: _selectedRoute,
        workspace: _workspace,
        loading: loading,
        message: _fieldMessage,
        onOpenRoutes: () => _openTab(1),
        onOpenRouteOutlet: (line) =>
            _openRouteOutlet(_customerForLine(line), line),
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
      ),
      RoutesPage(
        routes: _routes,
        selectedRoute: _selectedRoute,
        workspace: _workspace,
        loading: loading,
        message: _fieldMessage,
        routeActionBusy: _routeActionBusy,
        onSelectRoute: _loadWorkspace,
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
        onOpenOutlet: (line) => _openRouteOutlet(_customerForLine(line), line),
        onStartRoute: _fieldActions == null ? null : _startRoute,
        onFinishRoute: _fieldActions == null ? null : _finishRoute,
        onAddCustomer: _fieldActions == null ? null : _openAddRouteCustomer,
      ),
      OutletsPage(
        outlets: _outlets,
        loading: _loadingOutlets,
        message: _outletMessage,
        onRefresh: _fieldDataClient == null ? null : _refreshOutlets,
        onOpenOutlet: _openDirectoryOutlet,
      ),
      const OrdersPage(),
      MorePage(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _openTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Hôm nay',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Đi tuyến',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Điểm bán',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Đơn hàng',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'Thêm',
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCheckIn {
  const _PendingCheckIn({
    required this.key,
    required this.location,
  });

  final String key;
  final FieldLocation location;
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
