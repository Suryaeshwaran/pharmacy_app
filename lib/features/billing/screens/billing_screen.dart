// lib/features/billing/screens/billing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../widgets/bill_item_row.dart';
import 'bill_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _CartItem {
  final Medicine medicine;
  int qty;
  _CartItem({required this.medicine, required this.qty});
  double get total => medicine.salePrice * qty;
}

class _BillingScreenState extends State<BillingScreen>
    with AutomaticKeepAliveClientMixin {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _medicineSearch = TextEditingController();
  final _searchFocus = FocusNode();

  List<_CartItem> _cart = [];
  List<Medicine> _searchResults = [];
  bool _searching = false;
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _discountCtrl.dispose();
    _medicineSearch.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final results = await DatabaseProvider.instance.db.searchMedicines(query);
    setState(() { _searchResults = results; _searching = false; });
  }

  void _addToCart(Medicine m) {
    setState(() {
      final existing = _cart.indexWhere((c) => c.medicine.id == m.id);
      if (existing >= 0) {
        _cart[existing].qty++;
      } else {
        _cart.add(_CartItem(medicine: m, qty: 1));
      }
      _searchResults = [];
      _medicineSearch.clear();
    });
  }

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  void _updateQty(int index, int qty) {
    if (qty <= 0) {
      _removeFromCart(index);
    } else {
      setState(() => _cart[index].qty = qty);
    }
  }

  double get _subtotal => _cart.fold(0, (s, c) => s + c.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  bool get _canBill => _cart.isNotEmpty;

  Future<void> _saveBill() async {
    if (!_canBill) return;
    setState(() => _saving = true);
    final db = DatabaseProvider.instance.db;
    try {
      final billNumber = await db.generateBillNumber();
      final billId = await db.insertBill(BillsCompanion.insert(
        billNumber: billNumber,
        customerName: Value(_customerName.text.trim().isEmpty ? null : _customerName.text.trim()),
        customerPhone: Value(_customerPhone.text.trim().isEmpty ? null : _customerPhone.text.trim()),
        subtotal: _subtotal,
        discount: Value(_discount),
        totalAmount: _total,
      ));

      await db.insertBillItems(_cart.map((c) => BillItemsCompanion.insert(
        billId: billId,
        medicineId: c.medicine.id,
        medicineName: c.medicine.name,
        salePrice: c.medicine.salePrice,
        quantity: c.qty,
        totalPrice: c.total,
      )).toList());

      for (final item in _cart) {
        await db.deductStock(item.medicine.id, item.qty);
      }

      final bill = await db.getBillById(billId);
      final items = await db.getBillItems(billId);

      if (mounted) {
        _resetForm();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => BillPreviewScreen(bill: bill!, items: items),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving bill: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    setState(() { _cart = []; _searchResults = []; });
    _customerName.clear();
    _customerPhone.clear();
    _discountCtrl.text = '0';
    _medicineSearch.clear();
  }

  Future<void> _confirmClear() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Clear Bill?', style: TextStyle(color: cs.onSurface)),
        content: Text('This will remove all items and customer details from the current bill.', style: TextStyle(color: cs.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text('New Bill', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
      ),
      body: Row(children: [
        // ── Left: Medicine search + cart ──────────────────────────────────
        Expanded(
          flex: 3,
          child: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: _medicineSearch,
                  focusNode: _searchFocus,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search medicine by name...',
                    hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: cs.onSurface),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                    border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                    fillColor: Colors.white,
                    filled: true,
                    suffixIcon: _searching
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final m = _searchResults[i];
                        return ListTile(
                          dense: true,
                          title: Text(m.name, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500)),
                          subtitle: Text('Stock: ${m.stockQty} | ₹${m.salePrice.toStringAsFixed(2)}', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                          trailing: m.stockQty == 0
                              ? Chip(
                                  label: const Text('Out of stock', style: TextStyle(color: Colors.red, fontSize: 11)),
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                  side: BorderSide.none,
                                )
                              : Icon(Icons.add_circle_outline, color: cs.primary),
                          onTap: m.stockQty > 0 ? () => _addToCart(m) : null,
                        );
                      },
                    ),
                  ),
              ]),
            ),
            // Cart items
            Expanded(
              child: _cart.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shopping_cart_outlined, size: 56, color: cs.onSurface.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('Search and add medicines to bill', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _cart.length,
                      itemBuilder: (_, i) => BillItemRow(
                        medicine: _cart[i].medicine,
                        qty: _cart[i].qty,
                        onQtyChanged: (q) => _updateQty(i, q),
                        onRemove: () => _removeFromCart(i),
                      ),
                    ),
            ),
          ]),
        ),
        VerticalDivider(width: 1, color: cs.outlineVariant),
        // ── Right: Customer + Summary ─────────────────────────────────────
        Container(
          width: 320,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
              const SizedBox(height: 16),
              TextField(
                controller: _customerName,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Name (optional)',
                  labelStyle: TextStyle(color: cs.onSurface),
                  prefixIcon: Icon(Icons.person_outline, color: cs.onSurface),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                  border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerPhone,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  labelStyle: TextStyle(color: cs.onSurface),
                  prefixIcon: Icon(Icons.phone_outlined, color: cs.onSurface),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                  border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              Divider(height: 32, color: cs.outlineVariant),
              Text('Bill Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
              const SizedBox(height: 16),
              _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}', color: cs.onSurface),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Discount (₹)', style: TextStyle(color: cs.onSurface)),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _discountCtrl,
                    style: TextStyle(color: cs.onSurface),
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      isDense: true, 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                      border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              Divider(height: 32, color: cs.outlineVariant),
              _summaryRow('Total', '₹${_total.toStringAsFixed(2)}', bold: true, large: true, color: cs.onSurface),
              const Spacer(),
              if (_canBill) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _confirmClear,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Clear & New Bill', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_canBill && !_saving) ? _saveBill : null,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.receipt_long),
                  label: const Text('Generate Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, bool large = false, required Color color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: large ? 18 : 14,
      color: color,
    );
    return Row(children: [
      Text(label, style: style),
      const Spacer(),
      Text(value, style: style),
    ]);
  }
}