import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:integration_test/integration_test.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/customer_boundary_client.dart';
import 'package:mcp_field/core/data/field_activity_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/data/field_history_client.dart';
import 'package:mcp_field/core/data/management_proposal_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/data/route_management_client.dart';
import 'package:mcp_field/core/export/mobile_document_share.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';
import 'package:mcp_field/core/installation/system_endpoint_probe.dart';
import 'package:mcp_field/core/media/outlet_media_client.dart';
import 'package:mcp_field/core/storage/local_data_store.dart';
import 'package:mcp_field/core/sync/mutation_queue.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guarded test installation closes the mobile runtime chain', (
    tester,
  ) async {
    final config = _RuntimeGateConfig.fromEnvironment();
    config.validate();
    final profile = InstallationProfile.selected(
      name: config.environmentName,
      baseUrl: Uri.parse(config.apiBaseUrl),
    );
    final auth = HttpMobileAuthClient();
    MobileSession? session;

    try {
      await HttpSystemEndpointProbe().verify(profile.baseUrl);
      session = await auth.login(
        profile: profile,
        loginName: config.loginName,
        password: config.password,
        ownerCode: config.ownerCode,
      );
      final current = await auth.me(profile: profile, token: session.token);
      expect(current.employeeId, session.employeeId);
      _requirePermissions(current.permissions);

      final field = HttpFieldDataClient(profile: profile, token: current.token);
      final routes = HttpRouteManagementClient(
        profile: profile,
        token: current.token,
      );
      final activities = HttpFieldActivityClient(
        profile: profile,
        token: current.token,
      );
      final history = HttpFieldHistoryClient(
        profile: profile,
        token: current.token,
      );
      final customers = HttpCustomerBoundaryClient(
        profile: profile,
        token: current.token,
      );
      final orders = HttpOrderDataClient(
        profile: profile,
        token: current.token,
      );
      final media = HttpOutletMediaClient(
        profile: profile,
        token: current.token,
      );
      final proposals = HttpManagementProposalClient(
        profile: profile,
        token: current.token,
      );

      await field.loadRoutes();
      await field.loadOutlets();
      await customers.loadVerifications();
      await customers.loadCompanyCustomers();
      await activities.loadReportSettings();
      await activities.loadReportTemplates();
      await activities.loadTestFiles();
      await history.loadSessionHistory();
      await history.loadTasks();
      await history.loadSessionReports();
      await history.loadFieldChecks();
      await orders.loadCompleteCatalog();
      await orders.loadOrders();
      await proposals.load();

      await _reportSettings(activities, config.runId);
      await _orderReplay(orders, current, config);
      await _routeSessionChain(
        field: field,
        routes: routes,
        activities: activities,
        history: history,
        customers: customers,
        media: media,
        proposals: proposals,
        session: current,
        runId: config.runId,
      );
    } finally {
      if (session != null) {
        try {
          await auth.logout(profile: profile, token: session.token);
        } on Object {
          // Cleanup failure must not replace the primary gate result.
        }
      }
    }
  });
}

Future<void> _reportSettings(
  HttpFieldActivityClient client,
  String runId,
) async {
  final title = 'L7 Runtime $runId';
  final label = 'Lựa chọn L7 $runId';
  await client.saveReportSettingGroup(
    title: title,
    description: 'Nhóm kiểm thử runtime tự động',
    sortOrder: 9900,
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.report-setting-group.runtime-create',
    ),
  );
  final group = (await client.loadReportSettingGroups()).firstWhere(
    (item) => item.title == title,
  );
  await client.saveReportSettingItem(
    groupId: group.id,
    label: label,
    value: label,
    category: 'Runtime',
    brandName: '',
    productId: '',
    sortOrder: 1,
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.report-setting-item.runtime-create',
    ),
  );
  final refreshed = (await client.loadReportSettingGroups()).firstWhere(
    (item) => item.id == group.id,
  );
  final item = refreshed.items.firstWhere((item) => item.label == label);
  await client.saveReportSettingItem(
    itemId: item.id,
    groupId: group.id,
    label: item.label,
    value: item.value,
    category: item.category,
    brandName: item.brandName,
    productId: item.productId,
    sortOrder: item.sortOrder,
    status: 'inactive',
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.report-setting-item.runtime-retire',
    ),
  );
  await client.saveReportSettingGroup(
    groupId: group.id,
    title: group.title,
    description: group.description,
    sortOrder: group.sortOrder,
    status: 'inactive',
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.report-setting-group.runtime-retire',
    ),
  );
}

