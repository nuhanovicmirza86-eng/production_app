import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../models/capacity_calendar.dart';
import '../services/capacity_calendar_callable_service.dart';

/// Unos ili izmjena jednog kalendarskog dana u `capacity_calendars` (Callable).
class CapacityCalendarEditScreen extends StatefulWidget {
  const CapacityCalendarEditScreen({
    super.key,
    required this.companyData,
    this.existing,
    this.initialDate,
  });

  final Map<String, dynamic> companyData;
  final CapacityCalendar? existing;
  final DateTime? initialDate;

  @override
  State<CapacityCalendarEditScreen> createState() =>
      _CapacityCalendarEditScreenState();
}

class _CapacityCalendarEditScreenState extends State<CapacityCalendarEditScreen> {
  final _callable = CapacityCalendarCallableService();
  final _scopeIdCtrl = TextEditingController();
  late final TextEditingController _calendarSec;
  late final TextEditingController _operatingSec;
  late final TextEditingController _plannedSec;
  late final TextEditingController _shiftCount;
  late final TextEditingController _notes;
  late DateTime _day;
  String _scopeType = 'plant';
  bool _isHoliday = false;
  /// Kad je `true`, backend sam odredi vikend iz datuma (`isWeekend` se ne šalje).
  bool _autoWeekend = true;
  bool _manualWeekend = false;
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canSave => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  static String _scopeLockedLabel(CapacityCalendar c) {
    switch (c.scopeType) {
      case 'line':
        return 'Linija · ${c.scopeId}';
      case 'machine':
        return 'Stroj · ${c.scopeId}';
      default:
        return 'Cijeli pogon';
    }
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _scopeType = ex.scopeType;
      _scopeIdCtrl.text = ex.scopeId;
      _day = DateTime(ex.date.year, ex.date.month, ex.date.day);
      _calendarSec = TextEditingController(
        text: ex.calendarTimeSeconds.toString(),
      );
      _operatingSec = TextEditingController(
        text: ex.scheduledOperatingTimeSeconds.toString(),
      );
      _plannedSec = TextEditingController(
        text: ex.plannedProductionTimeSeconds.toString(),
      );
      _shiftCount = TextEditingController(text: ex.shiftCount.toString());
      _notes = TextEditingController(text: ex.notes ?? '');
      _isHoliday = ex.isHoliday;
      _autoWeekend = false;
      _manualWeekend = ex.isWeekend;
    } else {
      final base = widget.initialDate ?? DateTime.now();
      _day = DateTime(base.year, base.month, base.day);
      _calendarSec = TextEditingController(text: '86400');
      _operatingSec = TextEditingController(text: '57600');
      _plannedSec = TextEditingController(text: '46080');
      _shiftCount = TextEditingController(text: '1');
      _notes = TextEditingController();
      _isHoliday = false;
      _autoWeekend = true;
      _manualWeekend = false;
    }
  }

  @override
  void dispose() {
    _scopeIdCtrl.dispose();
    _calendarSec.dispose();
    _operatingSec.dispose();
    _plannedSec.dispose();
    _shiftCount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final first = DateTime(DateTime.now().year - 1);
    final last = DateTime(DateTime.now().year + 2);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (!_canSave || _saving || !mounted) return;
    final c = int.tryParse(_calendarSec.text.trim());
    final o = int.tryParse(_operatingSec.text.trim());
    final p = int.tryParse(_plannedSec.text.trim());
    if (c == null || o == null || p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesi cijele brojeve (sekunde) za sva tri vremena.')),
      );
      return;
    }
    int? sc;
    final scRaw = _shiftCount.text.trim();
    if (scRaw.isNotEmpty) {
      sc = int.tryParse(scRaw);
      if (sc == null || sc < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broj smjena mora biti nenegativan cijeli broj.')),
        );
        return;
      }
    }

    final scopeType = widget.existing?.scopeType ?? _scopeType;
    final scopeId =
        widget.existing != null ? widget.existing!.scopeId : (_scopeType == 'plant' ? '' : _scopeIdCtrl.text.trim());
    if (scopeType != 'plant' && scopeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesi ID linije ili stroja za taj opseg.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _callable.upsertCapacityCalendar(
        companyId: _companyId,
        plantKey: _plantKey,
        calendarDateLocal: _day,
        calendarTimeSeconds: c,
        scheduledOperatingTimeSeconds: o,
        plannedProductionTimeSeconds: p,
        scopeType: scopeType,
        scopeId: scopeId,
        shiftCount: sc,
        isHoliday: _isHoliday,
        isWeekend: _autoWeekend ? null : _manualWeekend,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalendar je spremljen.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _day;
    final title = widget.existing == null
        ? 'Novi zapis kapaciteta'
        : 'Uredi kapacitet';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_canSave)
            TextButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CompanyPlantLabelText(
            companyId: _companyId,
            plantKey: _plantKey,
            prefix: '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (!_canSave)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Nemaš pravo spremanja kalendara (potrebna je menadžerska uloga za OOE).',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ListTile(
            title: const Text('Datum'),
            subtitle: Text('${l.day}.${l.month}.${l.year}.'),
            trailing: const Icon(Icons.calendar_today),
            onTap: widget.existing != null ? null : _pickDay,
          ),
          if (widget.existing != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Za ovaj zapis datum se ne mijenja (novi dan = novi zapis s pregleda).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            ListTile(
              title: const Text('Opseg'),
              subtitle: Text(_scopeLockedLabel(widget.existing!)),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: _scopeType,
              decoration: const InputDecoration(
                labelText: 'Opseg',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'plant', child: Text('Cijeli pogon')),
                DropdownMenuItem(value: 'line', child: Text('Linija')),
                DropdownMenuItem(value: 'machine', child: Text('Stroj')),
              ],
              onChanged: !_canSave
                  ? null
                  : (v) => setState(() => _scopeType = v ?? 'plant'),
            ),
            if (_scopeType != 'plant') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _scopeIdCtrl,
                decoration: InputDecoration(
                  labelText: _scopeType == 'line' ? 'ID linije' : 'ID stroja',
                  border: const OutlineInputBorder(),
                ),
                readOnly: !_canSave,
              ),
            ],
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _calendarSec,
            decoration: const InputDecoration(
              labelText: 'Kalendarsko vrijeme (s)',
              helperText: 'npr. 86400 = 24 h',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: !_canSave,
          ),
          TextField(
            controller: _operatingSec,
            decoration: const InputDecoration(
              labelText: 'Operativno (zakazano) vrijeme (s)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: !_canSave,
          ),
          TextField(
            controller: _plannedSec,
            decoration: const InputDecoration(
              labelText: 'Planirana proizvodnja (s)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: !_canSave,
          ),
          TextField(
            controller: _shiftCount,
            decoration: const InputDecoration(
              labelText: 'Broj smjena (opcionalno)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: !_canSave,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Praznik / neradni dan (holiday)'),
            value: _isHoliday,
            onChanged:
                !_canSave ? null : (v) => setState(() => _isHoliday = v),
          ),
          SwitchListTile(
            title: const Text('Vikend: automatski prema datumu'),
            subtitle: const Text(
              'Isključi ako želiš ručno označiti je li dan vikend.',
            ),
            value: _autoWeekend,
            onChanged: !_canSave
                ? null
                : (v) => setState(() => _autoWeekend = v),
          ),
          if (!_autoWeekend)
            SwitchListTile(
              title: const Text('Vikend'),
              value: _manualWeekend,
              onChanged: !_canSave
                  ? null
                  : (v) => setState(() => _manualWeekend = v),
            ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Napomena (opcionalno)',
            ),
            maxLines: 3,
            readOnly: !_canSave,
          ),
        ],
      ),
    );
  }
}
