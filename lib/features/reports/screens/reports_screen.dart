// lib/features/reports/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../billing/screens/bill_preview_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              surface: Colors.white,
              onSurface: cs.onSurface,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: cs.primary,
              headerForegroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickMonth() async {
    final cs = Theme.of(context).colorScheme;
    int tempYear = _selectedMonth.year;
    int? pickedMonth;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Select Month',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 300,
            height: 320,
            child: Column(children: [
              // Year navigation row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: tempYear > 2020
                        ? () => setLocal(() => tempYear--)
                        : null,
                  ),
                  Text(
                    '$tempYear',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: tempYear < DateTime.now().year
                        ? () => setLocal(() => tempYear++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Month grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(12, (i) {
                    final month = i + 1;
                    final isSelected = tempYear == _selectedMonth.year && month == _selectedMonth.month;
                    final isDisabled = DateTime(tempYear, month).isAfter(DateTime.now());
                    return GestureDetector(
                      onTap: isDisabled ? null : () {
                        pickedMonth = month;
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? cs.primary : cs.outline.withOpacity(0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('MMM').format(DateTime(2000, month)),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isDisabled
                                ? cs.onSurface.withOpacity(0.3)
                                : isSelected
                                    ? Colors.white
                                    : cs.onSurface,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (pickedMonth != null) {
      setState(() => _selectedMonth = DateTime(tempYear, pickedMonth!));
    }
  }

  Future<void> _pickYear() async {
    final cs = Theme.of(context).colorScheme;
    DateTime temp = _selectedYear;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Select Year',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: cs.copyWith(
                surface: Colors.white,
                onSurface: cs.onSurface,
              ),
            ),
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              selectedDate: temp,
              onChanged: (d) {
                temp = d;
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
    setState(() => _selectedYear = temp);
  }

  Widget _buildDailyReport() {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('Change'),
            onPressed: _pickDate,
          ),
        ]),
      ),
      Expanded(child: StreamBuilder<List<Bill>>(
        stream: DatabaseProvider.instance.db.watchBillsByDateRange(start, end),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bills = snap.data!;
          final sales = bills.fold(0.0, (s, b) => s + b.subtotal - b.discount);
          final fee = bills.fold(0.0, (s, b) => s + b.consultationFee);
          final total = bills.fold(0.0, (s, b) => s + b.totalAmount);
          return Column(children: [
            // Summary cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _SummaryCard(label: 'Total Bills', value: '${bills.length}', icon: Icons.receipt),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Sales', value: '₹${sales.toStringAsFixed(2)}', icon: Icons.currency_rupee),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Fee', value: '₹${fee.toStringAsFixed(2)}', icon: Icons.medical_services_outlined),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Total', value: '₹${total.toStringAsFixed(2)}', icon: Icons.account_balance_wallet_outlined),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(child: bills.isEmpty
              ? Center(child: Text('No bills on this date', style: textTheme.bodySmall?.copyWith(color: cs.onSurface)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bills.length,
                  itemBuilder: (_, i) => _BillRow(bill: bills[i]),
                ),
            ),
          ]);
        },
      )),
    ]);
  }

  Widget _buildMonthlyReport() {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text('Change'),
            onPressed: _pickMonth,
          ),
        ]),
      ),
      Expanded(child: StreamBuilder<List<Bill>>(
        stream: DatabaseProvider.instance.db.watchBillsByDateRange(start, end),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bills = snap.data!;
          final sales = bills.fold(0.0, (s, b) => s + b.subtotal - b.discount);
          final fee = bills.fold(0.0, (s, b) => s + b.consultationFee);
          final total = bills.fold(0.0, (s, b) => s + b.totalAmount);

          // Group by day
          final Map<String, List<Bill>> byDay = {};
          for (final b in bills) {
            final key = DateFormat('dd MMM').format(b.billedAt);
            byDay.putIfAbsent(key, () => []).add(b);
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _SummaryCard(label: 'Total Bills', value: '${bills.length}', icon: Icons.receipt),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Sales', value: '₹${sales.toStringAsFixed(2)}', icon: Icons.currency_rupee),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Fee', value: '₹${fee.toStringAsFixed(2)}', icon: Icons.medical_services_outlined),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Total', value: '₹${total.toStringAsFixed(2)}', icon: Icons.account_balance_wallet_outlined),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(child: byDay.isEmpty
              ? Center(child: Text('No bills this month', style: textTheme.bodySmall?.copyWith(color: cs.onSurface)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: byDay.length,
                  itemBuilder: (_, i) {
                    final day = byDay.keys.toList().reversed.toList()[i];
                    final dayBills = byDay[day]!;
                    final dayTotal = dayBills.fold(0.0, (s, b) => s + b.totalAmount);
                    return ExpansionTile(
                      title: Text(day, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                      subtitle: Text('${dayBills.length} bills • ₹${dayTotal.toStringAsFixed(2)}', style: TextStyle(color: cs.onSurface)),
                      children: dayBills.map((b) => _BillRow(bill: b)).toList(),
                    );
                  },
                ),
            ),
          ]);
        },
      )),
    ]);
  }

  Widget _buildYearlyReport() {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime(_selectedYear.year, 1, 1);
    final end = DateTime(_selectedYear.year, 12, 31, 23, 59, 59);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('Year: ${_selectedYear.year}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('Change'),
            onPressed: _pickYear,
          ),
        ]),
      ),
      Expanded(child: StreamBuilder<List<Bill>>(
        stream: DatabaseProvider.instance.db.watchBillsByDateRange(start, end),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bills = snap.data!;
          final sales = bills.fold(0.0, (s, b) => s + b.subtotal - b.discount);
          final fee = bills.fold(0.0, (s, b) => s + b.consultationFee);
          final total = bills.fold(0.0, (s, b) => s + b.totalAmount);

          // Group by month
          final Map<int, List<Bill>> byMonth = {};
          for (final b in bills) {
            byMonth.putIfAbsent(b.billedAt.month, () => []).add(b);
          }
          final sortedMonths = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _SummaryCard(label: 'Total Bills', value: '${bills.length}', icon: Icons.receipt),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Sales', value: '₹${sales.toStringAsFixed(2)}', icon: Icons.currency_rupee),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Fee', value: '₹${fee.toStringAsFixed(2)}', icon: Icons.medical_services_outlined),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Total', value: '₹${total.toStringAsFixed(2)}', icon: Icons.account_balance_wallet_outlined),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(child: byMonth.isEmpty
              ? Center(child: Text('No bills this year', style: textTheme.bodySmall?.copyWith(color: cs.onSurface)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedMonths.length,
                  itemBuilder: (_, i) {
                    final monthNum = sortedMonths[i];
                    final monthBills = byMonth[monthNum]!;
                    final monthTotal = monthBills.fold(0.0, (s, b) => s + b.totalAmount);
                    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_selectedYear.year, monthNum));
                    return ExpansionTile(
                      title: Text(monthLabel, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                      subtitle: Text('${monthBills.length} bills • ₹${monthTotal.toStringAsFixed(2)}', style: TextStyle(color: cs.onSurface)),
                      children: monthBills.map((b) => _BillRow(bill: b)).toList(),
                    );
                  },
                ),
            ),
          ]);
        },
      )),
    ]);
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
          'Sales Reports', 
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(icon: Icon(Icons.today), text: 'Daily'),
          Tab(icon: Icon(Icons.calendar_month), text: 'Monthly'),
          Tab(icon: Icon(Icons.calendar_today), text: 'Yearly'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildDailyReport(),
        _buildMonthlyReport(),
        _buildYearlyReport(),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(child: Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface)),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),
          ]),
        ]),
      ),
    ));
  }
}

class _BillRow extends StatelessWidget {
  final Bill bill;
  const _BillRow({required this.bill});

  Future<void> _openBillPreview(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final items = await DatabaseProvider.instance.db.getBillItems(bill.id);
      if (context.mounted) {
        Navigator.pop(context); // dismiss loader
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillPreviewScreen(bill: bill, items: items),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load bill details')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.receipt_outlined),
      title: Text(bill.billNumber, style: TextStyle(color: cs.onSurface)),
      subtitle: Text(bill.customerName ?? 'Walk-in customer', style: TextStyle(color: cs.onSurface)),
      trailing: Text('₹${bill.totalAmount.toStringAsFixed(2)}',
        style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
      onTap: () => _openBillPreview(context),
    );
  }
}