Future<void> _customerBoundary(
  HttpCustomerBoundaryClient client,
  String routeCustomerId,
) async {
  final submitted = await client.submit(
    routeCustomerId: routeCustomerId,
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.customer-verification.runtime-submit',
    ),
  );
  expect(submitted.routeCustomerId, routeCustomerId);
  final synced = await client.sync(
    routeCustomerId: routeCustomerId,
    idempotencyKey: CanonicalIdempotencyKey.create(
      'mcp.customer-verification.runtime-sync',
    ),
  );
  expect(synced.routeCustomerId, routeCustomerId);
}

Future<void> _mediaBoundary(
  HttpOutletMediaClient client,
  String routeCustomerId,
  String runId,
) async {
  final before = await client.loadProfile(routeCustomerId: routeCustomerId);
  final existing = before.media.map((item) => item.id).toSet();
  final image = image_lib.Image(width: 4, height: 4);
  final bytes = Uint8List.fromList(image_lib.encodeJpg(image, quality: 80));
  final safeRun = runId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
  await client.uploadPhoto(
    routeCustomerId: routeCustomerId,
    clientUploadId: 'l7media$safeRun',
    bytes: bytes,
    mimeType: 'image/jpeg',
    width: 4,
    height: 4,
  );
  final after = await client.loadProfile(routeCustomerId: routeCustomerId);
  final created = after.media.where((item) => !existing.contains(item.id));
  expect(created, isNotEmpty);
  for (final item in created) {
    await client.deleteMedia(mediaId: item.id);
  }
}

