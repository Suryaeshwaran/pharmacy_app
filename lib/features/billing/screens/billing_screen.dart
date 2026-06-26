// lib/features/billing/screens/billing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../widgets/bill_item_row.dart';
import 'bill_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  /// When [editBill] and [editItems] are provided the screen opens in edit mode.
  final Bill? editBill;
  final List<BillItem>? editItems;

  const BillingScreen({super.key, this.editBill, this.editItems});

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
  final _consultationFeeCtrl = TextEditingController(text: '0');

  // Pharmacy payment
  String _paymentMode = 'cash'; // cash | online | partial
  final _partialCashCtrl = TextEditingController();

  // Fee payment
  String _feePaymentMode = 'cash'; // cash | online | partial
  final _feePartialCashCtrl = TextEditingController();

  // Collection
  final _collectionCtrl = TextEditingController();

  final _medicineSearch = TextEditingController();
  final _searchFocus = FocusNode();

  List<_CartItem> _cart = [];
  List<Medicine> _searchResults = [];
  bool _searching = false;
  bool _saving = false;

  // ── Visit Queue / Patient linkage ─────────────────────────────────────────
  final _pidCtrl = TextEditingController();
  List<VisitQueueData> _visitQueue = [];
  String? _selectedPid;       // pid picked from visit queue
  String? _patientPh1;        // ph1 from patient_master
  String? _patientPh2;        // ph2 from patient_master
  String? _selectedPhone;     // currently chosen phone number
  final _pidFocus = FocusNode();
  OverlayEntry? _pidOverlay;
  final _pidFieldKey = GlobalKey();

  bool get _isEditMode => widget.editBill != null;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVisitQueue();
    if (_isEditMode) {
      _prefillFromBill();
    }
  }

  Future<void> _loadVisitQueue() async {
    final queue = await DatabaseProvider.instance.db.watchVisitQueue().first;
    if (mounted) setState(() => _visitQueue = queue);
  }

  /// Pre-populate all fields from the existing bill being edited.
  Future<void> _prefillFromBill() async {
    final bill = widget.editBill!;
    final billItems = widget.editItems!;

    _customerName.text = bill.customerName ?? '';
    _customerPhone.text = bill.customerPhone ?? '';
    _discountCtrl.text = bill.discount.toStringAsFixed(2);
    _consultationFeeCtrl.text = bill.consultationFee.toStringAsFixed(2);

    // Patient ID
    if (bill.patientId != null) {
      _selectedPid = bill.patientId;
      _pidCtrl.text = bill.patientId!;
    }

    // Pharmacy payment
    _paymentMode = bill.paymentMode;
    if (bill.paymentMode == 'partial') {
      _partialCashCtrl.text = bill.cashAmount.toStringAsFixed(2);
    }

    // Fee payment
    _feePaymentMode = bill.feePaymentMode;
    if (bill.feePaymentMode == 'partial') {
      _feePartialCashCtrl.text = bill.feeCashAmount.toStringAsFixed(2);
    }

    // Collection
    if (bill.collectionAmount > 0) {
      _collectionCtrl.text = bill.collectionAmount.toStringAsFixed(2);
    }

    // Load each medicine from DB to build cart items
    final db = DatabaseProvider.instance.db;
    final List<_CartItem> cartItems = [];
    for (final item in billItems) {
      final medicine = await db.getMedicineById(item.medicineId);
      if (medicine != null) {
        cartItems.add(_CartItem(medicine: medicine, qty: item.quantity));
      } else {
        final placeholder = Medicine(
          id: item.medicineId,
          name: item.medicineName,
          unit: 'piece',
          mrp: item.salePrice,
          salePrice: item.salePrice,
          stockQty: item.quantity,
          lowStockThreshold: 0,
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        cartItems.add(_CartItem(medicine: placeholder, qty: item.quantity));
      }
    }

    if (mounted) setState(() => _cart = cartItems);
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _discountCtrl.dispose();
    _consultationFeeCtrl.dispose();
    _partialCashCtrl.dispose();
    _feePartialCashCtrl.dispose();
    _collectionCtrl.dispose();
    _medicineSearch.dispose();
    _searchFocus.dispose();
    _pidCtrl.dispose();
    _pidFocus.dispose();
    _removePidOverlay();
    super.dispose();
  }

  // ── Visit Queue overlay ───────────────────────────────────────────────────

  void _showPidOverlay() {
    _removePidOverlay();
    if (_visitQueue.isEmpty) return;

    final box = _pidFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _pidOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Full-screen transparent barrier — tapping anywhere outside the list closes it
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removePidOverlay,
            ),
          ),
          // The actual dropdown list
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            width: size.width,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _visitQueue.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = _visitQueue[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.how_to_reg_outlined, size: 18),
                      title: Text(entry.patientName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('ID: ${entry.pid}',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => _onPickFromQueue(entry),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_pidOverlay!);
  }

  void _removePidOverlay() {
    _pidOverlay?.remove();
    _pidOverlay = null;
  }

  Future<void> _onPickFromQueue(VisitQueueData entry) async {
    _removePidOverlay();
    _pidCtrl.text = entry.pid;
    _customerName.text = entry.patientName;

    // Load ph1/ph2 from patient_master
    final patient =
        await DatabaseProvider.instance.db.getPatientByPid(entry.pid);

    setState(() {
      _selectedPid = entry.pid;
      _patientPh1 = patient?.ph1;
      _patientPh2 = patient?.ph2;
      // Default to ph1
      _selectedPhone = patient?.ph1;
      _customerPhone.text = patient?.ph1 ?? entry.patientPhone ?? '';
    });
  }

  void _clearPatientSelection() {
    setState(() {
      _selectedPid = null;
      _patientPh1 = null;
      _patientPh2 = null;
      _selectedPhone = null;
    });
    _pidCtrl.clear();
    _customerName.clear();
    _customerPhone.clear();
  }

  // ── Medicine search ───────────────────────────────────────────────────────

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

  // ─── Computed totals ───────────────────────────────────────────────────────

  double get _subtotal => _cart.fold(0, (s, c) => s + c.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _consultationFee => double.tryParse(_consultationFeeCtrl.text) ?? 0;
  double get _pharmacyNet => (_subtotal - _discount).clamp(0, double.infinity);
  double get _total => (_pharmacyNet + _consultationFee).clamp(0, double.infinity);

  double get _cashAmount {
    if (_paymentMode == 'cash') return _pharmacyNet;
    if (_paymentMode == 'online') return 0;
    return double.tryParse(_partialCashCtrl.text) ?? 0;
  }

  double get _onlineAmount {
    if (_paymentMode == 'cash') return 0;
    if (_paymentMode == 'online') return _pharmacyNet;
    return (_pharmacyNet - _cashAmount).clamp(0, double.infinity);
  }

  double get _feeCashAmount {
    if (_feePaymentMode == 'cash') return _consultationFee;
    if (_feePaymentMode == 'online') return 0;
    return double.tryParse(_feePartialCashCtrl.text) ?? 0;
  }

  double get _feeOnlineAmount {
    if (_feePaymentMode == 'cash') return 0;
    if (_feePaymentMode == 'online') return _consultationFee;
    return (_consultationFee - _feeCashAmount).clamp(0, double.infinity);
  }

  bool get _canBill => _cart.isNotEmpty || _consultationFee > 0;

  bool get _showCollectionRow =>
      _paymentMode == 'cash' || _paymentMode == 'partial' ||
      _feePaymentMode == 'cash' || _feePaymentMode == 'partial';

  double get _collectionAmount => double.tryParse(_collectionCtrl.text) ?? 0;

  double get _totalCashPortion => _cashAmount + _feeCashAmount;

  double get _balance {
    // Always: collection minus the cash-only portions
    return _collectionAmount - _totalCashPortion;
  }

  // ─── Save (new bill) ───────────────────────────────────────────────────────

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
        patientId: Value(_selectedPid),
        subtotal: _subtotal,
        discount: Value(_discount),
        consultationFee: Value(_consultationFee),
        totalAmount: _total,
        paymentMode: Value(_paymentMode),
        cashAmount: Value(_cashAmount),
        onlineAmount: Value(_onlineAmount),
        feePaymentMode: Value(_feePaymentMode),
        feeCashAmount: Value(_feeCashAmount),
        feeOnlineAmount: Value(_feeOnlineAmount),
        collectionAmount: Value(_collectionAmount),
        balanceAmount: Value(_balance),
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

      // Remove from visit queue if patient was selected
      if (_selectedPid != null) {
        await db.removeFromVisitQueueByPid(_selectedPid!);
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

  // ─── Update (edit existing bill) ──────────────────────────────────────────

  Future<void> _updateBill() async {
    if (!_canBill) return;
    setState(() => _saving = true);
    final db = DatabaseProvider.instance.db;
    final originalBill = widget.editBill!;
    final originalItems = widget.editItems!;

    try {
      for (final item in originalItems) {
        await db.addStock(item.medicineId, item.quantity);
      }

      await db.updateBill(BillsCompanion(
        id: Value(originalBill.id),
        billNumber: Value(originalBill.billNumber),
        billedAt: Value(originalBill.billedAt),
        customerName: Value(_customerName.text.trim().isEmpty ? null : _customerName.text.trim()),
        customerPhone: Value(_customerPhone.text.trim().isEmpty ? null : _customerPhone.text.trim()),
        patientId: Value(_selectedPid),
        subtotal: Value(_subtotal),
        discount: Value(_discount),
        consultationFee: Value(_consultationFee),
        totalAmount: Value(_total),
        paymentMode: Value(_paymentMode),
        cashAmount: Value(_cashAmount),
        onlineAmount: Value(_onlineAmount),
        feePaymentMode: Value(_feePaymentMode),
        feeCashAmount: Value(_feeCashAmount),
        feeOnlineAmount: Value(_feeOnlineAmount),
        collectionAmount: Value(_collectionAmount),
        balanceAmount: Value(_balance),
      ));

      await db.replaceBillItems(
        originalBill.id,
        _cart.map((c) => BillItemsCompanion.insert(
          billId: originalBill.id,
          medicineId: c.medicine.id,
          medicineName: c.medicine.name,
          salePrice: c.medicine.salePrice,
          quantity: c.qty,
          totalPrice: c.total,
        )).toList(),
      );

      for (final item in _cart) {
        await db.deductStock(item.medicine.id, item.qty);
      }

      final updatedBill = await db.getBillById(originalBill.id);
      final updatedItems = await db.getBillItems(originalBill.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill updated successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => BillPreviewScreen(bill: updatedBill!, items: updatedItems),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating bill: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _cart = [];
      _searchResults = [];
      _selectedPid = null;
      _patientPh1 = null;
      _patientPh2 = null;
      _selectedPhone = null;
    });
    _pidCtrl.clear();
    _customerName.clear();
    _customerPhone.clear();
    _discountCtrl.text = '0';
    _consultationFeeCtrl.text = '0';
    _partialCashCtrl.clear();
    _feePartialCashCtrl.clear();
    _collectionCtrl.clear();
    _paymentMode = 'cash';
    _feePaymentMode = 'cash';
    _medicineSearch.clear();
    _loadVisitQueue(); // refresh queue after billing
  }

  Future<void> _confirmClear() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Clear Bill?', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'This will remove all items and customer details from the current bill.',
          style: TextStyle(color: cs.onSurface),
        ),
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
        title: Text(
          _isEditMode
              ? 'Edit Bill — ${widget.editBill!.billNumber}'
              : 'New Bill',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
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
                    hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
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
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
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
                          title: Text(m.name,
                              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            'Stock: ${m.stockQty} | ₹${m.salePrice.toStringAsFixed(2)} | Expiry: ${m.expiryDate != null ? DateFormat('dd-MMM-yyyy').format(m.expiryDate!) : 'N/A'}',
                            style: TextStyle(color: cs.onSurface),
                          ),
                          trailing: m.stockQty == 0
                              ? Chip(
                                  label: const Text('Out of stock',
                                      style: TextStyle(color: Colors.red, fontSize: 11)),
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
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
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 56, color: cs.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('Search and add medicines to bill',
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                      ]),
                    )
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
        // ── Right: Patient + Summary ──────────────────────────────────────
        Container(
          width: 320,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── Patient Details ──────────────────────────────────
                    Text('Patient Details',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: cs.onSurface)),
                    const SizedBox(height: 16),

                    // ── Patient ID (visit queue picker) ──────────────────
                    TextField(
                      key: _pidFieldKey,
                      controller: _pidCtrl,
                      readOnly: true,
                      style: TextStyle(color: cs.onSurface),
                      onTap: () {
                        if (_selectedPid != null) return; // already selected, × clears
                        _loadVisitQueue().then((_) => _showPidOverlay());
                      },
                      decoration: InputDecoration(
                        labelText: 'Patient ID (from queue)',
                        labelStyle: TextStyle(color: cs.onSurface),
                        prefixIcon: Icon(Icons.badge_outlined, color: cs.onSurface),
                        suffixIcon: _selectedPid != null
                            ? IconButton(
                                icon: Icon(Icons.clear, color: cs.onSurface),
                                onPressed: _clearPatientSelection,
                                tooltip: 'Clear selection',
                              )
                            : Icon(Icons.arrow_drop_down, color: cs.onSurface),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant)),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant)),
                      ),
                    ),
                    if (_visitQueue.isEmpty && !_isEditMode) ...[
                      const SizedBox(height: 4),
                      Text(
                        'No patients in today\'s queue',
                        style: TextStyle(fontSize: 11, color: cs.onSurface),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Name ─────────────────────────────────────────────
                    TextField(
                      controller: _customerName,
                      style: TextStyle(color: cs.onSurface),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_FirstLetterUpperCaseFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Name (optional)',
                        labelStyle: TextStyle(color: cs.onSurface),
                        prefixIcon: Icon(Icons.person_outline, color: cs.onSurface),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant)),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Phone — dropdown if ph2 exists, plain field otherwise
                    if (_patientPh2 != null) ...[
                      // Both ph1 and ph2 available — show dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedPhone,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          labelStyle: TextStyle(color: cs.onSurface),
                          prefixIcon: Icon(Icons.phone_outlined, color: cs.onSurface),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.outlineVariant)),
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.outlineVariant)),
                        ),
                        style: TextStyle(color: cs.onSurface),
                        dropdownColor: Colors.white,
                        items: [
                          if (_patientPh1 != null)
                            DropdownMenuItem(
                              value: _patientPh1,
                              child: Text(_patientPh1!,
                                  style: TextStyle(color: cs.onSurface)),
                            ),
                          DropdownMenuItem(
                            value: _patientPh2,
                            child: Text(_patientPh2!,
                                style: TextStyle(color: cs.onSurface)),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPhone = val);
                          _customerPhone.text = val ?? '';
                        },
                      ),
                    ] else ...[
                      // Single phone or manual entry
                      TextField(
                        controller: _customerPhone,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Phone (optional)',
                          labelStyle: TextStyle(color: cs.onSurface),
                          prefixIcon: Icon(Icons.phone_outlined, color: cs.onSurface),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.outlineVariant)),
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.outlineVariant)),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],

                    Divider(height: 32, color: cs.outlineVariant),

                    // ── Bill Summary ─────────────────────────────────────
                    _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}',
                        bold: true, color: cs.onSurface),
                    const SizedBox(height: 12),

                    // Discount
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
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: cs.outlineVariant)),
                            border: OutlineInputBorder(
                                borderSide: BorderSide(color: cs.outlineVariant)),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),

                    Divider(height: 32, color: cs.outlineVariant),

                    // ── Pharmacy Payment ─────────────────────────────────
                    Text('Pharmacy Payment',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.onSurface)),
                    const SizedBox(height: 10),
                    _paymentModeRow(
                      cs: cs,
                      mode: _paymentMode,
                      onChanged: (v) => setState(
                          () { _paymentMode = v; _partialCashCtrl.clear(); }),
                    ),
                    if (_paymentMode == 'partial') ...[
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Cash Amount (₹)',
                            style: TextStyle(color: cs.onSurface, fontSize: 13)),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _partialCashCtrl,
                            style: TextStyle(color: cs.onSurface),
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: cs.outlineVariant)),
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: cs.outlineVariant)),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('GPay / Online (₹)',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                        Text('₹${_onlineAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                      ]),
                    ],

                    Divider(height: 32, color: cs.outlineVariant),

                    // ── Consultation Fee ─────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Fee (₹)',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                              fontSize: 15)),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _consultationFeeCtrl,
                          style: TextStyle(color: cs.onSurface),
                          textAlign: TextAlign.end,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: cs.outlineVariant)),
                            border: OutlineInputBorder(
                                borderSide: BorderSide(color: cs.outlineVariant)),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),

                    // ── Fee Payment ──────────────────────────────────────
                    const SizedBox(height: 14),
                    Text('Fee Payment',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.onSurface)),
                    const SizedBox(height: 10),
                    _paymentModeRow(
                      cs: cs,
                      mode: _feePaymentMode,
                      onChanged: (v) => setState(
                          () { _feePaymentMode = v; _feePartialCashCtrl.clear(); }),
                    ),
                    if (_feePaymentMode == 'partial' && _consultationFee > 0) ...[
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Cash Amount (₹)',
                            style: TextStyle(color: cs.onSurface, fontSize: 13)),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _feePartialCashCtrl,
                            style: TextStyle(color: cs.onSurface),
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: cs.outlineVariant)),
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: cs.outlineVariant)),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('GPay / Online (₹)',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                        Text('₹${_feeOnlineAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                      ]),
                    ],

                    Divider(height: 32, color: cs.outlineVariant),

                    // ── Total ────────────────────────────────────────────
                    _summaryRow('Total', '₹${_total.toStringAsFixed(2)}',
                        bold: true, large: true, color: cs.onSurface),

                    // ── Collection & Balance ──────────────────────────────
                    if (_showCollectionRow) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        // Collection inline text field
                        Expanded(
                          child: TextField(
                            controller: _collectionCtrl,
                            style: TextStyle(
                                color: cs.onSurface, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.start,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Collection',
                              labelStyle: TextStyle(color: cs.onSurface),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant)),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Balance display
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Balance',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurface)),
                          Text(
                            '₹${_balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _balance < 0 ? Colors.red : Colors.green.shade800,
                            ),
                          ),
                        ]),
                      ]),
                    ],

                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              // ── Bottom action buttons ────────────────────────────────────
              if (_canBill && !_isEditMode) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _confirmClear,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Clear & New Bill',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
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
                  onPressed: (_canBill && !_saving)
                      ? (_isEditMode ? _updateBill : _saveBill)
                      : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(_isEditMode ? Icons.save_outlined : Icons.receipt_long),
                  label: Text(
                    _isEditMode ? 'Save Changes' : 'Generate Bill',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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

  /// Compact single-row chip/pill selector for Cash / GPay / Partial.
  /// No amounts shown inline — keeps the row short and avoids text overlap.
  Widget _paymentModeRow({
    required ColorScheme cs,
    required String mode,
    required ValueChanged<String> onChanged,
  }) {
    final options = const [
      ('cash', 'Cash', Icons.payments_outlined),
      ('online', 'GPay', Icons.phone_android_outlined),
      ('partial', 'Partial', Icons.call_split_outlined),
    ];

    return Row(
      children: options.map((opt) {
        final value = opt.$1;
        final label = opt.$2;
        final icon = opt.$3;
        final selected = mode == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: value == 'partial' ? 0 : 8),
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 15,
                          color: selected
                              ? cs.onPrimary
                              : cs.onSurface.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurface.withValues(alpha: 0.8),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, bool large = false, required Color color}) {
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

class _FirstLetterUpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final formatted = text[0].toUpperCase() + text.substring(1);
    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection,
    );
  }
}