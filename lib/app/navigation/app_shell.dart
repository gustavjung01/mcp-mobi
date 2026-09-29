import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/mobile_auth_client.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/field_history_client.dart';
import '../../core/data/management_proposal_client.dart';
import '../../core/data/local_catalog_order_data_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/data/route_management_client.dart';
import '../../core/installation/installation_profile.dart';
import '../../core/location/external_navigation.dart';
import '../../core/location/field_location.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_pending_store.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../core/selection/route_selection_store.dart';
import '../../core/sync/customer_boundary_sync.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../core/sync/field_check_sync.dart';
import '../../core/sync/management_proposal_sync.dart';
import '../../core/sync/mutation_queue.dart';
import '../../core/sync/order_offline_store.dart';
import '../../core/sync/route_mutation_sync.dart';
import '../../core/sync/route_management_sync.dart';
import '../../core/storage/legacy_secure_storage_migration.dart';
import '../../core/storage/local_data_store.dart';
import '../../features/customers/company_customer_detail_page.dart';
import '../../features/customers/customer_onboarding_page.dart';
import '../../features/more/more_page.dart';
import '../../features/orders/create_order_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/outlets/outlet_detail_page.dart';
import '../../features/outlets/outlet_edit_page.dart';
import '../../features/product_trials/product_trial_page.dart';
import '../../features/reports/field_activity_history_page.dart';
import '../../features/reports/management_proposals_page.dart';
import '../../features/reports/market_report_page.dart';
import '../../features/reports/session_history_page.dart';
import '../../features/outlets/outlets_page.dart';
import '../../features/routes/add_route_customer_page.dart';
import '../../features/routes/fixed_routes_page.dart';
import '../../features/routes/routes_page.dart';
import '../../features/tasks/followup_page.dart';
import '../../features/tasks/tasks_page.dart';
import '../../features/today/today_page.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.session,
    this.fieldDataClient,
    this.fieldActivityClient,
    this.fieldHistoryClient,
    this.customerBoundaryClient,
    this.managementProposalClient,
    this.routeManagementClient,
    this.orderDataClient,
    this.fieldLocationProvider,
    this.externalNavigation,
    this.outletMediaClient,
    this.outletPhotoPicker,
    this.outletPhotoPendingStore,
    this.mutationQueueStore,
    this.routeSelectionStore,
    this.orderOfflineStore,
    this.onLogout,
  });

  final InstallationProfile? profile;
  final MobileSession? session;
  final FieldDataClient? fieldDataClient;
  final FieldActivityClient? fieldActivityClient;
  final FieldHistoryClient? fieldHistoryClient;
  final CustomerBoundaryClient? customerBoundaryClient;
  final ManagementProposalClient? managementProposalClient;
  final RouteManagementClient? routeManagementClient;
  final OrderDataClient? orderDataClient;
  final FieldLocationProvider? fieldLocationProvider;
  final ExternalNavigation? externalNavigation;
  final OutletMediaClient? outletMediaClient;
  final OutletPhotoPicker? outletPhotoPicker;
  final OutletPhotoPendingStore? outletPhotoPendingStore;
  final MutationQueueStore? mutationQueueStore;
  final RouteSelectionStore? routeSelectionStore;
  final OrderOfflineStore? orderOfflineStore;
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  FieldDataClient? _fieldDataClient;
  FieldActivityClient? _fieldActivityClient;
  FieldHistoryClient? _fieldHistoryClient;
  CustomerBoundaryClient? _customerBoundaryClient;
  ManagementProposalClient? _managementProposalClient;
  RouteManagementClient? _routeManagementClient;
  LocalDataStore? _localDataStore;
  LocalDataScope? _localDataScope;
  LegacySecureStorageMigrator? _legacyMigrator;
  MutationQueueStore? _mutationQueueStore;
  RouteSelectionStore? _routeSelectionStore;
  OrderDataClient? _orderDataClient;
  OrderOfflineStore? _orderOfflineStore;
  OutletMediaClient? _outletMediaClient;
  late final FieldLocationProvider _locationProvider;
  late final ExternalNavigation _externalNavigation;
  late final OutletPhotoPicker _photoPicker;
  late final OutletPhotoPendingStore _photoPendingStore;
  List<FieldRoute> _routes = const [];
  List<FieldOutlet> _outlets = const [];
  List<CompanyCustomer> _companyCustomers = const [];
  FieldRoute? _selectedRoute;
  FieldRouteWorkspace? _workspace;
  bool _loadingRoutes = false;
  bool _loadingOutlets = false;
  bool _loadingCompanyCustomers = false;
  bool _loadingWorkspace = false;
  bool _routeActionBusy = false;
  bool _routeMutationSyncing = false;
  bool _routeManagementSyncing = false;
  bool _fieldActivitySyncing = false;
  bool _fieldCheckSyncing = false;
  bool _customerBoundarySyncing = false;
  bool _orderSyncing = false;
  bool _managementProposalSyncing = false;
  bool _mediaSyncing = false;
  bool _routeSelectionLoaded = false;
  bool _localPersistenceReady = false;
  String? _fieldMessage;
  String? _localPersistenceMessage;
  String? _outletMessage;
  String? _companyCustomerMessage;
  int _workspaceLoadGeneration = 0;
  int _orderRefreshToken = 0;

  FieldActionClient? get _fieldActions {
    final client = _fieldDataClient;
    return client is FieldActionClient ? client as FieldActionClient : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final profile = widget.profile;
    final session = widget.session;
    if (profile != null && session != null) {
      _localDataStore = LocalDataStore.shared;
      _localDataScope = LocalDataScope(
        installationKey: profile.installationKey,
        employeeId: session.employeeId,
      );
      final usesDefaultLegacyBusinessStorage =
          widget.mutationQueueStore == null ||
          widget.routeSelectionStore == null ||
          widget.orderOfflineStore == null;
      if (usesDefaultLegacyBusinessStorage) {
        _legacyMigrator = LegacySecureStorageMigrator(
          database: _localDataStore!,
          scope: _localDataScope!,
        );
      }
    }

    _fieldDataClient = widget.fieldDataClient ?? _defaultFieldDataClient();
    _fieldActivityClient =
        widget.fieldActivityClient ?? _defaultFieldActivityClient();
    _fieldHistoryClient =
        widget.fieldHistoryClient ?? _defaultFieldHistoryClient();
    _customerBoundaryClient =
        widget.customerBoundaryClient ?? _defaultCustomerBoundaryClient();
    _managementProposalClient =
        widget.managementProposalClient ?? _defaultManagementProposalClient();
    _routeManagementClient =
        widget.routeManagementClient ?? _defaultRouteManagementClient();
    _mutationQueueStore =
        widget.mutationQueueStore ?? _defaultMutationQueueStore();
    _routeSelectionStore =
        widget.routeSelectionStore ?? _defaultRouteSelectionStore();
    _orderDataClient = widget.orderDataClient ?? _defaultOrderDataClient();
    _orderOfflineStore =
        widget.orderOfflineStore ?? _defaultOrderOfflineStore();
    _outletMediaClient =
        widget.outletMediaClient ?? _defaultOutletMediaClient();
    _locationProvider =
        widget.fieldLocationProvider ?? const DeviceFieldLocationProvider();
    _externalNavigation =
        widget.externalNavigation ?? const DeviceExternalNavigation();
    _photoPicker = widget.outletPhotoPicker ?? DeviceOutletPhotoPicker();
    _photoPendingStore =
        widget.outletPhotoPendingStore ??
        const DeviceOutletPhotoPendingStore();

    if (_fieldDataClient != null) {
      _loadingRoutes = true;
      _loadingOutlets = true;
      _loadRoutes();
      _loadOutlets();
    }
    if (_customerBoundaryClient != null) {
      _loadingCompanyCustomers = true;
      _loadCompanyCustomers();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocalPersistence();
    });
  }

  Future<void> _initializeLocalPersistence() async {
    String? migrationWarning;
    final migrator = _legacyMigrator;
    if (migrator != null) {
      try {
        await migrator.run();
      } on LegacyStorageMigrationFailure catch (failure) {
        migrationWarning = failure.message;
      }
    }

    _localPersistenceReady = migrationWarning == null;

    if (!mounted) return;
    if (migrationWarning != null) {
      setState(() {
        _localPersistenceMessage = migrationWarning;
      });
      return;
    }
    _syncPendingWork();
    final orderClient = _orderDataClient;
    if (orderClient is LocalCatalogOrderDataClient) {
      unawaited(
        orderClient.refreshCatalog().catchError((_) {
          // The local catalog remains usable; next product search can retry.
        }),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _localPersistenceReady) {
      _syncPendingWork();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  FieldActivityClient? _defaultFieldActivityClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpFieldActivityClient(
      profile: profile,
      token: session.token,
    );
  }

  FieldHistoryClient? _defaultFieldHistoryClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpFieldHistoryClient(
      profile: profile,
      token: session.token,
    );
  }

  CustomerBoundaryClient? _defaultCustomerBoundaryClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpCustomerBoundaryClient(
      profile: profile,
      token: session.token,
    );
  }

  ManagementProposalClient? _defaultManagementProposalClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null ||
        session == null ||
        !session.permissions.contains('mcp.report.write')) {
      return null;
    }
    return HttpManagementProposalClient(
      profile: profile,
      token: session.token,
    );
  }

  RouteManagementClient? _defaultRouteManagementClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    final permissions = session.permissions;
    if (!permissions.contains('mcp.route.write') &&
        !permissions.contains('mcp.route-customer.write') &&
        !permissions.contains('mcp.session.write')) {
      return null;
    }
    return HttpRouteManagementClient(
      profile: profile,
      token: session.token,
    );
  }

  bool get _canManageRoutes =>
      widget.session?.permissions.contains('mcp.route.write') == true;

  bool get _canManageRouteCustomers =>
      widget.session?.permissions.contains('mcp.route-customer.write') == true;

  bool get _canManageSessions =>
      widget.session?.permissions.contains('mcp.session.write') == true;

  bool get _canManageSessionCustomers =>
      widget.session?.permissions.contains('mcp.session-customer.write') == true;

  bool get _canUpdateOutletLocation =>
      widget.session?.permissions.contains('mcp.route-customer.write') == true;

  bool get _canManageProposals =>
      widget.session?.permissions.contains('mcp.report.write') == true;

  bool get _canReadOrders =>
      widget.session?.permissions.contains('mcp.sales-order.read') == true;

  bool get _canCreateOrders =>
      _canReadOrders &&
      widget.session?.permissions.contains('mcp.sales-order.create') == true;

  MutationQueueStore? _defaultMutationQueueStore() {
    final database = _localDataStore;
    final scope = _localDataScope;
    if (database == null || scope == null) return null;
    return LocalMutationQueueStore(
      database: database,
      scope: scope,
    );
  }

  RouteSelectionStore? _defaultRouteSelectionStore() {
    final database = _localDataStore;
    final scope = _localDataScope;
    if (database == null || scope == null) return null;
    return LocalRouteSelectionStore(
      database: database,
      scope: scope,
    );
  }

  OrderDataClient? _defaultOrderDataClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    final remote = HttpOrderDataClient(
      profile: profile,
      token: session.token,
    );
    final database = _localDataStore;
    final scope = _localDataScope;
    if (database == null || scope == null) return remote;
    return LocalCatalogOrderDataClient(
      remote: remote,
      database: database,
      scope: scope,
    );
  }

  OrderOfflineStore? _defaultOrderOfflineStore() {
    final database = _localDataStore;
    final scope = _localDataScope;
    if (database == null || scope == null) return null;
    return LocalOrderOfflineStore(
      database: database,
      scope: scope,
      mutationQueueStore: _mutationQueueStore,
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

      String? restoredRouteId;
      if (!_routeSelectionLoaded) {
        _routeSelectionLoaded = true;
        restoredRouteId = await _routeSelectionStore?.load();
        if (!mounted) return;
      }

      FieldRoute? selectedRoute;
      final currentId = _selectedRoute?.id ?? restoredRouteId;
      if ((currentId ?? '').isNotEmpty) {
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
      if (selectedRoute == null &&
          (currentId ?? '').isNotEmpty &&
          routes.length != 1) {
        try {
          await _routeSelectionStore?.clear();
        } catch (_) {
          // Tuyến cũ không còn trong phạm vi; không chặn tải dữ liệu mới.
        }
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

  Future<void> _loadCompanyCustomers() async {
    final client = _customerBoundaryClient;
    if (client == null) return;

    try {
      final customers = await client.loadCompanyCustomers();
      if (!mounted) return;
      setState(() {
        _companyCustomers = customers;
        _loadingCompanyCustomers = false;
        _companyCustomerMessage = null;
      });
    } on CustomerBoundaryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadingCompanyCustomers = false;
        _companyCustomerMessage = failure.message;
      });
    }
  }

  Future<void> _selectRoute(FieldRoute route) async {
    String? saveWarning;
    try {
      await _routeSelectionStore?.save(route.id);
    } catch (_) {
      saveWarning = 'Đã chọn tuyến nhưng chưa lưu được lựa chọn trên thiết bị.';
    }
    await _loadWorkspace(route);
    if (saveWarning != null && mounted) {
      setState(() {
        _fieldMessage = saveWarning;
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
      if (_customerBoundaryClient != null) {
        _loadingCompanyCustomers = true;
      }
    });
    await Future.wait([
      _loadOutlets(),
      if (_customerBoundaryClient != null) _loadCompanyCustomers(),
    ]);
  }

  Future<void> _startRoute() async {
    final route = _selectedRoute;
    final service = _routeMutationSubmissionService;
    if (route == null || service == null || _routeActionBusy) return;

    final now = DateTime.now();
    final displayName = (widget.session?.displayName ?? '').trim();
    final owner = displayName.isNotEmpty ? displayName : route.salesOwner;

    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      final result = await service.openSession(
        routeId: route.id,
        date: now,
        owner: owner,
        routeName: route.name,
      );
      if (result.status == RouteMutationSubmitStatus.completed) {
        await _loadWorkspace(route);
      } else if (mounted) {
        setState(() {
          _fieldMessage =
              'Đã lưu bắt đầu tuyến chờ gửi. Ứng dụng sẽ tự đồng bộ lại.';
        });
      }
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
    if (route == null ||
        !_isActiveRouteDay(day) ||
        _routeMutationSubmissionService == null ||
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

    final service = _routeMutationSubmissionService;
    if (service == null) return;
    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      final result = await service.finishSession(
        sessionId: day!.run.id,
        routeName: route.name,
      );
      if (result.status == RouteMutationSubmitStatus.completed) {
        await _loadWorkspace(route);
      } else if (mounted) {
        setState(() {
          _fieldMessage =
              'Đã lưu kết thúc tuyến chờ gửi. Ứng dụng sẽ tự đồng bộ lại.';
        });
      }
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

  RouteMutationSubmissionService? get _routeMutationSubmissionService {
    final actions = _fieldActions;
    final queue = _mutationQueueStore;
    if (actions == null || queue == null) return null;
    return RouteMutationSubmissionService(
      client: actions,
      queue: queue,
    );
  }

  RouteManagementSubmissionService? get _routeManagementSubmissionService {
    final client = _routeManagementClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null) return null;
    return RouteManagementSubmissionService(
      client: client,
      queue: queue,
    );
  }

  Future<void> _cancelRouteSession() async {
    final route = _selectedRoute;
    final day = _workspace?.day;
    final service = _routeManagementSubmissionService;
    if (!_canManageSessions ||
        route == null ||
        day?.sessionOpened != true ||
        service == null ||
        _routeActionBusy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy phiên hôm nay?'),
        content: const Text(
          'Phiên sẽ chuyển sang đã hủy. Các dữ liệu đã ghi nhận vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hủy phiên'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      final result = await service.cancelSession(
        sessionId: day!.run.id,
        routeName: route.name,
      );
      if (result == RouteManagementSubmitStatus.completed) {
        await _loadWorkspace(route);
      } else if (mounted) {
        setState(() {
          _fieldMessage = 'Đã lưu hủy phiên chờ gửi.';
        });
      }
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() => _fieldMessage = failure.message);
    } finally {
      if (mounted) setState(() => _routeActionBusy = false);
    }
  }

  Future<void> _deleteEmptyRouteSession() async {
    final route = _selectedRoute;
    final day = _workspace?.day;
    final service = _routeManagementSubmissionService;
    if (!_canManageSessions ||
        route == null ||
        day?.sessionOpened != true ||
        service == null ||
        _routeActionBusy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phiên rỗng?'),
        content: const Text(
          'Chỉ phiên chưa có tác nghiệp mới xóa được. Tuyến cố định không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa phiên'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _routeActionBusy = true;
      _fieldMessage = null;
    });
    try {
      final result = await service.deleteEmptySession(
        sessionId: day!.run.id,
        routeName: route.name,
      );
      if (result == RouteManagementSubmitStatus.completed) {
        await _loadWorkspace(route);
      } else if (mounted) {
        setState(() {
          _fieldMessage = 'Đã lưu xóa phiên rỗng chờ gửi.';
        });
      }
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      setState(() => _fieldMessage = failure.message);
    } finally {
      if (mounted) setState(() => _routeActionBusy = false);
    }
  }

  Future<bool> _editOutletProfile({
    required String routeCustomerId,
    required String name,
    required String phone,
    required String area,
    required String address,
    required int sortOrder,
    required String note,
  }) async {
    final service = _routeManagementSubmissionService;
    if (!_canManageRouteCustomers || service == null) {
      throw const FieldDataFailure(
        code: 'ROUTE_CUSTOMER_UPDATE_FORBIDDEN',
        message: 'Tài khoản chưa được cấp quyền sửa điểm bán.',
      );
    }
    final input = await Navigator.of(context).push<OutletEditInput>(
      MaterialPageRoute<OutletEditInput>(
        builder: (context) => OutletEditPage(
          name: name,
          phone: phone,
          area: area,
          address: address,
          sortOrder: sortOrder,
          note: note,
        ),
      ),
    );
    if (input == null || !mounted) return false;

    final result = await service.updateRouteCustomer(
      routeCustomerId: routeCustomerId,
      customerName: input.name,
      phone: input.phone,
      area: input.area,
      address: input.address,
      sortOrder: input.sortOrder,
      note: input.note,
    );
    if (result == RouteManagementSubmitStatus.completed) {
      await Future.wait([
        if (_fieldDataClient != null) _loadOutlets(),
        if (_selectedRoute != null) _loadWorkspace(_selectedRoute!),
      ]);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi điểm bán chờ gửi.')),
      );
    }
    return true;
  }

  Future<bool> _archiveOutletProfile({
    required String routeCustomerId,
    required String customerName,
  }) async {
    final service = _routeManagementSubmissionService;
    if (!_canManageRouteCustomers || service == null) {
      throw const FieldDataFailure(
        code: 'ROUTE_CUSTOMER_ARCHIVE_FORBIDDEN',
        message: 'Tài khoản chưa được cấp quyền loại điểm bán khỏi tuyến.',
      );
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loại khỏi tuyến cố định?'),
        content: Text(
          '“$customerName” sẽ không còn trong tuyến cố định. Lịch sử cũ vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Loại khỏi tuyến'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    final result = await service.archiveRouteCustomer(
      routeCustomerId: routeCustomerId,
      customerName: customerName,
    );
    if (result == RouteManagementSubmitStatus.completed) {
      await Future.wait([
        if (_fieldDataClient != null) _loadOutlets(),
        if (_selectedRoute != null) _loadWorkspace(_selectedRoute!),
      ]);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu yêu cầu loại điểm bán chờ gửi.')),
      );
    }
    return true;
  }

  Future<bool> _setCheckIn(
    FieldDayLine line,
    bool checkedIn,
  ) async {
    final service = _routeMutationSubmissionService;
    final route = _selectedRoute;
    if (service == null || route == null) {
      throw const FieldDataFailure(
        code: 'CHECKIN_UNAVAILABLE',
        message: 'Bắt đầu tuyến trước khi check-in điểm bán.',
      );
    }

    FieldLocation? location;
    if (checkedIn) {
      try {
        location = await _locationProvider.current();
      } on FieldLocationFailure catch (failure) {
        throw FieldDataFailure(
          code: 'LOCATION_UNAVAILABLE',
          message: failure.message,
        );
      }
    }

    final result = await service.setCheckIn(
      line: line,
      checkedIn: checkedIn,
      location: location,
    );
    if (result.status == RouteMutationSubmitStatus.completed) {
      await _loadWorkspace(route);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            checkedIn ? 'Đã lưu check-in chờ gửi. Ứng dụng sẽ tự đồng bộ lại.' : 'Đã lưu hoàn tác check-in chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
          ),
        ),
      );
    }
    return true;
  }

  Future<bool> _skipRouteOutlet(
    FieldDayLine line,
    String reason,
    String note,
  ) async {
    final service = _routeMutationSubmissionService;
    final route = _selectedRoute;
    if (service == null || route == null) {
      throw const FieldDataFailure(
        code: 'SKIP_UNAVAILABLE',
        message: 'Bắt đầu tuyến trước khi ghi nhận bỏ qua.',
      );
    }

    final result = await service.skip(
      line: line,
      reason: reason,
      note: note,
    );
    if (result.status == RouteMutationSubmitStatus.completed) {
      await _loadWorkspace(route);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu lý do bỏ qua chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _openAddRouteCustomer() async {
    final route = _selectedRoute;
    final day = _workspace?.day;
    final service = _routeMutationSubmissionService;
    if (route == null || day?.sessionOpened != true || service == null) return;

    final status = day!.run.status.trim().toLowerCase();
    if (const {'done', 'completed', 'cancelled', 'closed'}.contains(status)) {
      setState(() {
        _fieldMessage =
            'Phiên hôm nay đã kết thúc nên không thể thêm điểm bán.';
      });
      return;
    }

    final outcome = await Navigator.of(context).push<RouteMutationSubmitStatus>(
      MaterialPageRoute<RouteMutationSubmitStatus>(
        builder: (context) => AddRouteCustomerPage(
          routeName: route.name,
          sessionId: day.run.id,
          submissionService: service,
          locationProvider: _locationProvider,
        ),
      ),
    );
    if (outcome == null || !mounted) return;

    if (outcome == RouteMutationSubmitStatus.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu điểm bán chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loadingWorkspace = true;
      _loadingOutlets = true;
    });
    await Future.wait([
      _loadWorkspace(route),
      _loadOutlets(),
    ]);
  }

  void _syncPendingWork() {
    if (!_localPersistenceReady) return;
    _syncRouteMutations();
    _syncRouteManagement();
    _syncFieldActivities();
    _syncFieldChecks();
    _syncCustomerBoundary();
    _syncOrders();
    _syncManagementProposals();
    _syncPendingMedia();
  }

  Future<void> _syncRouteMutations() async {
    final actions = _fieldActions;
    final queue = _mutationQueueStore;
    if (actions == null || queue == null || _routeMutationSyncing) return;

    _routeMutationSyncing = true;
    try {
      final result = await RouteMutationSyncService(
        client: actions,
        queue: queue,
      ).syncPending();
      if (result.sent > 0 && mounted) {
        final route = _selectedRoute;
        if (route != null) {
          await Future.wait([
            _loadWorkspace(route),
            if (_fieldDataClient != null) _loadOutlets(),
          ]);
        }
      }
    } finally {
      _routeMutationSyncing = false;
    }
  }

  Future<void> _syncRouteManagement() async {
    final client = _routeManagementClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null || _routeManagementSyncing) return;

    _routeManagementSyncing = true;
    try {
      final sent = await RouteManagementSyncService(
        client: client,
        queue: queue,
      ).syncPending();
      if (sent > 0 && mounted) {
        await Future.wait([
          if (_fieldDataClient != null) _loadRoutes(),
          if (_fieldDataClient != null) _loadOutlets(),
        ]);
        final route = _selectedRoute;
        if (route != null) await _loadWorkspace(route);
      }
    } catch (_) {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _routeManagementSyncing = false;
    }
  }

  Future<void> _syncFieldActivities() async {
    final client = _fieldActivityClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null || _fieldActivitySyncing) return;

    _fieldActivitySyncing = true;
    try {
      final result = await FieldActivitySyncService(
        client: client,
        queue: queue,
      ).syncPending();
      if (result.sent > 0 && mounted) {
        final route = _selectedRoute;
        if (route != null) {
          await _loadWorkspace(route);
        }
      }
    } finally {
      _fieldActivitySyncing = false;
    }
  }

  Future<void> _syncFieldChecks() async {
    final client = _fieldHistoryClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null || _fieldCheckSyncing) return;

    _fieldCheckSyncing = true;
    try {
      await FieldCheckSyncService(client: client, queue: queue).syncPending();
    } catch (_) {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _fieldCheckSyncing = false;
    }
  }

  Future<void> _syncCustomerBoundary() async {
    final client = _customerBoundaryClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null || _customerBoundarySyncing) return;

    _customerBoundarySyncing = true;
    try {
      final result = await CustomerBoundarySyncService(
        client: client,
        queue: queue,
      ).syncPending();
      if (result.sent > 0 && mounted) {
        await Future.wait([
          if (_fieldDataClient != null) _loadOutlets(),
          _loadCompanyCustomers(),
        ]);
      }
    } catch (_) {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _customerBoundarySyncing = false;
    }
  }

  Future<void> _syncOrders() async {
    final client = _orderDataClient;
    final store = _orderOfflineStore;
    if (client == null || store == null || _orderSyncing) return;

    _orderSyncing = true;
    try {
      final result = await OrderSyncService(
        client: client,
        store: store,
      ).syncPending();
      if (result.sent > 0 && mounted) {
        setState(() {
          _orderRefreshToken += 1;
        });
        final route = _selectedRoute;
        if (route != null) await _loadWorkspace(route);
      }
    } catch (_) {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _orderSyncing = false;
    }
  }

  Future<void> _syncPendingMedia() async {
    final client = _outletMediaClient;
    if (client == null || _mediaSyncing) return;

    _mediaSyncing = true;
    try {
      final pending = await _photoPendingStore.load();
      var sent = 0;
      for (final item in pending) {
        try {
          await client.uploadPhoto(
            routeCustomerId: item.routeCustomerId,
            sessionId: item.sessionId,
            clientUploadId: item.draft.clientUploadId,
            bytes: item.draft.bytes,
            mimeType: item.draft.mimeType,
            width: item.draft.width,
            height: item.draft.height,
          );
          await _photoPendingStore.remove(item.draft.clientUploadId);
          sent += 1;
        } on OutletMediaFailure {
          // Giữ ảnh chờ trên thiết bị để lần sau gửi lại cùng clientUploadId.
        } on OutletPhotoPendingFailure {
          // Không xóa intent nếu thiết bị chưa dọn được file chờ.
        }
      }
      if (sent > 0 && mounted && _fieldDataClient != null) {
        await _loadOutlets();
      }
    } on OutletPhotoPendingFailure {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _mediaSyncing = false;
    }
  }

  Future<void> _syncManagementProposals() async {
    final client = _managementProposalClient;
    final queue = _mutationQueueStore;
    if (!_canManageProposals ||
        client == null ||
        queue == null ||
        _managementProposalSyncing) {
      return;
    }

    _managementProposalSyncing = true;
    try {
      await ManagementProposalSyncService(
        client: client,
        queue: queue,
      ).syncPending();
    } catch (_) {
      // Đồng bộ nền không chặn người dùng tiếp tục làm việc.
    } finally {
      _managementProposalSyncing = false;
    }
  }

  CustomerBoundarySubmissionService? get _customerBoundarySubmissionService {
    final client = _customerBoundaryClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null) return null;
    return CustomerBoundarySubmissionService(
      client: client,
      queue: queue,
    );
  }

  FieldActivitySubmissionService? get _fieldActivitySubmissionService {
    final client = _fieldActivityClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null) return null;
    return FieldActivitySubmissionService(
      client: client,
      queue: queue,
    );
  }

  Future<void> _openFieldActivity(
    FieldActivityKind kind,
    FieldDayLine line,
  ) async {
    final service = _fieldActivitySubmissionService;
    final client = _fieldActivityClient;
    if (service == null || client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được chức năng tác nghiệp.'),
        ),
      );
      return;
    }

    final day = _workspace?.day;
    final route = _selectedRoute;
    if (day?.sessionOpened != true ||
        route == null ||
        (line.sessionCustomerId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bắt đầu tuyến trước khi ghi nhận tác nghiệp.'),
        ),
      );
      return;
    }

    final currentDay = day!;
    final FieldActivitySubmitStatus? outcome;
    if (kind == FieldActivityKind.report) {
      outcome = await Navigator.of(context).push<FieldActivitySubmitStatus>(
        MaterialPageRoute<FieldActivitySubmitStatus>(
          builder: (context) => MarketReportPage(
            line: line,
            routeName: route.name,
            routeId: route.id,
            sessionDate: currentDay.run.date,
            owner: currentDay.run.owner,
            sessionId: currentDay.run.id,
            activityClient: client,
            submissionService: service,
            mediaClient: _outletMediaClient,
            photoPicker: _photoPicker,
          ),
        ),
      );
    } else if (kind == FieldActivityKind.productTrial) {
      outcome = await Navigator.of(context).push<FieldActivitySubmitStatus>(
        MaterialPageRoute<FieldActivitySubmitStatus>(
          builder: (context) => ProductTrialPage(
            line: line,
            submissionService: service,
          ),
        ),
      );
    } else {
      outcome = await Navigator.of(context).push<FieldActivitySubmitStatus>(
        MaterialPageRoute<FieldActivitySubmitStatus>(
          builder: (context) => FollowupPage(
            line: line,
            owner: widget.session?.displayName ?? currentDay.run.owner,
            submissionService: service,
          ),
        ),
      );
    }

    if (outcome == null || !mounted) return;
    if (outcome == FieldActivitySubmitStatus.completed) {
      await _loadWorkspace(route);
    }
    if (!mounted) return;
    final action = switch (kind) {
      FieldActivityKind.report => 'báo cáo',
      FieldActivityKind.productTrial => 'kết quả thử sản phẩm',
      FieldActivityKind.followup => 'việc theo dõi',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == FieldActivitySubmitStatus.completed
              ? 'Đã lưu $action.'
              : 'Đã lưu $action chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
        ),
      ),
    );
  }

  Future<void> _openMap(FieldGps? gps, String query) {
    return _externalNavigation.openMap(
      latitude: gps?.lat,
      longitude: gps?.lng,
      query: query,
    );
  }

  Future<bool> _updateOutletLocation(
    String routeCustomerId,
    String customerName,
  ) async {
    final service = _routeMutationSubmissionService;
    if (!_canUpdateOutletLocation || service == null) {
      throw const FieldDataFailure(
        code: 'LOCATION_UPDATE_FORBIDDEN',
        message: 'Tài khoản chưa được cấp quyền cập nhật vị trí điểm bán.',
      );
    }

    final FieldLocation location;
    try {
      location = await _locationProvider.current();
    } on FieldLocationFailure catch (failure) {
      throw FieldDataFailure(
        code: 'LOCATION_UNAVAILABLE',
        message: failure.message,
      );
    }

    final result = await service.updateLocation(
      routeCustomerId: routeCustomerId,
      customerName: customerName,
      location: location,
    );
    if (result.status == RouteMutationSubmitStatus.completed) {
      await _loadOutlets();
      final route = _selectedRoute;
      if (route != null) await _loadWorkspace(route);
    }
    return result.status == RouteMutationSubmitStatus.completed;
  }

  Future<void> _openSessionHistory() async {
    final client = _fieldHistoryClient;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa kết nối được lịch sử phiên.')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SessionHistoryPage(client: client),
      ),
    );
  }

  Future<void> _openTasks() async {
    final client = _fieldHistoryClient;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa kết nối được danh sách công việc.')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TasksPage(client: client),
      ),
    );
  }

  Future<void> _openActivityHistory(FieldActivityKind kind) async {
    final client = _fieldActivityClient;
    final queue = _mutationQueueStore;
    if (client == null || queue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được dữ liệu tác nghiệp.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FieldActivityHistoryPage(
          kind: kind,
          lines: _workspace?.day.lines ?? const <FieldDayLine>[],
          queue: queue,
          syncService: FieldActivitySyncService(
            client: client,
            queue: queue,
          ),
          historyClient: _fieldHistoryClient,
          onSynchronized: () async {
            final route = _selectedRoute;
            if (route != null) await _loadWorkspace(route);
          },
        ),
      ),
    );
  }

  void _openRouteOutlet(
    FieldRouteCustomer? customer,
    FieldDayLine line,
  ) {
    final outlet = _outletForRouteCustomerId(line.routeCustomerId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OutletDetailPage(
          routeName: _selectedRoute?.name ?? customer?.routeName ?? 'Đi tuyến',
          customer: customer,
          outlet: outlet,
          line: line,
          sessionId: _workspace?.day.sessionOpened == true
              ? _workspace?.day.run.id
              : null,
          mediaClient: _outletMediaClient,
          photoPicker: _photoPicker,
          photoPendingStore: _photoPendingStore,
          historyClient: _fieldHistoryClient,
          onOpenMap: _openMap,
          onUpdateLocation: _canUpdateOutletLocation
              ? _updateOutletLocation
              : null,
          onEditOutlet: _canManageRouteCustomers
              ? () => _editOutletProfile(
                    routeCustomerId:
                        (line.routeCustomerId ?? customer?.id ?? '').trim(),
                    name: line.accountName,
                    phone: line.phone ?? customer?.phone ?? '',
                    area: line.area,
                    address: line.address ?? customer?.address ?? '',
                    sortOrder: customer?.sortOrder ?? line.sortOrder,
                    note: line.note.isNotEmpty ? line.note : customer?.note ?? '',
                  )
              : null,
          onArchiveOutlet: _canManageRouteCustomers
              ? () => _archiveOutletProfile(
                    routeCustomerId:
                        (line.routeCustomerId ?? customer?.id ?? '').trim(),
                    customerName: line.accountName,
                  )
              : null,
          onSetCheckIn:
              _canManageSessionCustomers && _routeMutationSubmissionService != null
              ? _setCheckIn
              : null,
          onSkip:
              _canManageSessionCustomers && _routeMutationSubmissionService != null
              ? _skipRouteOutlet
              : null,
          onCreateOrder: _orderDataClient == null || !_canCreateOrders
              ? null
              : () => _openCreateOrder(line),
          onCustomerOnboarding: _customerBoundaryClient == null
              ? null
              : () => _openCustomerOnboarding(
                  routeCustomerId: line.routeCustomerId,
                ),
          onCreateReport: _fieldActivityClient == null
              ? null
              : () => _openFieldActivity(FieldActivityKind.report, line),
          onCreateProductTrial: _fieldActivityClient == null
              ? null
              : () => _openFieldActivity(
                  FieldActivityKind.productTrial,
                  line,
                ),
          onCreateFollowup: _fieldActivityClient == null
              ? null
              : () => _openFieldActivity(FieldActivityKind.followup, line),
        ),
      ),
    );
  }

  Future<bool> _openCustomerOnboarding({
    String? routeCustomerId,
  }) async {
    final client = _customerBoundaryClient;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được chức năng mở hoặc liên kết mã.'),
        ),
      );
      return false;
    }

    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CustomerOnboardingPage(
          client: client,
          focusRouteCustomerId: routeCustomerId,
          submissionService: _customerBoundarySubmissionService,
          onChanged: () async {
            changed = true;
            await Future.wait([
              if (_fieldDataClient != null) _loadOutlets(),
              _loadCompanyCustomers(),
            ]);
          },
        ),
      ),
    );
    return changed;
  }

  void _openDirectoryOutlet(FieldOutlet outlet) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OutletDetailPage(
          routeName: outlet.routeName.isEmpty ? 'Điểm bán' : outlet.routeName,
          outlet: outlet,
          mediaClient: _outletMediaClient,
          photoPicker: _photoPicker,
          photoPendingStore: _photoPendingStore,
          historyClient: _fieldHistoryClient,
          onOpenMap: _openMap,
          onUpdateLocation: _canUpdateOutletLocation
              ? _updateOutletLocation
              : null,
          onEditOutlet: _canManageRouteCustomers
              ? () => _editOutletProfile(
                    routeCustomerId: outlet.id,
                    name: outlet.name,
                    phone: outlet.phone,
                    area: outlet.area,
                    address: outlet.address,
                    sortOrder: outlet.sortOrder,
                    note: outlet.note,
                  )
              : null,
          onArchiveOutlet: _canManageRouteCustomers
              ? () => _archiveOutletProfile(
                    routeCustomerId: outlet.id,
                    customerName: outlet.name,
                  )
              : null,
          onCreateOrder: _orderDataClient == null || !_canCreateOrders
              ? null
              : () => _openOrderForOutlet(outlet),
          onCustomerOnboarding: _customerBoundaryClient == null
              ? null
              : () => _openCustomerOnboarding(
                  routeCustomerId: outlet.id,
                ),
        ),
      ),
    );
  }

  void _openCompanyCustomer(CompanyCustomer customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CompanyCustomerDetailPage(
          customer: customer,
          onCreateOrder: _orderDataClient == null || !_canCreateOrders
              ? null
              : () => _openOrderForCompanyCustomer(customer),
        ),
      ),
    );
  }

  FieldOutlet? _outletForRouteCustomerId(String? routeCustomerId) {
    if ((routeCustomerId ?? '').isEmpty) return null;
    for (final outlet in _outlets) {
      if (outlet.id == routeCustomerId) return outlet;
    }
    return null;
  }

  bool _canOrderForOutlet(FieldOutlet outlet) {
    return (outlet.coreCustomerId ?? '').trim().isNotEmpty &&
        (outlet.coreCustomerAddressId ?? '').trim().isNotEmpty;
  }

  Future<void> _openCreateOrder(FieldDayLine line) async {
    var outlet = _outletForRouteCustomerId(line.routeCustomerId);
    if (outlet == null && _fieldDataClient != null) {
      await _loadOutlets();
      outlet = _outletForRouteCustomerId(line.routeCustomerId);
    }
    if (!mounted) return;
    if (outlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy hồ sơ điểm bán để ra đơn.'),
        ),
      );
      return;
    }
    await _openOrderForOutlet(outlet);
  }

  Future<void> _openOrderForOutlet(FieldOutlet outlet) async {
    final client = _orderDataClient;
    if (client == null || !_canCreateOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản chưa được cấp quyền tạo đơn hàng.'),
        ),
      );
      return;
    }

    var current = _outletForRouteCustomerId(outlet.id) ?? outlet;
    if (!_canOrderForOutlet(current)) {
      final openOnboarding = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Điểm bán chưa sẵn sàng ra đơn'),
          content: const Text(
            'Cần mở hoặc liên kết mã khách Công Ty và có địa chỉ giao hàng trước khi tạo đơn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mở / liên kết mã'),
            ),
          ],
        ),
      );
      if (openOnboarding != true || !mounted) return;

      await _openCustomerOnboarding(routeCustomerId: current.id);
      if (_fieldDataClient != null) {
        await _loadOutlets();
      }
      if (!mounted) return;
      current = _outletForRouteCustomerId(current.id) ?? current;
      if (!_canOrderForOutlet(current)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Điểm bán chưa được Công Ty xác nhận đủ thông tin để ra đơn.',
            ),
          ),
        );
        return;
      }
    }

    final outcome = await Navigator.of(context).push<OrderSubmitOutcome>(
      MaterialPageRoute<OrderSubmitOutcome>(
        builder: (context) => CreateOrderPage(
          outlet: current,
          orderClient: client,
          offlineStore: _orderOfflineStore,
        ),
      ),
    );
    if (outcome == null || !mounted) return;

    setState(() {
      _orderRefreshToken += 1;
    });
    if (outcome == OrderSubmitOutcome.created) {
      final route = _selectedRoute;
      if (route != null) {
        await _loadWorkspace(route);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == OrderSubmitOutcome.created ? 'Đã tạo đơn hàng.' : 'Đã lưu đơn chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
        ),
      ),
    );
  }

  Future<void> _openOrderForCompanyCustomer(
    CompanyCustomer customer,
  ) async {
    final client = _orderDataClient;
    if (client == null || !_canCreateOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản chưa được cấp quyền tạo đơn hàng.'),
        ),
      );
      return;
    }

    final addressId = (customer.defaultAddressId ?? '').trim();
    if (customer.status.trim().toLowerCase() != 'active' || addressId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Khách Công Ty chưa có địa chỉ giao hàng đang hoạt động.',
          ),
        ),
      );
      return;
    }

    final target = FieldOutlet(
      id: 'company-${customer.id}',
      routeId: '',
      routeName: 'Đơn hàng',
      code: customer.customerCode ?? '',
      name: customer.name,
      phone: customer.phone ?? '',
      area: '',
      address:
          customer.defaultAddressLine1 ?? customer.defaultAddressLabel ?? '',
      status: 'linked_existing',
      note: '',
      coreCustomerId: customer.id,
      coreCustomerAddressId: addressId,
      coreCustomerCode: customer.customerCode,
    );

    final outcome = await Navigator.of(context).push<OrderSubmitOutcome>(
      MaterialPageRoute<OrderSubmitOutcome>(
        builder: (context) => CreateOrderPage(
          outlet: target,
          orderClient: client,
          offlineStore: _orderOfflineStore,
        ),
      ),
    );
    if (outcome == null || !mounted) return;

    setState(() {
      _orderRefreshToken += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == OrderSubmitOutcome.created ? 'Đã tạo đơn hàng.' : 'Đã lưu đơn chờ gửi. Ứng dụng sẽ tự đồng bộ lại.',
        ),
      ),
    );
  }

  Future<void> _openManagementProposals() async {
    final client = _managementProposalClient;
    final queue = _mutationQueueStore;
    if (!_canManageProposals || client == null || queue == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ManagementProposalsPage(
          client: client,
          submissionService: ManagementProposalSubmissionService(
            client: client,
            queue: queue,
          ),
          syncService: ManagementProposalSyncService(
            client: client,
            queue: queue,
          ),
          queue: queue,
        ),
      ),
    );
  }

  Future<void> _openFixedRoutes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FixedRoutesPage(
          routes: _routes,
          initialRoute: _selectedRoute,
          dataClient: _fieldDataClient,
          managementService: _routeManagementSubmissionService,
          canManageRoutes: _canManageRoutes,
          canManageCustomers: _canManageRouteCustomers,
        ),
      ),
    );
    if (!mounted || _fieldDataClient == null) return;
    await Future.wait([
      _loadRoutes(),
      _loadOutlets(),
    ]);
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
        message: _localPersistenceMessage ?? _fieldMessage,
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
        message: _localPersistenceMessage ?? _fieldMessage,
        routeActionBusy: _routeActionBusy,
        onSelectRoute: _selectRoute,
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
        onOpenOutlet: (line) => _openRouteOutlet(_customerForLine(line), line),
        onStartRoute:
            _canManageSessions && _routeMutationSubmissionService != null
            ? _startRoute
            : null,
        onFinishRoute:
            _canManageSessions && _routeMutationSubmissionService != null
            ? _finishRoute
            : null,
        onCancelRoute: _canManageSessions &&
                _routeManagementSubmissionService != null
            ? _cancelRouteSession
            : null,
        onDeleteEmptySession: _canManageSessions &&
                _routeManagementSubmissionService != null
            ? _deleteEmptyRouteSession
            : null,
        onAddCustomer:
            _canManageSessionCustomers && _routeMutationSubmissionService != null
            ? _openAddRouteCustomer
            : null,
      ),
      OutletsPage(
        outlets: _outlets,
        companyCustomers: _companyCustomers,
        loading: _loadingOutlets,
        companyLoading: _loadingCompanyCustomers,
        message: _outletMessage,
        companyMessage: _companyCustomerMessage,
        onRefresh: _fieldDataClient == null && _customerBoundaryClient == null
            ? null
            : _refreshOutlets,
        onOpenOutlet: _openDirectoryOutlet,
        onOpenCompanyCustomer: _openCompanyCustomer,
      ),
      OrdersPage(
        orderClient: _orderDataClient,
        offlineStore: _orderOfflineStore,
        companyCustomers: _companyCustomers,
        onCreateOrder: _orderDataClient == null || !_canCreateOrders
            ? null
            : _openOrderForCompanyCustomer,
        onCustomerOnboarding: _customerBoundaryClient == null
            ? null
            : () async {
                await _openCustomerOnboarding();
              },
        refreshToken: _orderRefreshToken,
      ),
      MorePage(
        onFixedRoutes: _fieldDataClient == null ? null : _openFixedRoutes,
        onSessionHistory: _fieldHistoryClient == null
            ? null
            : _openSessionHistory,
        onReports: _fieldActivityClient == null
            ? null
            : () => _openActivityHistory(FieldActivityKind.report),
        onProductTrials: _fieldActivityClient == null
            ? null
            : () => _openActivityHistory(FieldActivityKind.productTrial),
        onTasks: _fieldHistoryClient == null ? null : _openTasks,
        onManagementProposals:
            _canManageProposals && _managementProposalClient != null
            ? _openManagementProposals
            : null,
        onCustomerOnboarding: _customerBoundaryClient == null
            ? null
            : () => _openCustomerOnboarding(),
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      key: const Key('app-shell-scaffold'),
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        key: const Key('app-bottom-navigation'),
        top: false,
        child: DecoratedBox(
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
      ),
    );
  }
}

bool _isActiveRouteDay(FieldDayData? day) {
  if (day?.sessionOpened != true) return false;
  final status = day!.run.status.trim().toLowerCase();
  return const {'active', 'opened', 'open', 'in_progress'}.contains(status);
}