Future<void> _orderReplay(
  HttpOrderDataClient client,
  MobileSession session,
  _RuntimeGateConfig config,
) async {
  final database = LocalDataStore();
  final scope = LocalDataScope(
    installationKey: 'l7-runtime-${config.runId}',
    employeeId: session.employeeId,
  );
  final queue = LocalMutationQueueStore(database: database, scope: scope);
  final store = LocalOrderOfflineStore(
    database: database,
    scope: scope,
    mutationQueueStore: queue,
  );
  final key = CanonicalIdempotencyKey.create('mcp.sales-order.runtime-create');
  final lines = [
    OrderLineInput(
      variantId: config.orderVariantId,
      quantity: 1,
      note: 'L7 runtime gate',
    ),
  ];
  try {
    await store.saveMutation(
      QueuedOrderMutation(
        idempotencyKey: key,
        outletId: 'l7-runtime',
        outletName: 'Điểm bán runtime',
        customerId: config.orderCustomerId,
        customerAddressId: config.orderCustomerAddressId,
        note: 'L7 runtime gate ${config.runId}',
        lines: lines,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    final sync = await OrderSyncService(
      client: client,
      store: store,
    ).syncPending(idempotencyKey: key);
    expect(sync.sent, 1);
    expect(sync.failed, 0);
    final queued = (await store.loadMutations()).firstWhere(
      (item) => item.idempotencyKey == key,
    );
    expect(queued.state, OrderQueueState.acknowledged);
    expect(queued.serverOrderId, isNotEmpty);

    final replay = await client.createOrder(
      customerId: config.orderCustomerId,
      customerAddressId: config.orderCustomerAddressId,
      lines: lines,
      idempotencyKey: key,
      note: 'L7 runtime gate ${config.runId}',
    );
    expect(replay.id, queued.serverOrderId);
    expect(
      (await client.loadOrders()).any((item) => item.id == replay.id),
      isTrue,
    );
  } finally {
    await store.removeMutation(key);
    await database.dispose();
  }
}

Future<void> _routeSessionChain({
  required HttpFieldDataClient field,
  required HttpRouteManagementClient routes,
  required HttpFieldActivityClient activities,
  required HttpFieldHistoryClient history,
  required HttpCustomerBoundaryClient customers,
  required HttpOutletMediaClient media,
  required HttpManagementProposalClient proposals,
  required MobileSession session,
  required String runId,
}) async {
  final suffix = runId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final routeName = 'L7-$suffix';
  final outletName = 'Điểm bán L7 $suffix';
  final testProduct = 'Sản phẩm L7 $suffix';
  final today = DateTime.now();
  String? routeId;
  String? routeCustomerId;
  String? addedRouteCustomerId;
  String? activeSessionId;

  try {
    await routes.createRoute(
      routeName: routeName,
      area: 'Runtime Gate',
      note: 'Tuyến tạm cho kiểm thử L7',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.route.runtime-create',
      ),
    );
    final route = (await field.loadRoutes()).firstWhere(
      (item) => item.name == routeName,
    );
    routeId = route.id;
    await routes.updateRoute(
      routeId: route.id,
      note: 'Đã xác nhận cập nhật runtime L7',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.route.runtime-update',
      ),
    );

    await field.openRouteSession(
      routeId: route.id,
      date: today,
      owner: session.displayName,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session.runtime-empty-open',
      ),
    );
    var workspace = await field.loadRouteWorkspace(route: route, date: today);
    final emptySessionId = workspace.day.run.id;
    await routes.updateSession(
      sessionId: emptySessionId,
      note: 'Phiên rỗng L7',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session.runtime-empty-update',
      ),
    );
    await routes.deleteEmptySession(
      sessionId: emptySessionId,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session.runtime-empty-delete',
      ),
    );

    await routes.addRouteCustomer(
      routeId: route.id,
      customerName: outletName,
      phone: '0900000000',
      area: 'Runtime Gate',
      address: 'Địa chỉ kiểm thử L7',
      note: 'Điểm bán tạm',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.route-customer.runtime-create',
      ),
    );
    workspace = await field.loadRouteWorkspace(route: route, date: today);
    final customer = workspace.customers.firstWhere(
      (item) => item.accountName == outletName,
    );
    routeCustomerId = customer.id;
    await routes.updateRouteCustomer(
      routeCustomerId: customer.id,
      note: 'Đã cập nhật hồ sơ L7',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.route-customer.runtime-update',
      ),
    );
    await field.updateRouteCustomerLocation(
      routeCustomerId: customer.id,
      latitude: 10.7769,
      longitude: 106.7009,
      accuracy: 5,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.route-customer.runtime-location',
      ),
    );

    await _customerBoundary(customers, customer.id);
    await _mediaBoundary(media, customer.id, runId);

    await field.openRouteSession(
      routeId: route.id,
      date: today,
      owner: session.displayName,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session.runtime-open',
      ),
    );
    workspace = await field.loadRouteWorkspace(route: route, date: today);
    activeSessionId = workspace.day.run.id;
    final line = workspace.day.lines.firstWhere(
      (item) => item.routeCustomerId == customer.id,
    );
    final sessionCustomerId = line.sessionCustomerId;
    if (sessionCustomerId == null || sessionCustomerId.isEmpty) {
      throw StateError('runtime_gate_session_customer_missing');
    }

    await field.setSessionCustomerCheckIn(
      sessionCustomerId: sessionCustomerId,
      checkedIn: true,
      latitude: 10.7769,
      longitude: 106.7009,
      accuracy: 5,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-customer.runtime-checkin',
      ),
    );
    await field.setSessionCustomerStatus(
      sessionCustomerId: sessionCustomerId,
      visitStatus: 'visited',
      note: 'Đã ghé điểm bán trong runtime gate',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-customer.runtime-status',
      ),
    );

    final report = await activities.submit(
      kind: FieldActivityKind.report,
      payload: {
        'sessionCustomerId': sessionCustomerId,
        'reportType': 'market_report',
        'content': 'Báo cáo runtime L7 $suffix',
        'fields': {'note': 'Runtime L7'},
        'selected': {
          'competitors': <Object?>[],
          'usedProducts': <Object?>[],
          'settingItems': <Object?>[],
        },
        'context': {
          'routeId': route.id,
          'routeName': routeName,
          'sessionDate': _dateOnly(today),
          'sales': session.displayName,
          'customerName': outletName,
          'area': 'Runtime Gate',
          'routeCustomerId': customer.id,
        },
      },
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.report.runtime-create',
      ),
    );
    final trial = await activities.submit(
      kind: FieldActivityKind.productTrial,
      payload: {
        'sessionCustomerId': sessionCustomerId,
        'fileTitle': 'Phiếu runtime L7',
        'results': [
          {
            'productName': testProduct,
            'status': 'tested',
            'note': 'Runtime L7',
          },
        ],
        'note': 'Runtime L7',
        'customerStatus': 'tested',
      },
      idempotencyKey: CanonicalIdempotencyKey.create('mcp.test.runtime-create'),
    );
    final followup = await activities.submit(
      kind: FieldActivityKind.followup,
      payload: {
        'sessionCustomerId': sessionCustomerId,
        'title': 'Theo dõi runtime L7 $suffix',
        'dueDate': _dateOnly(today.add(const Duration(days: 1))),
        'priority': 'medium',
        'owner': session.displayName,
        'note': 'Runtime L7',
        'followupType': 'report',
      },
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.followup.runtime-create',
      ),
    );

    final added = await field.addSessionCustomer(
      sessionId: activeSessionId,
      customerName: 'Điểm bán thêm L7 $suffix',
      phone: '',
      area: 'Runtime Gate',
      address: 'Địa chỉ bổ sung L7',
      note: 'Khách thêm trong phiên',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-customer.runtime-add',
      ),
    );
    addedRouteCustomerId = added.routeCustomerId;
    await field.setSessionCustomerStatus(
      sessionCustomerId: added.sessionCustomerId,
      visitStatus: 'skipped',
      statusReason: 'no_demand',
      note: 'Bỏ qua có lý do trong runtime gate',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-customer.runtime-skip',
      ),
    );
    await field.finishRouteSession(
      sessionId: activeSessionId,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session.runtime-finish',
      ),
    );

    expect(
      (await history.loadSessionHistory()).any(
        (item) => item.id == activeSessionId,
      ),
      isTrue,
    );
    expect(
      (await history.loadTasks()).any(
        (item) => item.id == followup.referenceId,
      ),
      isTrue,
    );
    final check = (await history.loadFieldChecks(search: testProduct))
        .firstWhere((item) => item.productName == testProduct);
    await history.updateFieldCheck(
      resultId: check.id,
      productName: check.productName,
      status: 'opportunity',
      note: 'Hậu kiểm runtime L7',
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.field-check.runtime-update',
      ),
    );

    await history.createSessionReportSnapshot(
      sessionId: activeSessionId,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-report.runtime-snapshot',
      ),
    );
    final detail = await history.loadSessionReportDetail(activeSessionId);
    expect(detail.hasSnapshot, isTrue);
    final analysis = await history.analyzeSessionReport(
      sessionId: activeSessionId,
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.session-report.runtime-analyze',
      ),
    );
    expect(analysis.summary, isNotEmpty);
    for (final kind in SessionExportKind.values) {
      final export = SessionReportExporter.build(detail, kind, ai: analysis);
      expect(export.fileName, isNotEmpty);
      expect(export.content, isNotEmpty);
    }

    final proposal = await proposals.create(
      draft: ManagementProposalDraft(
        title: 'Đề xuất runtime L7 $suffix',
        content: 'Đề xuất kiểm thử chuỗi mobile runtime.',
        entityType: 'route',
        entityId: route.id,
        entityLabel: routeName,
        impact: 'Kiểm tra contract',
        reason: 'Runtime gate',
        rule: 'L7',
        evidence: [report.referenceId, trial.referenceId],
      ),
      idempotencyKey: CanonicalIdempotencyKey.create(
        'mcp.management-proposal.runtime-create',
      ),
    );
    expect(
      (await proposals.load()).any((item) => item.id == proposal.id),
      isTrue,
    );
    activeSessionId = null;
  } finally {
    if (activeSessionId != null && activeSessionId.isNotEmpty) {
      try {
        await routes.updateSession(
          sessionId: activeSessionId,
          status: 'cancelled',
          note: 'Dọn runtime gate sau lỗi',
          idempotencyKey: CanonicalIdempotencyKey.create(
            'mcp.session.runtime-cleanup',
          ),
        );
      } on Object {
        // Cleanup failure must not replace the primary gate result.
      }
    }
    if (addedRouteCustomerId != null && addedRouteCustomerId.isNotEmpty) {
      try {
        await routes.archiveRouteCustomer(
          routeCustomerId: addedRouteCustomerId,
          idempotencyKey: CanonicalIdempotencyKey.create(
            'mcp.route-customer.runtime-added-retire',
          ),
        );
      } on Object {
        // Cleanup failure must not replace the primary gate result.
      }
    }
    if (routeCustomerId != null && routeCustomerId.isNotEmpty) {
      try {
        await routes.archiveRouteCustomer(
          routeCustomerId: routeCustomerId,
          idempotencyKey: CanonicalIdempotencyKey.create(
            'mcp.route-customer.runtime-retire',
          ),
        );
      } on Object {
        // Cleanup failure must not replace the primary gate result.
      }
    }
    if (routeId != null && routeId.isNotEmpty) {
      try {
        await routes.archiveRoute(
          routeId: routeId,
          idempotencyKey: CanonicalIdempotencyKey.create(
            'mcp.route.runtime-retire',
          ),
        );
      } on Object {
        // Cleanup failure must not replace the primary gate result.
      }
    }
  }
}

