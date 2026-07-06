// lib/features/agency_purchase/screens/agency_purchase_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class AgencyPurchaseScreen extends StatefulWidget {
  const AgencyPurchaseScreen({super.key});
  @override
  State<AgencyPurchaseScreen> createState() => _AgencyPurchaseScreenState();
}

class _AgencyPurchaseScreenState extends State<AgencyPurchaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showAddAgencyDialog() {
    showDialog(context: context, builder: (_) => const _AgencyFormDialog());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Agency Purchase',
          style: TextStyle(
              color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.business_outlined), text: 'Agencies'),
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AgenciesTab(),
          _ReportsTab(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (_, __) => _tabs.index == 0
            ? FloatingActionButton.extended(
                heroTag: 'agency_purchase_fab',
                onPressed: _showAddAgencyDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Agency'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ─── AGENCIES TAB ─────────────────────────────────────────────────────────────

class _AgenciesTab extends StatelessWidget {
  const _AgenciesTab();

  @override
  Widget build(BuildContext context) {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<AgencyPurchase>>(
      stream: db.watchAllAgencies(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final agencies = snap.data!;
        if (agencies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 56, color: cs.onSurface),
                const SizedBox(height: 12),
                Text('No agencies yet. Tap + to add one.',
                    style: TextStyle(color: cs.onSurface)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: agencies.length,
          itemBuilder: (_, i) => _AgencyCard(agency: agencies[i]),
        );
      },
    );
  }
}

// ─── AGENCY CARD ──────────────────────────────────────────────────────────────

class _AgencyCard extends StatefulWidget {
  final AgencyPurchase agency;
  const _AgencyCard({required this.agency});

  @override
  State<_AgencyCard> createState() => _AgencyCardState();
}

class _AgencyCardState extends State<_AgencyCard> {
  bool _expanded = false;

  Future<void> _confirmDeleteAgency(BuildContext context, double balance) async {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;

    if (balance > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Cannot Delete', style: TextStyle(color: cs.onSurface)),
          content: Text(
            '${widget.agency.name} has an outstanding balance of ₹${balance.toStringAsFixed(2)}. '
            'Clear all dues before deleting.',
            style: TextStyle(color: cs.onSurface),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete Agency', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Delete ${widget.agency.name} and all its bills? This cannot be undone.',
          style: TextStyle(color: cs.onSurface),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deleteAgency(widget.agency.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;
    const green = Color(0xFF1B5E20);

    return StreamBuilder<double>(
      stream: db.watchTotalBilledForAgency(widget.agency.id),
      builder: (context, billedSnap) {
        final totalBilled = billedSnap.data ?? 0.0;
        return StreamBuilder<double>(
          stream: db.watchTotalPaidForAgency(widget.agency.id),
          builder: (context, paidSnap) {
            final totalPaid = paidSnap.data ?? 0.0;
            final balance = totalBilled - totalPaid;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Header row ──
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              color: green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.agency.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: cs.onSurface),
                            ),
                          ),
                          // Summary chips
                          _summaryChip('Bill: ₹${_fmt(totalBilled)}',
                              Colors.blueGrey),
                          const SizedBox(width: 6),
                          _summaryChip('Paid: ₹${_fmt(totalPaid)}',
                              Colors.green.shade700),
                          const SizedBox(width: 6),
                          _summaryChip('Bal: ₹${_fmt(balance)}',
                              balance > 0 ? Colors.red.shade700 : Colors.grey),
                          const SizedBox(width: 8),
                          // Edit agency name
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: cs.onSurface, size: 18),
                            tooltip: 'Edit Agency Name',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _AgencyFormDialog(
                                  agency: widget.agency),
                            ),
                          ),
                          // Delete agency
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: cs.onSurface, size: 18),
                            tooltip: 'Delete Agency',
                            onPressed: () =>
                                _confirmDeleteAgency(context, balance),
                          ),
                          // Add bill
                          IconButton(
                            icon: Icon(Icons.add_circle_outline,
                                color: green, size: 20),
                            tooltip: 'Add Bill',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  _BillFormDialog(agencyId: widget.agency.id),
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: cs.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Expanded bills ──
                  if (_expanded)
                    StreamBuilder<List<AgencyBill>>(
                      stream: db.watchBillsForAgency(widget.agency.id),
                      builder: (context, billSnap) {
                        final bills = billSnap.data ?? [];
                        if (bills.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'No bills yet. Tap + to add a bill.',
                              style: TextStyle(
                                  color: cs.onSurface, fontSize: 13),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            const Divider(height: 1),
                            ...bills.map((bill) => _BillRow(
                                  bill: bill,
                                  agencyId: widget.agency.id,
                                )),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryChip(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);
}

// ─── BILL ROW ─────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final AgencyBill bill;
  final int agencyId;
  const _BillRow({required this.bill, required this.agencyId});

  Future<void> _confirmDeleteBill(BuildContext context) async {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete Bill', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Delete this bill of ₹${bill.billAmount.toStringAsFixed(2)}? '
          'All payments recorded against it will also be removed.',
          style: TextStyle(color: cs.onSurface),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deleteAgencyBill(bill.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;
    const green = Color(0xFF1B5E20);

    return StreamBuilder<double>(
      stream: db.watchTotalPaidForBill(bill.id),
      builder: (context, paidSnap) {
        final paid = paidSnap.data ?? 0.0;
        final balance = bill.billAmount - paid;
        final isPaid = balance <= 0;

        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (bill.billNumber != null &&
                          bill.billNumber!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${bill.billNumber}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        DateFormat('dd MMM yyyy').format(bill.billDate),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(
                        'Bill: ₹${bill.billAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Paid: ₹${paid.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bal: ₹${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: isPaid
                                ? Colors.grey
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
              // Record payment
              if (!isPaid)
                TextButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _PaymentDialog(
                      bill: bill,
                      agencyId: agencyId,
                      outstanding: balance,
                    ),
                  ),
                  icon: Icon(Icons.payments_outlined,
                      size: 16, color: green),
                  label: Text('Pay',
                      style: TextStyle(
                          color: green, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        green.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Text('PAID',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700)),
                ),
              // Edit bill
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: cs.onSurface, size: 18),
                tooltip: 'Edit Bill',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _BillFormDialog(
                      agencyId: agencyId, bill: bill),
                ),
              ),
              // Delete bill
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: cs.onSurface, size: 18),
                tooltip: 'Delete Bill',
                onPressed: () => _confirmDeleteBill(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── REPORTS TAB ──────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  bool _isMonthly = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Recomputed whenever period toggles — StreamBuilder subscribes to this.
  Stream<List<Map<String, dynamic>>> _buildStream() {
    final db = DatabaseProvider.instance.db;
    final DateTime from, to;
    if (_isMonthly) {
      from = DateTime(_selectedYear, _selectedMonth);
      to   = DateTime(_selectedYear, _selectedMonth + 1)
          .subtract(const Duration(seconds: 1));
    } else {
      from = DateTime(_selectedYear);
      to   = DateTime(_selectedYear + 1).subtract(const Duration(seconds: 1));
    }
    return db.watchAgencyReport(from: from, to: to);
  }

  Future<void> _pickYear() async {
    final cs = Theme.of(context).colorScheme;
    final years = List.generate(6, (i) => DateTime.now().year - i);
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Select Year', style: TextStyle(color: cs.onSurface)),
        content: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: years
                .map((y) => ListTile(
                      title: Text('$y', style: TextStyle(color: cs.onSurface)),
                      selected: y == _selectedYear,
                      selectedColor: const Color(0xFF1B5E20),
                      onTap: () => Navigator.pop(context, y),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedYear = picked);
  }

  Future<void> _pickMonth() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Select Month', style: TextStyle(color: cs.onSurface)),
        content: SizedBox(
          width: 260,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              12,
              (i) => ChoiceChip(
                label: Text(_months[i]),
                selected: i + 1 == _selectedMonth,
                selectedColor: const Color(0xFF1B5E20).withValues(alpha: 0.2),
                onSelected: (_) => Navigator.pop(context, i + 1),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const green = Color(0xFF1B5E20);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Controls row ──
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Monthly')),
                  ButtonSegment(value: false, label: Text('Yearly')),
                ],
                selected: {_isMonthly},
                onSelectionChanged: (s) =>
                    setState(() => _isMonthly = s.first),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickYear,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('$_selectedYear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: BorderSide(color: green.withValues(alpha: 0.5)),
                ),
              ),
              if (_isMonthly) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(_months[_selectedMonth - 1]),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: green,
                    side: BorderSide(color: green.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Reactive table ──
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _buildStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      'No data for the selected period.',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  );
                }

                final totalBilled =
                    rows.fold(0.0, (s, r) => s + (r['billed'] as double));
                final totalPaid =
                    rows.fold(0.0, (s, r) => s + (r['paid'] as double));
                final totalBalance =
                    rows.fold(0.0, (s, r) => s + (r['balance'] as double));

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Row(children: [
                          Expanded(
                              flex: 3,
                              child: Text('AGENCY',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: cs.onSurface))),
                          _headerCell('BILLED'),
                          _headerCell('PAID'),
                          _headerCell('BALANCE'),
                        ]),
                      ),
                      // Data rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.4)),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final bal = r['balance'] as double;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(children: [
                                Expanded(
                                    flex: 3,
                                    child: Text(r['name'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface))),
                                _dataCell('₹${_fmt(r['billed'] as double)}',
                                    Colors.blueGrey),
                                _dataCell('₹${_fmt(r['paid'] as double)}',
                                    Colors.green.shade700),
                                _dataCell(
                                    '₹${_fmt(bal)}',
                                    bal > 0
                                        ? Colors.red.shade700
                                        : Colors.grey),
                              ]),
                            );
                          },
                        ),
                      ),
                      // Grand total
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.06),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          border: Border(
                              top: BorderSide(
                                  color: cs.outlineVariant
                                      .withValues(alpha: 0.5))),
                        ),
                        child: Row(children: [
                          Expanded(
                              flex: 3,
                              child: Text('TOTAL',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurface))),
                          _dataCell('₹${_fmt(totalBilled)}', Colors.blueGrey,
                              bold: true),
                          _dataCell('₹${_fmt(totalPaid)}',
                              Colors.green.shade700,
                              bold: true),
                          _dataCell(
                              '₹${_fmt(totalBalance)}',
                              totalBalance > 0
                                  ? Colors.red.shade700
                                  : Colors.grey,
                              bold: true),
                        ]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String t) => Expanded(
        flex: 2,
        child: Text(t,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _dataCell(String t, Color c, {bool bold = false}) => Expanded(
        flex: 2,
        child: Text(t,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: c,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13)),
      );
}

