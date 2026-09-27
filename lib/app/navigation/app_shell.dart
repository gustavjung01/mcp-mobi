import 'package:flutter/material.dart';

import '../../features/more/more_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/outlets/outlets_page.dart';
import '../../features/routes/routes_page.dart';
import '../../features/today/today_page.dart';
import '../../core/auth/mobile_auth_client.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.session,
    this.onLogout,
  });

  final MobileSession? session;
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TodayPage(displayName: widget.session?.displayName),
      const RoutesPage(),
      const OutletsPage(),
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
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hôm nay',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Đi tuyến',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Điểm bán',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Đơn hàng',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Thêm',
            ),
          ],
        ),
      ),
    );
  }
}