void _requirePermissions(List<String> permissions) {
  const required = {
    'mcp.route.write',
    'mcp.route-customer.write',
    'mcp.session.write',
    'mcp.session-customer.write',
    'mcp.report.write',
    'mcp.test.write',
    'mcp.followup.write',
    'mcp.report-setting.write',
    'mcp.sales-order.read',
    'mcp.sales-order.create',
  };
  final missing = required.difference(permissions.toSet());
  expect(
    missing,
    isEmpty,
    reason: 'Tài khoản runtime thiếu quyền bắt buộc: ${missing.join(', ')}',
  );
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}

class _RuntimeGateConfig {
  const _RuntimeGateConfig({
    required this.guard,
    required this.environmentName,
    required this.apiBaseUrl,
    required this.loginName,
    required this.password,
    required this.ownerCode,
    required this.orderCustomerId,
    required this.orderCustomerAddressId,
    required this.orderVariantId,
    required this.runId,
  });

  factory _RuntimeGateConfig.fromEnvironment() {
    return const _RuntimeGateConfig(
      guard: String.fromEnvironment('MCP_RUNTIME_GUARD'),
      environmentName: String.fromEnvironment('MCP_RUNTIME_ENVIRONMENT'),
      apiBaseUrl: String.fromEnvironment('MCP_RUNTIME_API_BASE_URL'),
      loginName: String.fromEnvironment('MCP_RUNTIME_LOGIN_NAME'),
      password: String.fromEnvironment('MCP_RUNTIME_PASSWORD'),
      ownerCode: String.fromEnvironment('MCP_RUNTIME_OWNER_CODE'),
      orderCustomerId: String.fromEnvironment('MCP_RUNTIME_ORDER_CUSTOMER_ID'),
      orderCustomerAddressId: String.fromEnvironment(
        'MCP_RUNTIME_ORDER_CUSTOMER_ADDRESS_ID',
      ),
      orderVariantId: String.fromEnvironment('MCP_RUNTIME_ORDER_VARIANT_ID'),
      runId: String.fromEnvironment('MCP_RUNTIME_RUN_ID'),
    );
  }

