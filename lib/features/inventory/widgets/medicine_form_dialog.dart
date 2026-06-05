// lib/features/inventory/widgets/medicine_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class MedicineFormDialog extends StatefulWidget {
  final Medicine? medicine;
  const MedicineFormDialog({super.key, this.medicine});

  @override
  State<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _genericName = TextEditingController();
  final _manufacturer = TextEditingController();
  final _salePrice = TextEditingController();
  final _stock = TextEditingController();
  final _lowStock = TextEditingController();
  final _batch = TextEditingController();
  String _unit = 'tablet';
  DateTime? _expiryDate;
  bool _loading = false;

  static const _units = ['tablet', 'bottle', 'tube', 'piece', 'capsule', 'kit'];

  bool get isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final m = widget.medicine!;
      _name.text = m.name;
      _genericName.text = m.genericName ?? '';
      _manufacturer.text = m.manufacturer ?? '';
      _salePrice.text = m.salePrice.toString();
      _stock.text = m.stockQty.toString();
      _lowStock.text = m.lowStockThreshold.toString();
      _batch.text = m.batchNumber ?? '';
      _unit = _units.contains(m.unit) ? m.unit : 'tablet';
      _expiryDate = m.expiryDate;
    } else {
      _stock.text = '0';
      _lowStock.text = '10';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _genericName, _manufacturer, _salePrice, _stock, _lowStock, _batch]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final db = DatabaseProvider.instance.db;
    try {
      final companion = MedicinesCompanion(
        id: isEditing ? Value(widget.medicine!.id) : const Value.absent(),
        name: Value(_name.text.trim()),
        genericName: Value(_genericName.text.trim().isEmpty ? null : _genericName.text.trim()),
        manufacturer: Value(_manufacturer.text.trim().isEmpty ? null : _manufacturer.text.trim()),
        unit: Value(_unit),
        mrp: Value(double.tryParse(_salePrice.text) ?? 0),
        salePrice: Value(double.parse(_salePrice.text)),
        stockQty: Value(int.parse(_stock.text)),
        lowStockThreshold: Value(int.parse(_lowStock.text)),
        expiryDate: Value(_expiryDate),
        batchNumber: Value(_batch.text.trim().isEmpty ? null : _batch.text.trim()),
        hsnCode: const Value(null),
        updatedAt: Value(DateTime.now()),
      );
      if (isEditing) {
        await db.updateMedicine(companion);
      } else {
        await db.insertMedicine(companion);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        isEditing ? 'Edit Medicine' : 'Add Medicine',
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Medicine Name
                _field(_name, 'Medicine Name *', required: true),
                const SizedBox(height: 16),

                // 2. Generic Name | Manufacturer
                Row(children: [
                  Expanded(child: _field(_genericName, 'Generic Name')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_manufacturer, 'Manufacturer')),
                ]),
                const SizedBox(height: 16),

                // 3. Stock Qty | Low Stock Alert
                Row(children: [
                  Expanded(child: _field(_stock, 'Stock Qty *', number: true, required: true, integer: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lowStock, 'Low Stock Alert *', number: true, required: true, integer: true)),
                ]),
                const SizedBox(height: 16),

                // 4. Unit (left) | Price per Unit (right)
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        labelStyle: TextStyle(color: cs.onSurface),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                        border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                      ),
                      items: _units
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u, style: TextStyle(color: cs.onSurface)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _salePrice,
                      'Price per Unit (₹) *',
                      number: true,
                      required: true,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // 5. Batch Number
                _field(_batch, 'Batch Number'),
                const SizedBox(height: 16),

                // 6. Expiry Date
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiry Date',
                      labelStyle: TextStyle(color: cs.onSurface),
                      prefixIcon: Icon(Icons.calendar_today, color: cs.onSurface),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                      border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: Text(
                      _expiryDate == null
                          ? 'Select expiry date'
                          : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEditing ? 'Update' : 'Add Medicine'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    bool number = false,
    bool integer = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurface),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
        border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
      ),
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters: integer ? [FilteringTextInputFormatter.digitsOnly] : null,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }
}