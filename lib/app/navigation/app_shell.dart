import 'package:flutter/material.dart';

import '../../core/auth/mobile_auth_client.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/installation/installation_profile.dart';
import '../../core/location/field_location.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../core/selection/route_selection_store.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../core/sync/mutation_queue.dart';
import '../../core/sync/order_offline_store.dart';
import '../../core/sync/route_mutation_sync.dart';
import '../../features/customers/customer_onboarding_page.dart';
import '../../features/more/more_page.dart';
import '../../features/orders/create_order_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/outlets/outlet_detail_page.dart';
import '../../features/product_trials/product_trial_page.dart';
import '../../features/reports/field_activity_history_page.dart';
import '../../features/reports/market_report_page.dart';
import '../../features/outlets/outlets_page.dart';
import '../../features/routes/add_route_customer_page.dart';
import '../../features/routes/fixed_routes_page.dart';
import '../../features/routes/routes_page.dart';
import '../../features/tasks/followup_page.dart';
import '../../features/today/today_page.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.session,
    this.fieldDataClient,
    this.fieldActivityClient,
    this.customerBoundaryClient,
    this.orderDataClient,
    this.fieldLocationProvider,
    this.outletMediaClient,
    this.outletPhotoPicker,
    this.mutationQueueStore,
    this.routeSelectionStore,
    this.orderOfflineStore,
    this.onLogout,
  });

  final InstallationProfile? profile;
  final MobileSession? session;
  final FieldDataClient? fieldDataClient;
  final FieldActivityClient? fieldActivityClient;
  final CustomerBoundaryClient? customerBoundaryClient;
  final OrderDataClient? orderDataClient;
  final FieldLocationProvider? fieldLocationProvider;
  final OutletMediaClient? outletMediaClient;
  final OutletPhotoPicker? outletPhotoPicker;
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
  CustomerBoundaryClient? _customerBoundaryClient;
  MutationQueueStore? _mutationQueueStore;
  RouteSelectionStore? _routeSelectionStore;
  OrderDataClient? _orderDataClient;
  OrderOfflineStore? _orderOfflineStore;
  OutletMediaClient? _outletMediaClient;
  late final FieldLocationProvider _locationProvider;
  late final OutletPhotoPicker _photoPicker;
  final Map<String, String> _mutationKeys = {};
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
  bool _fieldActivitySyncing = false;
  bool _routeSelectionLoaded = false;
  String? _fieldMessage;
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
    _fieldDataClient = widget.fieldDataClient ?? _defaultFieldDataClient();
    _fieldActivityClient =
        widget.fieldActivityClient ?? _defaultFieldActivityClient();
    _customerBoundaryClient =
        widget.customerBoundaryClient ?? _defaultCustomerBoundaryClient();
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
    _photoPicker = widget.outletPhotoPicker ?? DeviceOutletPhotoPicker();
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
      _syncRouteMutations();
      _syncFieldActivities();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncRouteMutations();
      _syncFieldActivities();
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

  CustomerBoundaryClient? _defaultCustomerBoundaryClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpCustomerBoundaryClient(
      profile: profile,
      token: session.token,
    );
  }

  MutationQueueStore? _defaultMutationQueueStore() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return SecureMutationQueueStore(
      installationKey: profile.installationKey,
      employeeId: session.employeeId,
    );
  }

  RouteSelectionStore? _defaultRouteSelectionStore() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return SecureRouteSelectionStore(
      installationKey: profile.installationKey,
      employeeId: session.employeeId,
    );
  }

  OrderDataClient? _defaultOrderDataClient() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return HttpOrderDataClient(
      profile: profile,
      token: session.token,
    );
  }

  OrderOfflineStore? _defaultOrderOfflineStore() {
    final profile = widget.profile;
    final session = widget.session;
    if (profile == null || session == null) return null;
    return SecureOrderOfflineStore(
      installationKey: profile.installationKey,
      employeeId: session.employeeId,
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
        !_isActiveRouteDay(day) ||
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

  RouteMutationSubmissionService? get _routeMutationSubmissionService {
    final actions = _fieldActions;
    final queue = _mutationQueueStore;
    if (actions == null || queue == null) return null;
    return RouteMutationSubmissionService(
      client: actions,
      queue: queue,
    );
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
              : 'Đã lưu $action chờ gửi. Ứng dụng sẽ đồng bộ lại bằng đúng lần gửi này.',
        ),
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
          onSetCheckIn: _routeMutationSubmissionService == null
              ? null
              : _setCheckIn,
          onSkip: _routeMutationSubmissionService == null
              ? null
              : _skipRouteOutlet,
          onCreateOrder: _orderDataClient == null
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
          onCreateOrder: _orderDataClient == null
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
    if (client == null) return;

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
          outcome == OrderSubmitOutcome.created ? 'Đã tạo đơn hàng.' : 'Đã lưu đơn chờ gửi. Ứng dụng sẽ dùng lại đúng lần gửi này khi đồng bộ.',
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
        onSelectRoute: _selectRoute,
        onRefresh: _fieldDataClient == null ? null : _refreshFieldData,
        onOpenOutlet: (line) => _openRouteOutlet(_customerForLine(line), line),
        onStartRoute: _fieldActions == null ? null : _startRoute,
        onFinishRoute: _fieldActions == null ? null : _finishRoute,
        onAddCustomer: _routeMutationSubmissionService == null
            ? null
            : _openAddRouteCustomer,
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
      ),
      OrdersPage(
        orderClient: _orderDataClient,
        offlineStore: _orderOfflineStore,
        refreshToken: _orderRefreshToken,
      ),
      MorePage(
        onFixedRoutes: _fieldDataClient == null ? null : _openFixedRoutes,
        onReports: _fieldActivityClient == null
            ? null
            : () => _openActivityHistory(FieldActivityKind.report),
        onProductTrials: _fieldActivityClient == null
            ? null
            : () => _openActivityHistory(FieldActivityKind.productTrial),
        onTasks: _fieldActivityClient == null
            ? null
            : () => _openActivityHistory(FieldActivityKind.followup),
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

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
