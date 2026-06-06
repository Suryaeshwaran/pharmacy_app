// lib/features/inventory/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../widgets/medicine_form_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAdd() => showDialog(context: context, builder: (_) => const MedicineFormDialog());
  void _openEdit(Medicine m) => showDialog(context: context, builder: (_) => MedicineFormDialog(medicine: m));

  Future<void> _adjustStock(Medicine m) async {
    final ctrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    String mode = 'add';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Adjust Stock — ${m.name}', style: TextStyle(color: cs.onSurface)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current stock: ${m.stockQty} ${m.unit}', style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'add', label: Text('Add')),
              ButtonSegment(value: 'deduct', label: Text('Deduct')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setSt(() => mode = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(color: cs.onSurface),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity to $mode',
              labelStyle: TextStyle(color: cs.onSurface),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
              border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      )),
    );
    if (confirmed == true && ctrl.text.isNotEmpty) {
      final qty = int.tryParse(ctrl.text) ?? 0;
      if (qty > 0) {
        final db = DatabaseProvider.instance.db;
        mode == 'add' ? await db.addStock(m.id, qty) : await db.deductStock(m.id, qty);
      }
    }
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete Medicine', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Delete ${medicine.name}? This cannot be undone.',
          style: TextStyle(color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseProvider.instance.db.deleteMedicine(medicine.id);
    }
  }

  Widget _buildMedicineList(Stream<List<Medicine>> stream, {bool filterBySearch = false}) {
    return StreamBuilder<List<Medicine>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var list = snap.data!;
        if (filterBySearch && _searchQuery.isNotEmpty) {
          list = list.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }
        if (list.isEmpty) return _empty();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: list.length,
          itemBuilder: (_, i) => _MedicineTile(
            medicine: list[i],
            onEdit: () => _openEdit(list[i]),
            onAdjustStock: () => _adjustStock(list[i]),
            onDelete: () => _deleteMedicine(list[i]),
          ),
        );
      },
    );
  }

  Widget _empty() {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inventory_2_outlined, size: 56, color: cs.onSurface),
      const SizedBox(height: 12),
      Text('No medicines found', style: TextStyle(color: cs.onSurface)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseProvider.instance.db;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Inventory', 
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(controller: _tabs, tabs: [
          const Tab(icon: Icon(Icons.list), text: 'All'),
          Tab(
            icon: StreamBuilder<List<Medicine>>(
              stream: db.watchLowStockMedicines(),
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                if (count == 0) return const Icon(Icons.warning_amber);
                return Badge.count(
                  count: count,
                  backgroundColor: Colors.orange.shade700,
                  child: Icon(Icons.warning_amber, color: Colors.orange.shade700),
                );
              },
            ),
            text: 'Low Stock',
          ),
          Tab(
            icon: StreamBuilder<List<Medicine>>(
              stream: db.watchExpiringMedicines(),
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                if (count == 0) return const Icon(Icons.event_busy);
                return Badge.count(
                  count: count,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.event_busy, color: Colors.red),
                );
              },
            ),
            text: 'Expiring',
          ),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SizedBox(
              width: 220,
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search medicine...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => _searchCtrl.clear())
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildMedicineList(db.watchAllMedicines(), filterBySearch: true),
        _buildMedicineList(db.watchLowStockMedicines()),
        _buildMedicineList(db.watchExpiringMedicines()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  const _MedicineTile({required this.medicine, required this.onEdit, required this.onAdjustStock  , required this.onDelete});

  Color _stockColor(BuildContext context) {
    if (medicine.stockQty == 0) return Theme.of(context).colorScheme.error;
    if (medicine.stockQty <= medicine.lowStockThreshold) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _expiryColor() {
    if (medicine.expiryDate == null) return Colors.black;
    final days = medicine.expiryDate!.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red.shade700;
    if (days <= 30) return Colors.red.shade700;
    if (days <= 90) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  String _expiryText() {
    if (medicine.expiryDate == null) return 'No expiry';
    return 'Exp: ${DateFormat('MMM yyyy').format(medicine.expiryDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(medicine.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface))),
              _badge('${medicine.stockQty} ${medicine.unit}', _stockColor(context)),
            ]),
            if (medicine.genericName != null) ...[
              const SizedBox(height: 2),
              Text(medicine.genericName!, style: TextStyle(fontSize: 12, color: cs.onSurface)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Text('MRP: ₹${medicine.mrp.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: cs.onSurface)),
              const SizedBox(width: 12),
              Text('Sale: ₹${medicine.salePrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface)),
              const SizedBox(width: 12),
              Text(_expiryText(), style: TextStyle(fontSize: 12, color: _expiryColor(), fontWeight: FontWeight.w600)),
            ]),
          ])),
          IconButton(icon: Icon(Icons.add_box_outlined, color: cs.onSurface), tooltip: 'Adjust Stock', onPressed: onAdjustStock),
          IconButton(icon: Icon(Icons.edit_outlined, color: cs.onSurface), tooltip: 'Edit', onPressed: onEdit),
          IconButton(
              icon: Icon(Icons.delete_outline, color: medicine.stockQty == 0 ? cs.onSurface : cs.outlineVariant),
              tooltip: medicine.stockQty == 0
                  ? 'Delete'
                  : 'Cannot delete while stock exists',
              onPressed: medicine.stockQty == 0
                  ? onDelete
                  : null,
            ),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );
}