// ─── DIALOGS ──────────────────────────────────────────────────────────────────

/// Add / Edit Agency name.
class _AgencyFormDialog extends StatefulWidget {
  final AgencyPurchase? agency;
  const _AgencyFormDialog({this.agency});
  @override
  State<_AgencyFormDialog> createState() => _AgencyFormDialogState();
}

class _AgencyFormDialogState extends State<_AgencyFormDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.agency != null) _nameCtrl.text = widget.agency!.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseProvider.instance.db;
    final name = _nameCtrl.text.trim().toUpperCase();
    if (widget.agency == null) {
      await db.insertAgency(
          AgencyPurchasesCompanion.insert(name: name));
    } else {
      await db.updateAgency(AgencyPurchasesCompanion(
        id: Value(widget.agency!.id),
        name: Value(name),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.agency != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(isEdit ? 'Edit Agency' : 'Add Agency',
          style: TextStyle(color: cs.onSurface)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (old, n) => n.copyWith(text: n.text.toUpperCase()),
            ),
          ],
          decoration: InputDecoration(
            labelText: 'Agency Name',
            labelStyle: TextStyle(color: cs.onSurface),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: cs.outlineVariant)),
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _save,
            child: Text(isEdit ? 'Update' : 'Add')),
      ],
    );
  }
}

