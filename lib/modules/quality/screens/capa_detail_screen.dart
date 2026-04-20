import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';

/// Detalj CAPA zapisa (action_plans · sourceType non_conformance).
class CapaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String actionPlanId;

  const CapaDetailScreen({
    super.key,
    required this.companyData,
    required this.actionPlanId,
  });

  @override
  State<CapaDetailScreen> createState() => _CapaDetailScreenState();
}

class _CapaDetailScreenState extends State<CapaDetailScreen> {
  final _svc = QualityCallableService();
  final _title = TextEditingController();
  final _rootCause = TextEditingController();
  final _actionText = TextEditingController();
  final _verification = TextEditingController();
  final _responsible = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _plan;

  String _status = 'open';
  DateTime? _dueDate;
  bool _saving = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  static const _statuses = [
    'open',
    'in_progress',
    'waiting_verification',
    'closed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _rootCause.dispose();
    _actionText.dispose();
    _verification.dispose();
    _responsible.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _svc.getQmsCapaActionPlanMap(
        companyId: _cid,
        actionPlanId: widget.actionPlanId,
      );
      if (!mounted) return;
      _title.text = (m['title'] ?? '').toString();
      _rootCause.text = (m['rootCause'] ?? '').toString();
      _actionText.text = (m['actionText'] ?? '').toString();
      _verification.text = (m['verificationNotes'] ?? '').toString();
      _responsible.text = (m['responsibleUserId'] ?? '').toString();
      final st = (m['status'] ?? 'open').toString().toLowerCase();
      _status = _statuses.contains(st) ? st : 'open';
      final due = m['dueDate']?.toString();
      if (due != null && due.isNotEmpty) {
        _dueDate = DateTime.tryParse(due);
      } else {
        _dueDate = null;
      }
      setState(() {
        _plan = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null && mounted) {
      setState(() => _dueDate = d);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? dueIso;
      if (_dueDate != null) {
        final x = _dueDate!;
        dueIso = DateTime(x.year, x.month, x.day).toUtc().toIso8601String();
      }
      await _svc.updateQmsCapaActionPlan(
        companyId: _cid,
        actionPlanId: widget.actionPlanId,
        title: _title.text.trim(),
        status: _status,
        rootCause: _rootCause.text,
        actionText: _actionText.text,
        verificationNotes: _verification.text,
        responsibleUserId: _responsible.text.trim(),
        dueDateIso: dueIso,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CAPA je spremljena.')),
      );
      await _load();
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
      appBar: AppBar(
        title: const Text('CAPA'),
        actions: [
          QmsIatfInfoIcon(
            title: 'CAPA',
            message: QmsIatfStrings.detailCapa,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_plan != null)
                    Text(
                      'NCR ref: ${_plan!['sourceRefId'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Naslov *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('capa_st_$_status'),
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rootCause,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Uzrok (root cause)',
                      border: const OutlineInputBorder(),
                      suffixIcon: QmsIatfInfoIcon(
                        title: 'Root cause',
                        message: QmsIatfStrings.termRootCause,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _actionText,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Akcije / plan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _verification,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Verifikacija',
                      border: const OutlineInputBorder(),
                      suffixIcon: QmsIatfInfoIcon(
                        title: 'Verifikacija CAPA',
                        message: QmsIatfStrings.termVerification,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _responsible,
                    decoration: const InputDecoration(
                      labelText: 'Odgovoran (user id)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      _dueDate == null
                          ? 'Rok (opcionalno)'
                          : 'Rok: ${_dueDate!.toIso8601String().split('T').first}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDue,
                  ),
                  if (_dueDate != null)
                    TextButton(
                      onPressed: () => setState(() => _dueDate = null),
                      child: const Text('Ukloni rok'),
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
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Spremanje…' : 'Spremi CAPA'),
                  ),
                ],
              ),
            ),
    );
  }
}
