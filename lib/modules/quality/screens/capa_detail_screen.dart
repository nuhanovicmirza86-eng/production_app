import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/capa_methodology_constants.dart';
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

  final Map<String, TextEditingController> _eightD = {};
  final Map<String, TextEditingController> _ishikawa = {};

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
    for (final k in CapaEightDKeys.all) {
      _eightD[k] = TextEditingController();
    }
    for (final k in CapaIshikawaKeys.all) {
      _ishikawa[k] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _rootCause.dispose();
    _actionText.dispose();
    _verification.dispose();
    _responsible.dispose();
    for (final c in _eightD.values) {
      c.dispose();
    }
    for (final c in _ishikawa.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyEightD(dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    for (final k in CapaEightDKeys.all) {
      _eightD[k]!.text = (m[k] ?? '').toString();
    }
  }

  void _applyIshikawa(dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    for (final k in CapaIshikawaKeys.all) {
      final list = m[k];
      if (list is List) {
        _ishikawa[k]!.text = list
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .join('\n');
      } else {
        _ishikawa[k]!.text = '';
      }
    }
  }

  Map<String, dynamic> _eightDPayload() {
    return {for (final k in CapaEightDKeys.all) k: _eightD[k]!.text};
  }

  Map<String, dynamic> _ishikawaPayload() {
    return {
      for (final k in CapaIshikawaKeys.all)
        k: _ishikawa[k]!
            .text
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
    };
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
      _applyEightD(m['eightD']);
      _applyIshikawa(m['ishikawa']);
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
        eightD: _eightDPayload(),
        ishikawa: _ishikawaPayload(),
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
                  const SizedBox(height: 16),
                  ExpansionTile(
                    initiallyExpanded: false,
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '8D disciplina',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        QmsIatfInfoIcon(
                          title: '8D',
                          message: QmsIatfStrings.capaEightD,
                          size: 20,
                        ),
                      ],
                    ),
                    children: [
                      for (final k in CapaEightDKeys.all) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                CapaEightDKeys.labelHr(k),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _eightD[k],
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  ExpansionTile(
                    initiallyExpanded: false,
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Ishikawa (riblja kost)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        QmsIatfInfoIcon(
                          title: 'Ishikawa',
                          message: QmsIatfStrings.capaIshikawa,
                          size: 20,
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'Jedan potencijalni uzrok po retku u svakoj kategoriji.',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: [
                      for (final k in CapaIshikawaKeys.all) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                CapaIshikawaKeys.labelHr(k),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _ishikawa[k],
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Uzrok 1\nUzrok 2',
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  QmsIatfSectionTitle(
                    label: 'Uzrok (root cause)',
                    iatfTitle: 'Root cause',
                    iatfMessage: QmsIatfStrings.termRootCause,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _rootCause,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
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
                  QmsIatfSectionTitle(
                    label: 'Verifikacija',
                    iatfTitle: 'Verifikacija CAPA',
                    iatfMessage: QmsIatfStrings.termVerification,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _verification,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
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
