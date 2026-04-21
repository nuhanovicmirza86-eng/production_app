import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../models/shift_context.dart';
import '../services/shift_context_service.dart';

/// Administracija `shift_contexts` za pogon — neto operativno vrijeme po danu i oznaci smjene.
///
/// Vidljivo samo ulogama s [ProductionAccessHelper.canManage] za OOE (npr. supervizor, menadžer).
class OoeShiftContextScreen extends StatelessWidget {
  const OoeShiftContextScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _companyId => (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  @override
  Widget build(BuildContext context) {
    final svc = ShiftContextService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontekst smjene'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: CompanyPlantLabelText(
                companyId: _companyId,
                plantKey: _plantKey,
                prefix: '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(
                context,
                companyId: _companyId,
                plantKey: _plantKey,
                existing: null,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Novi unos'),
            )
          : null,
      body: StreamBuilder<List<ShiftContext>>(
        stream: svc.watchRecentForPlant(
          companyId: _companyId,
          plantKey: _plantKey,
          limit: 90,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ne mogu učitati podatke. Provjeri vezu ili prava pristupa.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Još nema definisanog konteksta smjene',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _canManage
                          ? 'Dodaj unos za današnji ili naredni radni dan kako bi '
                              'availability u OOE koristio tačno neto vrijeme smjene.'
                          : 'Menadžer ili supervizor može dodati planirana vremena.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                child: ListTile(
                  title: Text(
                    '${_formatCalendarDate(c.shiftDateKey)} · ${c.shiftCode}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Operativno: ${_formatMinutes(c.operatingTimeSeconds)}',
                        ),
                        if (c.plannedBreakSeconds > 0)
                          Text(
                            'Pauze: ${_formatMinutes(c.plannedBreakSeconds)}',
                          ),
                        if (c.active)
                          _chip(context, 'Aktivan', true, positive: true)
                        else
                          _chip(context, 'Neaktivan', true, positive: false),
                        if (!c.isWorkingShift)
                          _chip(context, 'Nije radna smjena', true, positive: false),
                      ],
                    ),
                  ),
                  trailing: _canManage
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Uredi',
                          onPressed: () => _openEditor(
                            context,
                            companyId: _companyId,
                            plantKey: _plantKey,
                            existing: c,
                          ),
                        )
                      : null,
                  onTap: _canManage
                      ? () => _openEditor(
                            context,
                            companyId: _companyId,
                            plantKey: _plantKey,
                            existing: c,
                          )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Widget _chip(
    BuildContext context,
    String label,
    bool on, {
    required bool positive,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: on
            ? (positive
                ? cs.primaryContainer.withValues(alpha: 0.7)
                : cs.errorContainer.withValues(alpha: 0.45))
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  static String _formatCalendarDate(String shiftDateKey) {
    final p = shiftDateKey.split('-');
    if (p.length != 3) return shiftDateKey;
    final y = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    final d = int.tryParse(p[2]) ?? 0;
    if (y == 0) return shiftDateKey;
    return '$d.$m.$y.';
  }

  static String _formatMinutes(int seconds) {
    if (seconds <= 0) return '—';
    final m = (seconds / 60).round();
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '$h h';
    return '$h h $r min';
  }

  static Future<void> _openEditor(
    BuildContext context, {
    required String companyId,
    required String plantKey,
    required ShiftContext? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ShiftContextEditorSheet(
        companyId: companyId,
        plantKey: plantKey,
        existing: existing,
      ),
    );
  }
}

class _ShiftContextEditorSheet extends StatefulWidget {
  const _ShiftContextEditorSheet({
    required this.companyId,
    required this.plantKey,
    required this.existing,
  });

  final String companyId;
  final String plantKey;
  final ShiftContext? existing;

  @override
  State<_ShiftContextEditorSheet> createState() =>
      _ShiftContextEditorSheetState();
}

class _ShiftContextEditorSheetState extends State<_ShiftContextEditorSheet> {
  final _svc = ShiftContextService();
  late DateTime _date;
  late TextEditingController _codeCtrl;
  late TextEditingController _opMinCtrl;
  late TextEditingController _breakMinCtrl;
  late TextEditingController _notesCtrl;
  late bool _active;
  late bool _isWorkingShift;
  /// Za agregaciju u sažetku smjene — ako oba postoje, koriste se kao prozor događaja.
  DateTime? _plannedStartAt;
  DateTime? _plannedEndAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.shiftDateLocal ?? DateTime.now();
    _codeCtrl = TextEditingController(text: e?.shiftCode ?? 'DAY');
    _opMinCtrl = TextEditingController(
      text: e != null
          ? ((e.operatingTimeSeconds / 60).round()).toString()
          : '480',
    );
    _breakMinCtrl = TextEditingController(
      text: e != null && e.plannedBreakSeconds > 0
          ? ((e.plannedBreakSeconds / 60).round()).toString()
          : '0',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _active = e?.active ?? true;
    _isWorkingShift = e?.isWorkingShift ?? true;
    _plannedStartAt = e?.plannedStartAt;
    _plannedEndAt = e?.plannedEndAt;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _opMinCtrl.dispose();
    _breakMinCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      if (_plannedStartAt != null) {
        final t = _plannedStartAt!.toLocal();
        _plannedStartAt = DateTime(
          _date.year,
          _date.month,
          _date.day,
          t.hour,
          t.minute,
        );
      }
      if (_plannedEndAt != null) {
        final t = _plannedEndAt!.toLocal();
        _plannedEndAt = DateTime(
          _date.year,
          _date.month,
          _date.day,
          t.hour,
          t.minute,
        );
      }
    });
  }

  String? _formatHm(DateTime? d) {
    if (d == null) return null;
    final x = d.toLocal();
    return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPlannedStart() async {
    final initial = _plannedStartAt != null
        ? TimeOfDay.fromDateTime(_plannedStartAt!)
        : const TimeOfDay(hour: 6, minute: 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t == null || !mounted) return;
    setState(() {
      _plannedStartAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        t.hour,
        t.minute,
      );
    });
  }

  Future<void> _pickPlannedEnd() async {
    final initial = _plannedEndAt != null
        ? TimeOfDay.fromDateTime(_plannedEndAt!)
        : const TimeOfDay(hour: 22, minute: 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t == null || !mounted) return;
    setState(() {
      _plannedEndAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        t.hour,
        t.minute,
      );
    });
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _toast('Upiši oznaku smjene (npr. DAY).');
      return;
    }
    final opMin = int.tryParse(_opMinCtrl.text.trim());
    final brMin = int.tryParse(_breakMinCtrl.text.trim()) ?? 0;
    if (opMin == null || opMin <= 0) {
      _toast('Operativno vrijeme mora biti pozitivan broj minuta.');
      return;
    }
    if (brMin < 0) {
      _toast('Planirane pauze ne mogu biti negativne.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;

    setState(() => _saving = true);
    try {
      await _svc.upsertContext(
        companyId: widget.companyId,
        plantKey: widget.plantKey,
        shiftDateLocal: _date,
        shiftCode: code,
        operatingTimeSeconds: opMin * 60,
        plannedBreakSeconds: brMin * 60,
        plannedStartAt: _plannedStartAt,
        plannedEndAt: _plannedEndAt,
        isWorkingShift: _isWorkingShift,
        active: _active,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdBy: uid,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kontekst smjene sačuvan.')),
        );
      }
    } catch (e) {
      if (mounted) {
        _toast('Čuvanje nije uspjelo. Provjeri unos i prava pristupa.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni unos?'),
        content: const Text(
          'Ovaj zapis konteksta smjene bit će trajno obrisan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _svc.deleteContext(
        companyId: widget.companyId,
        plantKey: widget.plantKey,
        shiftDateLocal: e.shiftDateLocal,
        shiftCode: e.shiftCode,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unos obrisan.')),
        );
      }
    } catch (_) {
      if (mounted) {
        _toast('Brisanje nije uspjelo. Provjeri prava pristupa.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Uredi kontekst smjene' : 'Novi kontekst smjene',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Datum'),
              subtitle: Text(OoeShiftContextScreen._formatCalendarDate(
                ShiftContext.shiftDateKeyFromLocal(_date),
              )),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving ? null : _pickDate,
            ),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Oznaka smjene',
                hintText: 'Npr. DAY, NIGHT, A',
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _opMinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Operativno vrijeme (minute)',
                helperText: 'Neto vrijeme koje ulazi u availability',
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _breakMinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Planirane pauze (minute)',
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Planirani početak (opc.)'),
              subtitle: Text(
                _formatHm(_plannedStartAt) ??
                    'Nije postavljen — potrebna su oba vremena za prilagođeni prozor',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_plannedStartAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Ukloni',
                      onPressed:
                          _saving ? null : () => setState(() => _plannedStartAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'Odaberi vrijeme',
                    onPressed: _saving ? null : _pickPlannedStart,
                  ),
                ],
              ),
              onTap: _saving ? null : _pickPlannedStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Planirani kraj (opc.)'),
              subtitle: Text(
                _formatHm(_plannedEndAt) ??
                    'Nije postavljen — potrebna su oba vremena za prilagođeni prozor',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_plannedEndAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Ukloni',
                      onPressed:
                          _saving ? null : () => setState(() => _plannedEndAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'Odaberi vrijeme',
                    onPressed: _saving ? null : _pickPlannedEnd,
                  ),
                ],
              ),
              onTap: _saving ? null : _pickPlannedEnd,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktivan'),
              subtitle: const Text('Neaktivan zapis se ne koristi u izračunu'),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Radna smjena'),
              subtitle: const Text('Isključi za praznik ili zatvoren pogon'),
              value: _isWorkingShift,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _isWorkingShift = v),
            ),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Napomena (opcionalno)'),
              enabled: !_saving,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Obriši'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
