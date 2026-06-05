// lib/features/backup/backup_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$backupName');
      await dbFile.copy(backupFile.path);

      // share_plus v10 API
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'Pharmacy App Backup — $now',
      );

      setState(() => _statusMessage = '✅ Backup created: $backupName');
    } catch (e) {
      setState(() => _statusMessage = '❌ Backup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Restore Backup', style: TextStyle(color: cs.onSurface)),
        content: Text(
          '⚠️ Restoring will REPLACE all current data with the backup.\n\nThis cannot be undone. Are you sure?',
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
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _loading = true; _statusMessage = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _statusMessage = 'No file selected.');
        return;
      }

      final sourceFile = File(result.files.single.path!);
      final dbPath = await _getDbPath();
      await sourceFile.copy(dbPath);

      setState(() => _statusMessage = '✅ Restore successful. Please restart the app.');
    } catch (e) {
      setState(() => _statusMessage = '❌ Restore failed: $e');
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
                    Text(
                      'Restore', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Import a previously exported backup file. This will replace all current data.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _restore,
                        icon: const Icon(Icons.restore, color: Colors.red),
                        label: const Text('Import Backup', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
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
}