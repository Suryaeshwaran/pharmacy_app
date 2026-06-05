// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _expandedSection = 0;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Dashboard', 
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // ── Greeting Card ──────────────────────────────────────
          _WhiteCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()} 👋',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(today),
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Today's Summary label ──────────────────────────────
          _SectionLabel(label: "Today's Summary"),
          const SizedBox(height: 8),

          // ── Stat Tiles Card ────────────────────────────────────
          _WhiteCard(
            child: StreamBuilder<List<Bill>>(
              stream: DatabaseProvider.instance.db
                  .watchBillsByDateRange(startOfDay, endOfDay),
              builder: (context, snap) {
                final bills = snap.data ?? [];
                final sales = bills.fold(0.0, (s, b) => s + b.subtotal - b.discount);
                final fee = bills.fold(0.0, (s, b) => s + b.consultationFee);
                final total = bills.fold(0.0, (s, b) => s + b.totalAmount);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(children: [
                    _StatTile(
                      icon: Icons.receipt_long_outlined,
                      value: '${bills.length}',
                      label: 'Bills Today',
                      iconColor: cs.primary,
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: cs.outlineVariant,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    _StatTile(
                      icon: Icons.currency_rupee_outlined,
                      value: snap.hasData
                          ? '₹${NumberFormat('#,##,###').format(sales)}'
                          : '—',
                      label: 'Sales',
                      iconColor: cs.primary,
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: cs.outlineVariant,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    _StatTile(
                      icon: Icons.medical_services_outlined,
                      value: snap.hasData
                          ? '₹${NumberFormat('#,##,###').format(fee)}'
                          : '—',
                      label: 'Fee',
                      iconColor: cs.primary,
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: cs.outlineVariant,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    _StatTile(
                      icon: Icons.account_balance_wallet_outlined,
                      value: snap.hasData
                          ? '₹${NumberFormat('#,##,###').format(total)}'
                          : '—',
                      label: 'Total',
                      iconColor: cs.primary,
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Inventory Alerts label ─────────────────────────────
          _SectionLabel(label: 'Inventory Alerts'),
          const SizedBox(height: 8),

          // ── Inventory Alerts Card ──────────────────────────────
          _WhiteCard(
            child: Column(
              children: [
                StreamBuilder<List<Medicine>>(
                  stream: DatabaseProvider.instance.db.watchLowStockMedicines(),
                  builder: (context, snap) {
                    final all = snap.data ?? [];
                    final outOfStock = all.where((m) => m.stockQty == 0).toList();
                    final lowStock = all.where((m) => m.stockQty > 0).toList();
                    return Column(children: [
                      _AlertSection(
                        index: 1,
                        expandedIndex: _expandedSection,
                        onTap: (i) => setState(() =>
                            _expandedSection = _expandedSection == i ? 0 : i),
                        icon: Icons.remove_shopping_cart_outlined,
                        label: 'Out of Stock',
                        count: outOfStock.length,
                        accentColor: cs.error,
                        medicines: outOfStock,
                        showExpiry: false,
                        isLast: false,
                      ),
                      _AlertSection(
                        index: 2,
                        expandedIndex: _expandedSection,
                        onTap: (i) => setState(() =>
                            _expandedSection = _expandedSection == i ? 0 : i),
                        icon: Icons.warning_amber_outlined,
                        label: 'Low Stock',
                        count: lowStock.length,
                        accentColor: Colors.orange.shade700,
                        medicines: lowStock,
                        showExpiry: false,
                        isLast: false,
                      ),
                    ]);
                  },
                ),
                StreamBuilder<List<Medicine>>(
                  stream: DatabaseProvider.instance.db.watchExpiringMedicines(),
                  builder: (context, snap) {
                    final expiring = snap.data ?? [];
                    return _AlertSection(
                      index: 3,
                      expandedIndex: _expandedSection,
                      onTap: (i) => setState(() =>
                          _expandedSection = _expandedSection == i ? 0 : i),
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Expiring Soon',
                      count: expiring.length,
                      accentColor: Colors.amber.shade800,
                      medicines: expiring,
                      showExpiry: true,
                      isLast: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── White Card ───────────────────────────────────────────────────────────────

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Stat Tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),          
        ]),
      ]),
    );
  }
}

// ── Alert Section ────────────────────────────────────────────────────────────

class _AlertSection extends StatelessWidget {
  final int index;
  final int expandedIndex;
  final void Function(int) onTap;
  final IconData icon;
  final String label;
  final int count;
  final Color accentColor;
  final List<Medicine> medicines;
  final bool showExpiry;
  final bool isLast;

  const _AlertSection({
    required this.index,
    required this.expandedIndex,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.count,
    required this.accentColor,
    required this.medicines,
    required this.showExpiry,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isExpanded = expandedIndex == index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: count > 0 ? accentColor : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Icon(icon,
                  size: 20,
                  color: count > 0
                      ? accentColor
                      : cs.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: count > 0
                      ? accentColor.withOpacity(0.12)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: count > 0
                        ? accentColor
                        : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: cs.onSurface,
              ),
            ]),
          ),
        ),

        // ── Expanded list ──
        if (isExpanded)
          count == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(37, 0, 20, 12),
                  child: Text('Nothing to show',
                      style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurface)),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(37, 0, 20, 10),
                  child: Column(
                    children: medicines.map((m) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text(m.name,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurface)),
                          ),
                          Text(
                            showExpiry && m.expiryDate != null
                                ? DateFormat('dd MMM yy').format(m.expiryDate!)
                                : 'Qty: ${m.stockQty}',
                            style: textTheme.bodySmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

        if (!isLast)
          Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
            color: cs.outlineVariant.withOpacity(0.5),
          ),
      ],
    );
  }
}