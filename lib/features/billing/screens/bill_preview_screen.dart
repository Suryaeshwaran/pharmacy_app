// lib/features/billing/screens/bill_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class BillPreviewScreen extends StatefulWidget {
  final Bill bill;
  final List<BillItem> items;

  const BillPreviewScreen({super.key, required this.bill, required this.items});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  Bill get bill => widget.bill;
  List<BillItem> get items => widget.items;

  /// Show Collection/Balance only when there is a cash component somewhere.
  /// Pure GPay (both modes online, or one online + fee is zero) → hide.
  bool get _showCollectionBalance {
    if (bill.collectionAmount <= 0) return false;
    final pharmacyIsOnline = bill.paymentMode == 'online';
    final feeIsOnline = bill.feePaymentMode == 'online' || bill.consultationFee == 0;
    return !(pharmacyIsOnline && feeIsOnline);
  }

  String _pharmacyName = 'Pharmacy';
  String? _pharmacyAddress;
  String? _pharmacyCity;
  String? _pharmacyGstn;
  String? _pharmacyRegn;
  String? _pharmacyPhone;

  @override
  void initState() {
    super.initState();
    _loadPharmacyInfo();
  }

  Future<void> _loadPharmacyInfo() async {
    try {
      final info = await DatabaseProvider.instance.db.getPharmacyInfo();
      if (info != null && mounted) {
        setState(() {
          if (info.name.isNotEmpty) _pharmacyName = info.name;
          _pharmacyAddress = info.address;
          _pharmacyCity = info.city;
          _pharmacyGstn = info.gstn;
          _pharmacyRegn = info.regn;
          _pharmacyPhone = info.phone;
        });
      }
    } catch (_) {}
  }

  /// Header lines derived from PharmacyInfo — a field with no data is
  /// skipped entirely (label and all), not just left blank.
  List<String> _pharmacyHeaderLines() {
    final lines = <String>[_pharmacyName];

    final address = (_pharmacyAddress ?? '').trim();
    final city = (_pharmacyCity ?? '').trim();
    if (address.isNotEmpty && city.isNotEmpty) {
      lines.add('$address, $city');
    } else if (address.isNotEmpty) {
      lines.add(address);
    } else if (city.isNotEmpty) {
      lines.add(city);
    }

    final gstn = (_pharmacyGstn ?? '').trim();
    if (gstn.isNotEmpty) lines.add('GSTN: $gstn');

    final regn = (_pharmacyRegn ?? '').trim();
    if (regn.isNotEmpty) lines.add('REGN: $regn');

    final phone = (_pharmacyPhone ?? '').trim();
    if (phone.isNotEmpty) lines.add('Phone: $phone');

    return lines;
  }

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf({PdfPageFormat? format}) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.billedAt);
    final pageFormat = format ?? PdfPageFormat.a5;

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(children: [
              pw.Text(_pharmacyHeaderLines().first,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ..._pharmacyHeaderLines().skip(1).map((line) => pw.Text(line,
                  style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Text('Bill No: ${bill.billNumber}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: $dateStr',
                  style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.Divider(),
          if (bill.customerName != null) ...[
            pw.Text('Name: ${bill.customerName}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (bill.patientId != null)
              pw.Text('ID: ${bill.patientId}',
                  style: const pw.TextStyle(fontSize: 10)),
            if (bill.customerPhone != null)
              pw.Text('Phone: ${bill.customerPhone}'),
            pw.SizedBox(height: 8),
          ],
          pw.Row(children: [
            pw.Expanded(
                flex: 4,
                child: pw.Text('Medicines',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Expanded(
                child: pw.Text('Qty',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Expanded(
                child: pw.Text('Rate',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Expanded(
                child: pw.Text('Amount',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ]),
          pw.Divider(thickness: 0.5),
          ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text(item.medicineName,
                          style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(
                      child: pw.Text('${item.quantity}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(
                      child: pw.Text(
                          item.salePrice.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 10))),
                  pw.Expanded(
                      child: pw.Text(
                          item.totalPrice.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 10))),
                ]),
              )),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Subtotal: ${bill.subtotal.toStringAsFixed(2)}'),
                    if (bill.discount > 0)
                      pw.Text(
                          'Discount: -${bill.discount.toStringAsFixed(2)}'),
                    if (bill.consultationFee > 0)
                      pw.Text(
                          'Fee: ${bill.consultationFee.toStringAsFixed(2)}'),
                    pw.Text(
                        'TOTAL: ${bill.totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    if (_showCollectionBalance) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Collection: ${bill.collectionAmount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Balance: ${bill.balanceAmount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ]),
            ],
          ),
          pw.Divider(),
          pw.Center(
              child: pw.Text(
                  'Medicines once sold are non-returnable. \n Thank you for your understanding.',
                  style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    ));
    return pdf.save();
  }

  // ── Save PDF to Downloads (desktop) or temp (mobile) ─────────────────────

  Future<File> _savePdfFile() async {
    final data = await _generatePdf();

    Directory dir;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      dir = downloads ?? await getTemporaryDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }

    final file = File(
        '${dir.path}${Platform.pathSeparator}${bill.billNumber}.pdf');
    await file.writeAsBytes(data);
    return file;
  }

  // Auto-delete the temp PDF file after a delay
  void _scheduleFileDeletion(File file) {
    Future.delayed(const Duration(seconds: 30), () {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    });
  }

  // ── Print / Save PDF ──────────────────────────────────────────────────────

  Future<void> _printPdf(BuildContext context) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final file = await _savePdfFile();
      final result = await OpenFilex.open(file.path);
      _scheduleFileDeletion(file);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${result.message}')),
        );
      }
    } else {
      final data = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) => data);
    }
  }

  // ── Print (native print dialog, correct page format) ──────────────────────
  // Defaults to A5 Portrait. Printing.layoutPdf() passes this PdfPageFormat
  // to the OS print dialog as the default, but the user can still switch to
  // Landscape (or any other paper size) from within that native dialog.

  Future<void> _printBill(BuildContext context) async {
    final format = PdfPageFormat.a5;
    final data = await _generatePdf(format: format);
    await Printing.layoutPdf(onLayout: (_) => data, format: format);
  }

  // ── WhatsApp share ────────────────────────────────────────────────────────

  String _buildWhatsAppMessage() {
    final lines = items
        .map((i) =>
            '  ${i.medicineName} x${i.quantity} = ${i.totalPrice.toStringAsFixed(2)}')
        .join('\n');

    final headerLines = _pharmacyHeaderLines();
    final header = ' *${headerLines.first}*\n'
        '${headerLines.skip(1).map((l) => ' $l').join('\n')}'
        '${headerLines.length > 1 ? '\n' : ''}';

    return '$header'
        '━━━━━━━━━━━━━━━━━━\n'
        'Bill No: ${bill.billNumber}\n'
        'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.billedAt)}\n'
        '${bill.customerName != null ? 'Name: ${bill.customerName}\n' : ''}'
        '${bill.patientId != null ? 'ID: ${bill.patientId}\n' : ''}'
        '${bill.customerPhone != null ? 'Phone: ${bill.customerPhone}\n' : ''}'
        '━━━━━━━━━━━━━━━━━━\n'
        '*Medicines:*\n$lines\n'
        '━━━━━━━━━━━━━━━━━━\n'
        'Subtotal: ${bill.subtotal.toStringAsFixed(2)}'
        '${bill.discount > 0 ? '\nDiscount: -${bill.discount.toStringAsFixed(2)}' : ''}'
        '${bill.consultationFee > 0 ? '\nFee: ${bill.consultationFee.toStringAsFixed(2)}' : ''}\n'
        '*Total: ${bill.totalAmount.toStringAsFixed(2)}*\n'
        '${_showCollectionBalance ? 'Collection: ${bill.collectionAmount.toStringAsFixed(2)}\nBalance: ${bill.balanceAmount.toStringAsFixed(2)}\n' : ''}'
        '━━━━━━━━━━━━━━━━━━\n'
        '*Medicines once sold are non-returnable.*\n'
        '*Thank you for your understanding.*';
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    String phone = bill.customerPhone?.trim() ?? '';

    if (phone.isEmpty) {
      final phoneCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Enter Phone Number',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'WhatsApp Number',
                labelStyle: TextStyle(color: cs.onSurface),
                hintText: '10-digit mobile number',
                prefixText: '+91  ',
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Share'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
      phone = phoneCtrl.text.trim();
      if (phone.isEmpty) return;
    }

    final msg = _buildWhatsAppMessage();
    final encoded = Uri.encodeComponent(msg);

    final webUrl = phone.isNotEmpty
        ? Uri.parse('https://wa.me/91$phone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    if (Platform.isAndroid || Platform.isIOS) {
      final appUrl = phone.isNotEmpty
          ? Uri.parse('whatsapp://send?phone=91$phone&text=$encoded')
          : Uri.parse('whatsapp://send?text=$encoded');

      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Bill — ${bill.billNumber}',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: cs.onSurface),
            tooltip: isDesktop ? 'Save & Open PDF' : 'Save PDF',
            onPressed: () => _printPdf(context),
          ),
          IconButton(
            icon: Icon(Icons.print, color: cs.onSurface),
            tooltip: 'Print',
            onPressed: () => _printBill(context),
          ),
          IconButton(
            icon: Icon(Icons.chat, color: cs.onSurface),
            tooltip: 'Share via WhatsApp',
            onPressed: () => _shareWhatsApp(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Column(children: [
                        Text(_pharmacyHeaderLines().first,
                            style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        ..._pharmacyHeaderLines().skip(1).map((line) => Text(
                            line,
                            style: textTheme.bodySmall
                                ?.copyWith(color: cs.onSurface))),
                        const SizedBox(height: 6),
                        Text('Bill No: ${bill.billNumber}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                            DateFormat('dd MMM yyyy, hh:mm a')
                                .format(bill.billedAt),
                            style: textTheme.bodySmall
                                ?.copyWith(color: cs.onSurface)),
                      ])),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
                      ),
                      if (bill.customerName != null) ...[
                        Text('Name: ${bill.customerName}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: 14)),
                        if (bill.patientId != null) ...[
                          const SizedBox(height: 2),
                          Text('ID: ${bill.patientId}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        ],
                        if (bill.customerPhone != null) ...[
                          const SizedBox(height: 2),
                          Text('Phone: ${bill.customerPhone}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        ],
                        const SizedBox(height: 16),
                      ],
                      Row(children: [
                        Expanded(
                            flex: 4,
                            child: Text('Medicines',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface))),
                        SizedBox(
                            width: 40,
                            child: Text('Qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface))),
                        SizedBox(
                            width: 70,
                            child: Text('Rate',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface))),
                        SizedBox(
                            width: 80,
                            child: Text('Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface))),
                      ]),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: cs.outlineVariant, height: 1),
                      ),
                      ...items.map((item) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(
                                  flex: 4,
                                  child: Text(item.medicineName,
                                      style: TextStyle(
                                          fontSize: 13, color: cs.onSurface))),
                              SizedBox(
                                  width: 40,
                                  child: Text('${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13, color: cs.onSurface))),
                              SizedBox(
                                  width: 70,
                                  child: Text(
                                      item.salePrice.toStringAsFixed(2),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 13, color: cs.onSurface))),
                              SizedBox(
                                  width: 80,
                                  child: Text(
                                      item.totalPrice.toStringAsFixed(2),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface))),
                            ]),
                          )),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: cs.outlineVariant, height: 1),
                      ),
                      const SizedBox(height: 4),
                      Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    'Subtotal: ₹${bill.subtotal.toStringAsFixed(2)}',
                                    style: TextStyle(color: cs.onSurface, fontSize: 13)),
                                if (bill.discount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                      'Discount: -₹${bill.discount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                                if (bill.consultationFee > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                      'Fee: ₹${bill.consultationFee.toStringAsFixed(2)}',
                                      style: TextStyle(color: cs.onSurface, fontSize: 13)),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                    'TOTAL: ₹${bill.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface)),
                                const SizedBox(height: 8),
                                if (bill.consultationFee > 0) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Fee: ',
                                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                                      Text(
                                        bill.feePaymentMode == 'partial'
                                            ? 'Cash ₹${bill.feeCashAmount.toStringAsFixed(2)} / GPay ₹${bill.feeOnlineAmount.toStringAsFixed(2)}'
                                            : bill.feePaymentMode == 'online'
                                                ? 'GPay/Online'
                                                : 'Cash',
                                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if ((bill.subtotal - bill.discount) > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Pharmacy: ',
                                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                                      Text(
                                        bill.paymentMode == 'partial'
                                            ? 'Cash ₹${bill.cashAmount.toStringAsFixed(2)} / GPay ₹${bill.onlineAmount.toStringAsFixed(2)}'
                                            : bill.paymentMode == 'online'
                                                ? 'GPay/Online'
                                                : 'Cash',
                                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                if (_showCollectionBalance) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Collection: ',
                                          style: TextStyle(color: cs.onSurface, fontSize: 12)),
                                      Text('₹${bill.collectionAmount.toStringAsFixed(2)}',
                                          style: TextStyle(color: cs.onSurface, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Balance: ',
                                          style: TextStyle(color: cs.onSurface, fontSize: 12)),
                                      Text('₹${bill.balanceAmount.toStringAsFixed(2)}',
                                          style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ])),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
                      ),
                      Center(
                          child: Text(
                              'Medicines once sold are non-returnable.\n Thank you for your understanding.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}