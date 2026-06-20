// lib/features/maintenance/maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../core/database/database_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          'Maintenance',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface,
          indicatorColor: cs.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Backup & Restore'),
            Tab(text: 'Data Cleanup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BackupRestoreTab(),
          _DataCleanupTab(),
        ],
      ),
    );
  }
}

// ─── TAB 1: Backup & Restore ──────────────────────────────────────────────────

class _BackupRestoreTab extends StatefulWidget {
  const _BackupRestoreTab();
  @override
  State<_BackupRestoreTab> createState() => _BackupRestoreTabState();
}

class _BackupRestoreTabState extends State<_BackupRestoreTab> {
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
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
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

    return Center(
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
                  color: Colors.black.withValues(alpha:0.06),
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export the database file to save all your medicines, bills, and customer data.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha:0.8),
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _backup,
                      icon: const Icon(Icons.backup),
                      label: const Text('Export Backup',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Divider(
                        color: cs.outlineVariant.withValues(alpha:0.6), height: 1),
                  ),

                  // ── Restore Section ──
                  Text(
                    'Restore',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To restore a backup, follow the steps below while the application is closed.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha:0.8),
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String>(
                    future: _getDbDirectory(),
                    builder: (context, snapshot) {
                      final dbDir = snapshot.data ??
                          r'C:\Users\<username>\AppData\Roaming\PharmacyApp\pharmacy_app\';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha:0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.shade300, width: 0.6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700, size: 18),
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
                            _restoreStep(
                                '1', 'Close the application completely.'),
                            _restoreStep(
                                '2', 'Navigate to the database folder:'),
                            Container(
                              margin: const EdgeInsets.only(
                                  left: 24, top: 4, bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
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
                            _restoreStep('3',
                                'Replace the existing .sqlite file with your backup file.'),
                            _restoreStep('4',
                                'Rename the backup file to match the original filename.'),
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
                            ? Colors.green.withValues(alpha:0.08)
                            : Colors.red.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _statusMessage!.startsWith('✅')
                              ? Colors.green
                              : Colors.red,
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _statusMessage!.startsWith('✅')
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: cs.primary),
                    ),
                  ],
                ],
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
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ─── TAB 2: Data Cleanup ──────────────────────────────────────────────────────

class _DataCleanupTab extends StatefulWidget {
  const _DataCleanupTab();
  @override
  State<_DataCleanupTab> createState() => _DataCleanupTabState();
}

class _DataCleanupTabState extends State<_DataCleanupTab> {
  bool _loading = false;
  bool _deleting = false;
  String? _statusMessage;
  List<Map<String, dynamic>> _months = [];
  final Set<String> _selected = {}; // keys like "2026-01"

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _loadMonths() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final db = DatabaseProvider.instance.db;
      final rows = await db.getCleanupMonths();
      setState(() {
        _months = rows;
        _selected.clear();
      });
    } catch (e) {
      setState(() => _statusMessage = '❌ Failed to load data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_selected.isEmpty) return;

    final selectedMonths = _months
        .where((m) => _selected.contains(_monthKey(m['year'], m['month'])))
        .toList();

    final monthNames = selectedMonths
        .map((m) => DateFormat('MMMM yyyy')
            .format(DateTime(m['year'] as int, m['month'] as int)))
        .join(', ');

    final totalBills = selectedMonths.fold<int>(
        0, (sum, m) => sum + (m['count'] as int));

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade600, size: 22),
              const SizedBox(width: 8),
              const Text('Confirm Delete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to permanently delete $totalBills bill(s) from:',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                monthNames,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.06),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.shade200, width: 0.8),
                ),
                child: const Text(
                  'This cannot be undone. Stock will not be restored.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _statusMessage = null;
    });

    try {
      final db = DatabaseProvider.instance.db;
      int totalDeleted = 0;
      for (final m in selectedMonths) {
        final count =
            await db.deleteMonthData(m['year'] as int, m['month'] as int);
        totalDeleted += count;
      }
      setState(() => _statusMessage =
          '✅ Deleted $totalDeleted bill(s) from ${selectedMonths.length} month(s). Database compacted.');
      await _loadMonths();
    } catch (e) {
      setState(() => _statusMessage = '❌ Delete failed: $e');
    } finally {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Cleanup',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select bills older than 3 months to permanently delete.\n'
                      'Recent 3 months are protected and cannot be deleted.',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha:0.8),
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Month list ──
              if (_loading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ))
              else if (_months.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
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
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Nothing to clean up',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No bills older than 3 months found.',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha:0.7)),
                      ),
                    ],
                  ),
                )
              else ...[
                // Select-all row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selected.length == _months.length,
                        tristate: true,
                        onChanged: (_) {
                          setState(() {
                            if (_selected.length == _months.length) {
                              _selected.clear();
                            } else {
                              _selected.addAll(_months.map((m) =>
                                  _monthKey(m['year'], m['month'])));
                            }
                          });
                        },
                        activeColor: cs.primary,
                      ),
                      Text(
                        'Select all  (${_months.length} month${_months.length == 1 ? '' : 's'})',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadMonths,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),

                // Month cards
                ...(_months.map((m) {
                  final year = m['year'] as int;
                  final month = m['month'] as int;
                  final count = m['count'] as int;
                  final key = _monthKey(year, month);
                  final isChecked = _selected.contains(key);
                  final label = DateFormat('MMMM yyyy')
                      .format(DateTime(year, month));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: isChecked
                          ? Border.all(color: cs.primary, width: 1.5)
                          : Border.all(
                              color: Colors.transparent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CheckboxListTile(
                      value: isChecked,
                      onChanged: (_) {
                        setState(() {
                          if (isChecked) {
                            _selected.remove(key);
                          } else {
                            _selected.add(key);
                          }
                        });
                      },
                      activeColor: cs.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      title: Text(
                        label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: cs.onSurface),
                      ),
                      subtitle: Text(
                        '$count bill${count == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface.withValues(alpha:0.7)),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: cs.onPrimaryContainer),
                        ),
                      ),
                    ),
                  );
                })),

                const SizedBox(height: 16),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_selected.isEmpty || _deleting) ? null : _confirmAndDelete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      _deleting
                          ? 'Deleting...'
                          : _selected.isEmpty
                              ? 'Select months to delete'
                              : 'Delete ${_selected.length} month${_selected.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _selected.isEmpty ? null : Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],

              // ── Status message ──
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _statusMessage!.startsWith('✅')
                        ? Colors.green.withValues(alpha:0.08)
                        : Colors.red.withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusMessage!.startsWith('✅')
                          ? Colors.green
                          : Colors.red,
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _statusMessage!.startsWith('✅')
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