/// Add / Edit a bill for an agency.
class _BillFormDialog extends StatefulWidget {
  final int agencyId;
  final AgencyBill? bill;
  const _BillFormDialog({required this.agencyId, this.bill});
  @override
  State<_BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<_BillFormDialog> {
  final _amountCtrl = TextEditingController();
  final _billNoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _billDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _amountCtrl.text = widget.bill!.billAmount.toStringAsFixed(2);
      _billNoCtrl.text = widget.bill!.billNumber ?? '';
      _billDate = widget.bill!.billDate;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _billNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                surface: Colors.white,
                surfaceContainerHighest: Colors.white,
                surfaceContainerHigh: Colors.white,
                surfaceContainer: Colors.white,
                surfaceContainerLow: Colors.white,
                surfaceContainerLowest: Colors.white,
              ),
          dialogBackgroundColor: Colors.white,
          dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseProvider.instance.db;
    final amount = double.parse(_amountCtrl.text.trim());
    final billNo = _billNoCtrl.text.trim().isEmpty
        ? null
        : _billNoCtrl.text.trim();

    if (widget.bill == null) {
      await db.insertAgencyBill(AgencyBillsCompanion.insert(
        agencyId: widget.agencyId,
        billAmount: amount,
        billDate: _billDate,
        billNumber: Value(billNo),
      ));
    } else {
      await db.updateAgencyBill(AgencyBillsCompanion(
        id: Value(widget.bill!.id),
        agencyId: Value(widget.agencyId),
        billAmount: Value(amount),
        billDate: Value(_billDate),
        billNumber: Value(billNo),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.bill != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(isEdit ? 'Edit Bill' : 'Add Bill',
          style: TextStyle(color: cs.onSurface)),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bill Amount
              TextFormField(
                controller: _amountCtrl,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Bill Amount (₹)',
                  labelStyle: TextStyle(color: cs.onSurface),
                  prefixText: '₹ ',
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: cs.outlineVariant)),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Bill Number (optional)
              TextFormField(
                controller: _billNoCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Bill Number (optional)',
                  labelStyle: TextStyle(color: cs.onSurface),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: cs.outlineVariant)),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              // Bill Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Bill Date',
                    labelStyle: TextStyle(color: cs.onSurface),
                    suffixIcon:
                        const Icon(Icons.calendar_today, size: 18),
                    enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: cs.outlineVariant)),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_billDate),
                    style: TextStyle(color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _save,
            child: Text(isEdit ? 'Update' : 'Add Bill')),
      ],
    );
  }
}

