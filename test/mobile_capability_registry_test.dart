import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/capabilities/mobile_capability_registry.dart';

void main() {
  test('capability registry combines permission and runtime readiness', () {
    final registry = MobileCapabilityRegistry(
      permissions: const [
        'mcp.report.write',
        'mcp.sales-order.read',
        'mcp.sales-order.create',
      ],
      runtimeAvailability: const {
        MobileCapability.managementProposals: true,
        MobileCapability.createOrders: true,
        MobileCapability.reportSettings: true,
      },
    );

    expect(registry.can(MobileCapability.managementProposals), isTrue);
    expect(registry.can(MobileCapability.createOrders), isTrue);
    expect(registry.can(MobileCapability.reportSettings), isFalse);
    expect(
      registry.state(MobileCapability.reportSettings).unavailableReason,
      contains('chưa được cấp quyền'),
    );
  });

  test('capability registry blocks unavailable runtime even with permission', () {
    final registry = MobileCapabilityRegistry(
      permissions: const ['mcp.report.write'],
      runtimeAvailability: const {
        MobileCapability.createReports: false,
      },
    );

    expect(registry.can(MobileCapability.createReports), isFalse);
    expect(
      registry.state(MobileCapability.createReports).unavailableReason,
      contains('chưa sẵn sàng'),
    );
  });
}
