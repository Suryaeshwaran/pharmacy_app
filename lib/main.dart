// lib/main.dart

import 'package:flutter/material.dart';
import 'core/database/database_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/billing/screens/billing_screen.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/backup/backup_screen.dart';

void main() {
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmacy Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Screens are kept constant so IndexedStack never rebuilds them
  static const _screens = [
    DashboardScreen(),
    BillingScreen(),
    InventoryScreen(),
    ReportsScreen(),
    BackupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final db = DatabaseProvider.instance.db;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Row(children: [
        NavigationRail(
          backgroundColor: const Color(0xFFF2F4F7),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Icon(Icons.local_pharmacy, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(height: 4),
              Text('Pharmacy', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: Text('Billing'),
            ),
            // Inventory with low-stock badge
            NavigationRailDestination(
              icon: StreamBuilder(
                stream: db.watchLowStockMedicines(),
                builder: (_, snap) {
                  final count = snap.data?.length ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.inventory_2_outlined),
                  );
                },
              ),
              selectedIcon: StreamBuilder(
                stream: db.watchLowStockMedicines(),
                builder: (_, snap) {
                  final count = snap.data?.length ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.inventory_2),
                  );
                },
              ),
              label: const Text('Inventory'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: Text('Reports'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.backup_outlined),
              selectedIcon: Icon(Icons.backup),
              label: Text('Backup'),
            ),
          ],
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // IndexedStack keeps all screens alive — cart state is preserved on tab switch
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ]),
    );
  }
}