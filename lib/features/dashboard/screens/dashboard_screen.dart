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
      body: StreamBuilder<List<Bill>>(
        stream: DatabaseProvider.instance.db
            .watchBillsByDateRange(startOfDay, endOfDay),
        builder: (context, snap) {
          final bills = snap.data ?? [];

          // ── Today's Patients panel ────────────────────────────
          final patientsPanel = _WhiteCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.people_outline, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Count', style: TextStyle(fontSize: 12, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                          Text('${bills.length}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 6),
                  if (bills.isEmpty)
                    const Text(
                      'No patients yet',
                      style: TextStyle(fontSize: 11, color: Colors.black),
                    )
                  else
                    ...bills.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.customerName?.isNotEmpty == true
                                ? b.customerName!
                                : 'Walk-in',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (b.customerPhone?.isNotEmpty == true)
                            Text(
                              b.customerPhone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          );

          return ListView(
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

              // ── Main 80/20 layout: left = all 3 sections, right = patients ──
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Left: 80% — all 3 sections stacked ────────────
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Today's Summary
                          const _SectionLabel(label: "Today's Summary"),
                          const SizedBox(height: 8),
                          _WhiteCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(children: [
                                _StatTile(
                                  icon: Icons.receipt_long_outlined,
                                  value: '${bills.length}',
                                  label: 'Bills Today',
                                  iconColor: cs.primary,
                                ),
                                Container(width: 1, height: 48, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                _StatTile(
                                  icon: Icons.currency_rupee_outlined,
                                  value: snap.hasData ? '₹${NumberFormat('#,##,###').format(bills.fold(0.0, (s, b) => s + b.subtotal - b.discount))}' : '—',
                                  label: 'Sales',
                                  iconColor: cs.primary,
                                ),
                                Container(width: 1, height: 48, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                _StatTile(
                                  icon: Icons.medical_services_outlined,
                                  value: snap.hasData ? '₹${NumberFormat('#,##,###').format(bills.fold(0.0, (s, b) => s + b.consultationFee))}' : '—',
                                  label: 'Fee',
                                  iconColor: cs.primary,
                                ),
                                Container(width: 1, height: 48, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                _StatTile(
                                  icon: Icons.account_balance_wallet_outlined,
                                  value: snap.hasData ? '₹${NumberFormat('#,##,###').format(bills.fold(0.0, (s, b) => s + b.totalAmount))}' : '—',
                                  label: 'Total',
                                  iconColor: cs.primary,
                                ),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Payment Details
                          const _SectionLabel(label: 'Payment Details'),
                          const SizedBox(height: 8),
                          _WhiteCard(
                            child: Column(
                              children: [
                                // Header row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    const SizedBox(width: 90),
                                    Expanded(
                                      child: Row(children: [
                                        Icon(Icons.payments_outlined, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text('Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                      ]),
                                    ),
                                    Expanded(
                                      child: Row(children: [
                                        Icon(Icons.phone_android_outlined, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text('GPay/Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                                      ]),
                                    ),
                                    Expanded(
                                      child: Row(children: [
                                        Icon(Icons.account_balance_wallet_outlined, size: 14, color: cs.primary),
                                        const SizedBox(width: 4),
                                        Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                                      ]),
                                    ),
                                  ]),
                                ),
                                Divider(height: 1, color: cs.outlineVariant),
                                // Fee row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 90,
                                      child: Row(children: [
                                        Icon(Icons.medical_services_outlined, size: 14, color: cs.onSurface),
                                        const SizedBox(width: 6),
                                        Text('Fee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                      ]),
                                    ),
                                    Expanded(child: Text('₹${bills.fold(0.0, (s, b) => s + b.feeCashAmount).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: cs.onSurface))),
                                    Expanded(child: Text('₹${bills.fold(0.0, (s, b) => s + b.feeOnlineAmount).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: cs.onSurface))),
                                    Expanded(child: Text('₹${(bills.fold(0.0, (s, b) => s + b.feeCashAmount) + bills.fold(0.0, (s, b) => s + b.feeOnlineAmount)).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface))),
                                  ]),
                                ),
                                Divider(height: 1, color: cs.outlineVariant),
                                // Pharmacy row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 90,
                                      child: Row(children: [
                                        Icon(Icons.local_pharmacy_outlined, size: 14, color: cs.onSurface),
                                        const SizedBox(width: 6),
                                        Text('Pharmacy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                      ]),
                                    ),
                                    Expanded(child: Text('₹${bills.fold(0.0, (s, b) => s + b.cashAmount).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: cs.onSurface))),
                                    Expanded(child: Text('₹${bills.fold(0.0, (s, b) => s + b.onlineAmount).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: cs.onSurface))),
                                    Expanded(child: Text('₹${(bills.fold(0.0, (s, b) => s + b.cashAmount) + bills.fold(0.0, (s, b) => s + b.onlineAmount)).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface))),
                                  ]),
                                ),
                                Divider(height: 1, color: cs.outlineVariant),
                                // Total row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 90,
                                      child: Row(children: [
                                        Icon(Icons.account_balance_wallet_outlined, size: 14, color: cs.primary),
                                        const SizedBox(width: 6),
                                        Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                                      ]),
                                    ),
                                    Expanded(child: Text('₹${(bills.fold(0.0, (s, b) => s + b.feeCashAmount) + bills.fold(0.0, (s, b) => s + b.cashAmount)).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary))),
                                    Expanded(child: Text('₹${(bills.fold(0.0, (s, b) => s + b.feeOnlineAmount) + bills.fold(0.0, (s, b) => s + b.onlineAmount)).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary))),
                                    Expanded(child: Text('₹${(bills.fold(0.0, (s, b) => s + b.feeCashAmount) + bills.fold(0.0, (s, b) => s + b.cashAmount) + bills.fold(0.0, (s, b) => s + b.feeOnlineAmount) + bills.fold(0.0, (s, b) => s + b.onlineAmount)).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary))),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Inventory Alerts
                          const _SectionLabel(label: 'Inventory Alerts'),
                          const SizedBox(height: 8),
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
                                        onTap: (i) => setState(() => _expandedSection = _expandedSection == i ? 0 : i),
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
                                        onTap: (i) => setState(() => _expandedSection = _expandedSection == i ? 0 : i),
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
                                      onTap: (i) => setState(() => _expandedSection = _expandedSection == i ? 0 : i),
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
                    ),

                    const SizedBox(width: 8),

                    // ── Right: 20% — single patients panel spanning full height ──
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Align label with "Today's Summary"
                          const _SectionLabel(label: "Today's Patients"),
                          const SizedBox(height: 8),
                          Expanded(
                            child: patientsPanel,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
            color: Colors.black.withValues(alpha:0.06),
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
    // final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface), overflow: TextOverflow.ellipsis),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface), overflow: TextOverflow.ellipsis),
          ]),
        ),
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
                      ? accentColor.withValues(alpha:0.12)
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
            color: cs.outlineVariant.withValues(alpha:0.5),
          ),
      ],
    );
  }
}