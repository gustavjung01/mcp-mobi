enum MobileCapability {
  fixedRoutes,
  sessionHistory,
  reportHistory,
  productTrialHistory,
  reportSettings,
  dataExports,
  tasks,
  managementProposals,
  customerOnboarding,
  manageRoutes,
  manageRouteCustomers,
  updateOutletLocation,
  manageSessions,
  manageSessionCustomers,
  createReports,
  createProductTrials,
  createFollowups,
  readOrders,
  createOrders,
}

class MobileCapabilityState {
  const MobileCapabilityState.available()
    : available = true,
      unavailableReason = null;

  const MobileCapabilityState.unavailable(this.unavailableReason)
    : available = false;

  final bool available;
  final String? unavailableReason;
}

class MobileCapabilityRegistry {
  MobileCapabilityRegistry({
    required Iterable<String> permissions,
    Map<MobileCapability, bool> runtimeAvailability = const {},
  }) : permissions = Set.unmodifiable(
         permissions.map((item) => item.trim()).where((item) => item.isNotEmpty),
       ),
       runtimeAvailability = Map.unmodifiable(runtimeAvailability);

  final Set<String> permissions;
  final Map<MobileCapability, bool> runtimeAvailability;

  bool can(MobileCapability capability) => state(capability).available;

  MobileCapabilityState state(MobileCapability capability) {
    final missing = _requiredPermissions(
      capability,
    ).where((permission) => !permissions.contains(permission));
    if (missing.isNotEmpty) {
      return const MobileCapabilityState.unavailable(
        'Tài khoản chưa được cấp quyền sử dụng chức năng này.',
      );
    }
    if (runtimeAvailability[capability] == false) {
      return const MobileCapabilityState.unavailable(
        'Chức năng này chưa sẵn sàng trên hệ thống hiện tại.',
      );
    }
    return const MobileCapabilityState.available();
  }

  List<String> _requiredPermissions(MobileCapability capability) {
    return switch (capability) {
      MobileCapability.manageRoutes => const ['mcp.route.write'],
      MobileCapability.manageRouteCustomers ||
      MobileCapability.updateOutletLocation => const [
        'mcp.route-customer.write',
      ],
      MobileCapability.manageSessions => const ['mcp.session.write'],
      MobileCapability.manageSessionCustomers => const [
        'mcp.session-customer.write',
      ],
      MobileCapability.createReports ||
      MobileCapability.managementProposals => const ['mcp.report.write'],
      MobileCapability.createProductTrials => const ['mcp.test.write'],
      MobileCapability.createFollowups => const ['mcp.followup.write'],
      MobileCapability.reportSettings => const ['mcp.report-setting.write'],
      MobileCapability.readOrders => const ['mcp.sales-order.read'],
      MobileCapability.createOrders => const [
        'mcp.sales-order.read',
        'mcp.sales-order.create',
      ],
      _ => const [],
    };
  }
}