  final String guard;
  final String environmentName;
  final String apiBaseUrl;
  final String loginName;
  final String password;
  final String ownerCode;
  final String orderCustomerId;
  final String orderCustomerAddressId;
  final String orderVariantId;
  final String runId;

  void validate() {
    if (guard != 'APPROVED_TEST_INSTALLATION_ONLY') {
      throw StateError('runtime_gate_guard_invalid');
    }
    if (!environmentName.toLowerCase().startsWith('test-')) {
      throw StateError('runtime_gate_environment_must_start_with_test');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    final localEnvironment = environmentName.toLowerCase().startsWith('test-local-');
    const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
    final endpointAllowed =
        uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.scheme == 'https' ||
            (localEnvironment &&
                uri.scheme == 'http' &&
                localHosts.contains(uri.host.toLowerCase())));
    if (!endpointAllowed) {
      throw StateError('runtime_gate_safe_api_required');
    }
    final required = <String, String>{
      'MCP_RUNTIME_LOGIN_NAME': loginName,
      'MCP_RUNTIME_PASSWORD': password,
      'MCP_RUNTIME_ORDER_CUSTOMER_ID': orderCustomerId,
      'MCP_RUNTIME_ORDER_CUSTOMER_ADDRESS_ID': orderCustomerAddressId,
      'MCP_RUNTIME_ORDER_VARIANT_ID': orderVariantId,
      'MCP_RUNTIME_RUN_ID': runId,
    };
    final missing = required.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError('runtime_gate_missing_config:${missing.join(',')}');
    }
  }
}
