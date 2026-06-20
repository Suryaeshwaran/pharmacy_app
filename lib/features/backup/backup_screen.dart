// lib/features/backup/backup_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  String? _statusMessage;

  Future<String> _getDbPath() async {
    final appDir = await getApplicationSupportDirectory();
    final candidates = [
      '${appDir.path}/pharmacy_app.sqlite',
      '${appDir.path}/pharmacy_app.db',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    final files = Directory(appDir.path).listSync();
    for (final f in files) {
      if (f.path.contains('pharmacy_app')) return f.path;
    }
    return candidates[0];
  }

  Future<String> _getDbDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return appDir.path;
  }

  Future<void> _backup() async {
    setState(() { _loading = true; _statusMessage = null; });
    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        setState(() => _statusMessage = '⚠️ Database file not found at $dbPath');
        return;
      }

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = 'pharmacy_backup_$now.sqlite';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: backupName,
        allowedExtensions: ['sqlite'],
        type: FileType.custom,
      );

      if (savePath == null) {
        setState(() => _statusMessage = 'Backup cancelled.');
        return;
      }

      await dbFile.copy(savePath);
      setState(() => _statusMessage = '✅ Backup saved to $savePath');
    } catch (e) {
      setState(() => _statusMessage = '❌ Backup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
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
          'Backup & Restore',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
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
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Backup Section ──
                    Text(
                      'Backup',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Export the database file to save all your medicines, bills, and customer data.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _backup,
                        icon: const Icon(Icons.backup),
                        label: const Text('Export Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1),
                    ),

                    // ── Restore Section ──
                    Text(
                      'Restore',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To restore a backup, follow the steps below while the application is closed.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<String>(
                      future: _getDbDirectory(),
                      builder: (context, snapshot) {
                        final dbDir = snapshot.data ?? r'C:\Users\<username>\AppData\Roaming\PharmacyApp\pharmacy_app\';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300, width: 0.6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How to Restore',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _restoreStep('1', 'Close the application completely.'),
                              _restoreStep('2', 'Navigate to the database folder:'),
                              Container(
                                margin: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dbDir,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              _restoreStep('3', 'Replace the existing .sqlite file with your backup file.'),
                              _restoreStep('4', 'Rename the backup file to match the original filename.'),
                              _restoreStep('5', 'Reopen the application.'),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Status Message ──
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _statusMessage!.startsWith('✅')
                              ? Colors.green.withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _statusMessage!.startsWith('✅') ? Colors.green : Colors.red,
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _statusMessage!.startsWith('✅') ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _restoreStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}