/// Record a payment against a bill.
class _PaymentDialog extends StatefulWidget {
  final AgencyBill bill;
  final int agencyId;
  final double outstanding;
  const _PaymentDialog(
      {required this.bill,
      required this.agencyId,
      required this.outstanding});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _payDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-fill with outstanding amount
    _amountCtrl.text = widget.outstanding.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _payDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                surface: Colors.white,
                surfaceContainerHighest: Colors.white,
                surfaceContainerHigh: Colors.white,
                surfaceContainer: Colors.white,
                surfaceContainerLow: Colors.white,
                surfaceContainerLowest: Colors.white,
              ),
          dialogBackgroundColor: Colors.white,
          dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _payDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseProvider.instance.db;
    final amount = double.parse(_amountCtrl.text.trim());
    await db.insertAgencyPayment(AgencyPaymentsCompanion.insert(
      agencyId: widget.agencyId,
      billId: widget.bill.id,
      amountPaid: amount,
      paymentDate: _payDate,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Record Payment', style: TextStyle(color: cs.onSurface)),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Outstanding info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Outstanding: ₹${widget.outstanding.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // Amount paid
              TextFormField(
                controller: _amountCtrl,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  labelStyle: TextStyle(color: cs.onSurface),
                  prefixText: '₹ ',
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: cs.outlineVariant)),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final amt = double.tryParse(v.trim());
                  if (amt == null || amt <= 0) return 'Enter valid amount';
                  if (amt > widget.outstanding) {
                    return 'Cannot exceed outstanding ₹${widget.outstanding.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Payment date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    labelStyle: TextStyle(color: cs.onSurface),
                    suffixIcon:
                        const Icon(Icons.calendar_today, size: 18),
                    enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: cs.outlineVariant)),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_payDate),
                    style: TextStyle(color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _save,
            child: const Text('Record Payment')),
      ],
    );
  }
}