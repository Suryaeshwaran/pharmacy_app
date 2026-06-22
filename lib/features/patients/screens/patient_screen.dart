// lib/features/patients/screens/patient_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

/// Forces all typed input to uppercase as the user types.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});
  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _db = DatabaseProvider.instance.db;

  // ── Search controllers ────────────────────────────────────────────────────
  final _pidSearchCtrl = TextEditingController();
  final _nameSearchCtrl = TextEditingController();
  final _phoneSearchCtrl = TextEditingController();

  List<PatientMasterData> _searchResults = [];
  PatientMasterData? _selectedPatient;
  bool _searching = false;

  // ── Add / Edit form ───────────────────────────────────────────────────────
  bool _showForm = false;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _pidCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ph1Ctrl = TextEditingController();
  final _ph2Ctrl = TextEditingController();
  String? _pidError;
  bool _saving = false;

  @override
  void dispose() {
    _pidSearchCtrl.dispose();
    _nameSearchCtrl.dispose();
    _phoneSearchCtrl.dispose();
    _pidCtrl.dispose();
    _nameCtrl.dispose();
    _ph1Ctrl.dispose();
    _ph2Ctrl.dispose();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<void> _runSearch() async {
    final pid = _pidSearchCtrl.text.trim();
    final name = _nameSearchCtrl.text.trim();
    final phone = _phoneSearchCtrl.text.trim();

    if (pid.isEmpty && name.isEmpty && phone.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);

    final futures = <Future<List<PatientMasterData>>>[];
    if (pid.isNotEmpty) futures.add(_db.searchPatientsByPid(pid));
    if (name.isNotEmpty) futures.add(_db.searchPatientsByName(name));
    if (phone.isNotEmpty) futures.add(_db.searchPatientsByPhone(phone));

    final results = await Future.wait(futures);
    final merged = <String, PatientMasterData>{};
    for (final list in results) {
      for (final p in list) {
        merged[p.pid] = p;
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = merged.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _pidSearchCtrl.clear();
    _nameSearchCtrl.clear();
    _phoneSearchCtrl.clear();
    setState(() {
      _searchResults = [];
      _selectedPatient = null;
    });
  }

  // ── Select patient ─────────────────────────────────────────────────────────

  void _selectPatient(PatientMasterData p) {
    setState(() {
      _selectedPatient = p;
      _showForm = false;
      _isEditing = false;
    });
  }

  // ── Add New ────────────────────────────────────────────────────────────────

  void _openAddForm() {
    _pidCtrl.clear();
    _nameCtrl.clear();
    _ph1Ctrl.clear();
    _ph2Ctrl.clear();
    setState(() {
      _showForm = true;
      _isEditing = false;
      _selectedPatient = null;
      _pidError = null;
    });
  }

  // ── Edit ───────────────────────────────────────────────────────────────────

  void _openEditForm(PatientMasterData p) {
    _pidCtrl.text = p.pid;
    _nameCtrl.text = p.name;
    _ph1Ctrl.text = p.ph1 ?? '';
    _ph2Ctrl.text = p.ph2 ?? '';
    setState(() {
      _showForm = true;
      _isEditing = true;
      _pidError = null;
    });
  }

  // ── Save (insert or update) ────────────────────────────────────────────────

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _pidError = null; });

    final pid = _pidCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final ph1 = _ph1Ctrl.text.trim().isEmpty ? null : _ph1Ctrl.text.trim();
    final ph2 = _ph2Ctrl.text.trim().isEmpty ? null : _ph2Ctrl.text.trim();

    try {
      if (_isEditing) {
        final oldPid = _selectedPatient!.pid;
        final pidChanged = oldPid != pid;

        if (pidChanged) {
          // Make sure the new PID isn't already used by a different patient.
          final existing = await _db.getPatientByPid(pid);
          if (existing != null && existing.id != _selectedPatient!.id) {
            setState(() { _pidError = 'Patient ID "$pid" already exists.'; _saving = false; });
            return;
          }
        }

        await _db.updatePatient(PatientMasterCompanion(
          id: Value(_selectedPatient!.id),
          pid: Value(pid),
          name: Value(name),
          ph1: Value(ph1),
          ph2: Value(ph2),
        ));

        if (pidChanged) {
          // Keep today's visit queue in sync if this patient is currently queued.
          final wasQueued = await _db.isInVisitQueue(oldPid);
          if (wasQueued) {
            await _db.removeFromVisitQueueByPid(oldPid);
            await _db.addToVisitQueue(VisitQueueCompanion(
              pid: Value(pid),
              patientName: Value(name),
              patientPhone: Value(ph1),
            ));
          }
        }

        // Refresh selected patient
        final updated = await _db.getPatientByPid(pid);
        setState(() {
          _selectedPatient = updated;
          _showForm = false;
        });
      } else {
        // Duplicate PID check
        final existing = await _db.getPatientByPid(pid);
        if (existing != null) {
          setState(() { _pidError = 'Patient ID "$pid" already exists.'; _saving = false; });
          return;
        }
        await _db.insertPatient(PatientMasterCompanion(
          pid: Value(pid),
          name: Value(name),
          ph1: Value(ph1),
          ph2: Value(ph2),
        ));
        // New patients are automatically queued for today's visit.
        final created = await _db.getPatientByPid(pid);
        if (created != null) {
          await _addToVisitQueue(created);
        }
        setState(() => _showForm = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete patient ─────────────────────────────────────────────────────────

  Future<void> _deletePatient(PatientMasterData p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Delete "${p.name}" (${p.pid})? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deletePatient(p.id);
    setState(() {
      _selectedPatient = null;
      _showForm = false;
      _searchResults.removeWhere((r) => r.id == p.id);
    });
  }

  // ── Visit Queue ────────────────────────────────────────────────────────────

  Future<void> _addToVisitQueue(PatientMasterData p) async {
    final already = await _db.isInVisitQueue(p.pid);
    if (already) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${p.name} is already in today\'s queue.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }
    await _db.addToVisitQueue(VisitQueueCompanion(
      pid: Value(p.pid),
      patientName: Value(p.name),
      patientPhone: Value(p.ph1),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.name} added to today\'s queue.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Patients',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT PANEL ──────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildSearchCard(cs),
                  const SizedBox(height: 12),
                  Expanded(child: _buildLeftContent(cs)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // ── RIGHT PANEL — Visit Queue ────────────────────────────────────
            Expanded(
              flex: 2,
              child: _buildVisitQueuePanel(cs),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Card ────────────────────────────────────────────────────────────

  Widget _buildSearchCard(ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: cs.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SEARCH PATIENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddForm,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('New Patient'),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pidSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Patient ID',
                      labelStyle: TextStyle(color: cs.onSurface),
                      prefixIcon: Icon(Icons.badge_outlined, size: 18, color: cs.primary),
                      isDense: true,
                    ),
                    onChanged: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameSearchCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [_UpperCaseTextFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: cs.onSurface),
                      prefixIcon: Icon(Icons.person_outline, size: 18, color: cs.primary),
                      isDense: true,
                    ),
                    onChanged: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      labelStyle: TextStyle(color: cs.onSurface),
                      prefixIcon: Icon(Icons.phone_outlined, size: 18, color: cs.primary),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearSearch,
                  icon: Icon(Icons.clear, color: cs.onSurface),
                  tooltip: 'Clear',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Left content: results list OR patient detail OR form ───────────────────

  Widget _buildLeftContent(ColorScheme cs) {
    if (_showForm) return _buildPatientForm(cs);
    if (_selectedPatient != null) return _buildPatientDetail(cs, _selectedPatient!);

    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pidSearchCtrl.text.isEmpty &&
        _nameSearchCtrl.text.isEmpty &&
        _phoneSearchCtrl.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 56, color: cs.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Search by ID, Name or Phone',
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No patients found.', style: TextStyle(color: cs.onSurface)),
      );
    }

    return _buildResultsList(cs);
  }

  // ── Search results list ────────────────────────────────────────────────────

  Widget _buildResultsList(ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
        itemBuilder: (_, i) {
          final p = _searchResults[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              p.name,
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            subtitle: Text(
              'ID: ${p.pid}${p.ph1 != null ? '  •  ${p.ph1}' : ''}',
              style: TextStyle(fontSize: 12, color: cs.onSurface),
            ),
            trailing: Icon(Icons.chevron_right, color: cs.primary),
            onTap: () => _selectPatient(p),
          );
        },
      ),
    );
  }

  // ── Patient detail card ────────────────────────────────────────────────────

  Widget _buildPatientDetail(ColorScheme cs, PatientMasterData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back to results
        TextButton.icon(
          onPressed: () => setState(() => _selectedPatient = null),
          icon: Icon(Icons.arrow_back, size: 16, color: cs.primary),
          label: Text('Back to results', style: TextStyle(color: cs.primary)),
        ),
        const SizedBox(height: 4),
        Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'ID: ${p.pid}',
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),
                _detailRow(cs, Icons.phone_outlined, 'Phone 1', p.ph1 ?? '—'),
                const SizedBox(height: 8),
                _detailRow(cs, Icons.phone_outlined, 'Phone 2', p.ph2 ?? '—'),
                const SizedBox(height: 24),
                // Action buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _addToVisitQueue(p),
                      icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: const Text('Visiting Today'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditForm(p),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deletePatient(p),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(ColorScheme cs, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 13, color: cs.onSurface)),
      ],
    );
  }

  // ── Add / Edit form ────────────────────────────────────────────────────────

  Widget _buildPatientForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() { _showForm = false; _isEditing = false; }),
          icon: Icon(Icons.arrow_back, size: 16, color: cs.primary),
          label: Text('Cancel', style: TextStyle(color: cs.primary)),
        ),
        const SizedBox(height: 4),
        Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'EDIT PATIENT' : 'NEW PATIENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pidCtrl,
                    readOnly: false, // PID is now editable, including on edit
                    decoration: InputDecoration(
                      labelText: 'Patient ID *',
                      labelStyle: TextStyle(color: cs.onSurface),
                      errorText: _pidError,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Patient ID is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [_UpperCaseTextFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      labelStyle: TextStyle(color: cs.onSurface),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ph1Ctrl,
                    decoration: InputDecoration(
                      labelText: 'Phone 1',
                      labelStyle: TextStyle(color: cs.onSurface),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ph2Ctrl,
                    decoration: InputDecoration(
                      labelText: 'Phone 2',
                      labelStyle: TextStyle(color: cs.onSurface),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _savePatient,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEditing ? 'Update' : 'Save'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => setState(() { _showForm = false; _isEditing = false; }),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Right panel: Visit Queue ───────────────────────────────────────────────

  Widget _buildVisitQueuePanel(ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.today_outlined, color: cs.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'VISITING TODAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: StreamBuilder<List<VisitQueueData>>(
              stream: _db.watchVisitQueue(),
              builder: (context, snap) {
                final queue = snap.data ?? [];
                if (queue.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 48, color: cs.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        Text(
                          'No patients queued yet',
                          style: TextStyle(color: cs.onSurface, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: queue.length,
                  itemBuilder: (_, i) {
                    final entry = queue[i];
                    final isEven = i % 2 == 0;
                    return Container(
                      color: isEven
                          ? cs.primary.withValues(alpha: 0.05)
                          : Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // Index badge
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.patientName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${entry.pid}'
                                    '${entry.patientPhone != null ? '  •  ${entry.patientPhone}' : ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _confirmRemoveFromQueue(entry),
                              icon: Icon(Icons.check_circle_outline,
                                  color: Colors.green.shade700, size: 20),
                              tooltip: 'Mark Visited & Remove',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveFromQueue(VisitQueueData entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Visited'),
        content: Text('Remove "${entry.patientName}" from today\'s queue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark Visited')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.removeFromVisitQueue(entry.id);
    }
  }
}