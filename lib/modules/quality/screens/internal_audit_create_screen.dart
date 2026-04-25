import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/internal_audit_callable_service.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Forma za [createInternalAudit].
class InternalAuditCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const InternalAuditCreateScreen({super.key, required this.companyData});

  @override
  State<InternalAuditCreateScreen> createState() =>
      _InternalAuditCreateScreenState();
}

class _InternalAuditCreateScreenState extends State<InternalAuditCreateScreen> {
  final _svc = InternalAuditCallableService();
  final _plant = TextEditingController();
  final _title = TextEditingController();
  final _auditor = TextEditingController();
  final _department = TextEditingController();
  final _notes = TextEditingController();
  String _auditType = 'process';
  late String _auditDate;
  bool _saving = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _auditDate = _ymd(DateTime.now());
  }

  @override
  void dispose() {
    _plant.dispose();
    _title.dispose();
    _auditor.dispose();
    _department.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 1, 12, 31);
    final cur = DateTime.tryParse(_auditDate) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: first,
      lastDate: last,
    );
    if (d != null && mounted) {
      setState(() => _auditDate = _ymd(d));
    }
  }

  Future<void> _submit() async {
    final cid = _cid;
    if (cid.isEmpty) return;
    final title = _title.text.trim();
    final auditor = _auditor.text.trim();
    final dept = _department.text.trim();
    if (title.isEmpty || auditor.isEmpty || dept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naslov, auditor i odjel su obavezni.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await _svc.createInternalAudit(
        companyId: cid,
        plantKey: _plant.text.trim().isEmpty ? null : _plant.text.trim(),
        auditType: _auditType,
        title: title,
        auditorName: auditor,
        auditDate: _auditDate,
        department: dept,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop<Object?>(context, r);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Novi interni audit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tip audita',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _auditType,
                items: const [
                  DropdownMenuItem(value: 'process', child: Text('Proces')),
                  DropdownMenuItem(value: 'product', child: Text('Proizvod')),
                  DropdownMenuItem(value: 'system', child: Text('Sustav (QMS)')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _auditType = v);
                      },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plant,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Pogon (plantKey, opcionalno)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Naslov',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _auditor,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Ime auditora',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _department,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Odjel / područje',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datum audita'),
            subtitle: Text(_auditDate),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: _saving ? null : _pickDate,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Napomene (opcionalno)',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Spremi audit'),
          ),
        ],
      ),
    );
  }
}
