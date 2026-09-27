import 'package:flutter/material.dart';

import '../../core/auth/mobile_auth_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/installation/installation_profile.dart';
import '../../features/more/more_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/outlets/outlet_detail_page.dart';
import '../../features/outlets/outlets_page.dart';
import '../../features/routes/routes_page.dart';
import '../../features/today/today_page.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.session,
    this.fieldDataClient,
    this.onLogout,
  });

  final InstallationProfile? profile;
  final MobileSession? session;
  final FieldDataClient? fieldDataClient;
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  FieldDataClient? _fieldDataClient;
  List<FieldRoute> _routes = const [];
  FieldRoute? _selectedRoute;
  FieldRouteWorkspace? _workspace;
  bool _loadingRoutes = false;
  bool _loadingWorkspace = false;
  String? _fieldMessage;
  int _workspaceLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fieldDataClient = widget.fieldDataClient ?? _defaultFieldDataClient();
    if (_fieldDataClient != null) {
      _loadingRoutes = true;
      _loadRoutes();
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

  void _openOutlet(
    FieldRouteCustomer? customer,
    FieldDayLine? line,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OutletDetailPage(
          routeName: _selectedRoute?.name ?? customer?.routeName ?? 'Điểm bán',
          customer: customer,
          line: line,
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
        onOpenOutlets: () => _openTab(2),
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
      ),
      RoutesPage(
        routes: _routes,
        selectedRoute: _selectedRoute,
        workspace: _workspace,
        loading: loading,
        message: _fieldMessage,
        onSelectRoute: _loadWorkspace,
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
        onOpenOutlet: (line) => _openOutlet(_customerForLine(line), line),
      ),
      OutletsPage(
        selectedRoute: _selectedRoute,
        workspace: _workspace,
        loading: loading,
        message: _fieldMessage,
        onOpenRoutes: () => _openTab(1),
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
        onOpenOutlet: _openOutlet,
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
