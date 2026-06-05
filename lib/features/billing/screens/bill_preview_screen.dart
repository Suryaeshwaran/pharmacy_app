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

class BillPreviewScreen extends StatelessWidget {
  final Bill bill;
  final List<BillItem> items;

  const BillPreviewScreen({super.key, required this.bill, required this.items});

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.billedAt);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(children: [
              pw.Text('PHARMACY',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('INVOICE',
                  style: const pw.TextStyle(fontSize: 10)),
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
            pw.Text('Customer: ${bill.customerName}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (bill.customerPhone != null)
              pw.Text('Phone: ${bill.customerPhone}'),
            pw.SizedBox(height: 8),
          ],
          pw.Row(children: [
            pw.Expanded(
                flex: 4,
                child: pw.Text('Medicine',
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
                    pw.Text(
                        'TOTAL: ${bill.totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                  ]),
            ],
          ),
          pw.Divider(),
          pw.Center(
              child: pw.Text('Thank You!',
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
  // Desktop : save to Downloads → open in system PDF viewer → delete after 30s
  // Mobile  : standard print dialog (no file written to disk)

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

  // ── WhatsApp share (text only, all platforms) ─────────────────────────────

  String _buildWhatsAppMessage() {
    final lines = items
        .map((i) =>
            '  ${i.medicineName} x${i.quantity} = ${i.totalPrice.toStringAsFixed(2)}')
        .join('\n');

    return ' *PHARMACY INVOICE*\n'
        '━━━━━━━━━━━━━━━━━━\n'
        'Bill No: ${bill.billNumber}\n'
        'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.billedAt)}\n'
        '${bill.customerName != null ? 'Customer: ${bill.customerName}\n' : ''}'
        '${bill.customerPhone != null ? 'Phone: ${bill.customerPhone}\n' : ''}'
        '━━━━━━━━━━━━━━━━━━\n'
        '*Items:*\n$lines\n'
        '━━━━━━━━━━━━━━━━━━\n'
        'Subtotal: ${bill.subtotal.toStringAsFixed(2)}'
        '${bill.discount > 0 ? '\nDiscount: -${bill.discount.toStringAsFixed(2)}' : ''}\n'
        '*Total: ${bill.totalAmount.toStringAsFixed(2)}*\n'
        '━━━━━━━━━━━━━━━━━━\n'
        'Thank You!';
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    final msg = _buildWhatsAppMessage();
    final phone = bill.customerPhone ?? '';
    final encoded = Uri.encodeComponent(msg);

    final webUrl = phone.isNotEmpty
        ? Uri.parse('https://wa.me/91$phone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    if (Platform.isAndroid || Platform.isIOS) {
      // Try WhatsApp app deep link first
      final appUrl = phone.isNotEmpty
          ? Uri.parse('whatsapp://send?phone=91$phone&text=$encoded')
          : Uri.parse('whatsapp://send?text=$encoded');

      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Desktop + mobile fallback: open wa.me in browser (WhatsApp Web)
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
            tooltip: isDesktop ? 'Save & Open PDF' : 'Print / Save PDF',
            onPressed: () => _printPdf(context),
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
                    color: Colors.black.withOpacity(0.06),
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
                        Text('PHARMACY',
                            style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        Text('INVOICE',
                            style: textTheme.bodySmall
                                ?.copyWith(color: cs.onSurface.withOpacity(0.7))),
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
                                ?.copyWith(color: cs.onSurface.withOpacity(0.7))),
                      ])),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1),
                      ),
                      if (bill.customerName != null) ...[
                        Text('Customer: ${bill.customerName}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: 14)),
                        if (bill.customerPhone != null) ...[
                          const SizedBox(height: 2),
                          Text('Phone: ${bill.customerPhone}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurface.withOpacity(0.7))),
                        ],
                        const SizedBox(height: 16),
                      ],
                      Row(children: [
                        Expanded(
                            flex: 4,
                            child: Text('Medicine',
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
                                const SizedBox(height: 8),
                                Text(
                                    'TOTAL: ₹${bill.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface)),
                              ])),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1),
                      ),
                      Center(
                          child: Text('Thank You!',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.5),
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