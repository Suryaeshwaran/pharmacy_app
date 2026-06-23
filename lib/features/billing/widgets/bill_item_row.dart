// lib/features/billing/widgets/bill_item_row.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';

class BillItemRow extends StatefulWidget {
  final Medicine medicine;
  final int qty;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const BillItemRow({
    super.key, 
    required this.medicine, 
    required this.qty, 
    required this.onQtyChanged, 
    required this.onRemove,
  });

  @override
  State<BillItemRow> createState() => _BillItemRowState();
}

class _BillItemRowState extends State<BillItemRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(BillItemRow old) {
    super.didUpdateWidget(old);
    if (old.qty != widget.qty) _ctrl.text = widget.qty.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Left Side: Medicine Text details (Expanded prevents it from pushing widgets outwards)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.medicine.name, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600, 
                      fontSize: 14, 
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Rate: ₹${widget.medicine.salePrice.toStringAsFixed(2)}', 
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.8)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Total: ₹${(widget.medicine.salePrice * widget.qty).toStringAsFixed(2)}', 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600, 
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            // Middle: Compact Quantity Controls grouped cleanly to prevent right margin overflow
            Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.remove_circle_outline, color: cs.onSurface),
                  iconSize: 20,
                  onPressed: () => widget.onQtyChanged(widget.qty - 1),
                ),
                SizedBox(
                  width: 44, // Slightly narrowed field to safely accommodate the screen view bounds
                  child: TextField(
                    controller: _ctrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface, fontSize: 13),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true, 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onChanged: (v) {
                      final qty = int.tryParse(v) ?? 1;
                      widget.onQtyChanged(qty);
                    },
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.add_circle_outline, color: cs.onSurface),
                  iconSize: 20,
                  onPressed: widget.qty < widget.medicine.stockQty 
                      ? () => widget.onQtyChanged(widget.qty + 1) 
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 4),
            
            // Right Side: Delete Button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Remove',
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}