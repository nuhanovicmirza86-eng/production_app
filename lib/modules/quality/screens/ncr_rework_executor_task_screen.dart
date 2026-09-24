import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../models/ncr_rework_executor_task.dart';
import '../services/quality_callable_service.dart';
import '../screens/ncr_rework_execution_evidence_screen.dart';
import '../widgets/ncr_execution_dialogs.dart';

/// M1-I12-D — scoped ekran za dodijeljenog izvršioca dorade.
class NcrReworkExecutorTaskScreen extends StatefulWidget {
  const NcrReworkExecutorTaskScreen({
    super.key,
    required this.companyData,
    required this.ncrId,
    this.initialTask,
  });

  final Map<String, dynamic> companyData;
  final String ncrId;
  final NcrReworkExecutorTask? initialTask;

  @override
  State<NcrReworkExecutorTaskScreen> createState() =>
      _NcrReworkExecutorTaskScreenState();
}

class _NcrReworkExecutorTaskScreenState extends State<NcrReworkExecutorTaskScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  NcrReworkExecutorTask? _task;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _svc.getNcrReworkExecutorTask(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      final taskMap = res['task'];
      if (taskMap is! Map) {
        throw StateError('Zadatak dorade nije dostupan.');
      }
      if (!mounted) return;
      setState(() {
        _task = NcrReworkExecutorTask.fromMap(
          Map<String, dynamic>.from(taskMap),
        );
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

  String _formatDue(String? dueAt) {
    final raw = (dueAt ?? '').trim();
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y. $h:$min';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmRework() async {
    final task = _task;
    if (task == null || !task.canConfirm) return;

    final draft = await openNcrReworkExecutionEvidence(
      context,
      taskBs: (task.taskDescription ?? '').trim(),
    );
    if (draft == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _svc.confirmNcrReworkExecution(
        companyId: _cid,
        ncrId: widget.ncrId,
        reworkedQty: draft.reworkedQty,
        separatedQty: draft.separatedQty,
        toRecheckQty: draft.toRecheckQty,
        workDescription: draft.workDescription,
        machineCorrectionDone: draft.machineCorrectionDone,
        correctionDescription: draft.correctionDescription,
        separatedDescription: draft.separatedDescription,
        note: draft.note,
        executedAt: draft.executedAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Završetak dorade je potvrđen')),
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
    final role = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    if (!ProductionAccessHelper.canBeNcrReworkExecutorRole(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moj zadatak dorade')),
        body: const Center(
          child: Text('Nemaš pristup zadacima dorade.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final task = _task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moj zadatak dorade'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : task == null
                  ? const Center(child: Text('Zadatak nije dostupan.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.displayNcrCode,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if ((task.priorityLabel ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Chip(
                                      label: Text(task.priorityLabel!.trim()),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Poslovni kontekst',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _infoRow('Proizvod', task.displayProduct),
                                  _infoRow(
                                    'Nalog',
                                    (task.productionOrderCode ?? '').trim().isNotEmpty
                                        ? task.productionOrderCode!.trim()
                                        : '—',
                                  ),
                                  _infoRow('Mašina', task.displayMachine),
                                  _infoRow(
                                    'Koliko komada',
                                    task.quantityHint != null
                                        ? '${task.quantityHint}'
                                        : '—',
                                  ),
                                  _infoRow('Rok', _formatDue(task.dueAt)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Šta treba doraditi',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    (task.taskDescription ?? '').trim().isNotEmpty
                                        ? task.taskDescription!.trim()
                                        : 'Nije unesen opis zadatka — obrati se vođi smjene ili kvaliteti.',
                                  ),
                                  if ((task.note ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Napomena',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(task.note!.trim()),
                                  ],
                                  if ((task.containment ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sadržaj / obuhvat',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(task.containment!.trim()),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (task.canConfirm) ...[
                            Text(
                              'Klik na dugme otvara formu za evidenciju izvršenja dorade.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _saving ? null : _confirmRework,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.task_alt_outlined),
                              label: const Text('Potvrdi završetak dorade'),
                            ),
                          ] else
                            Text(
                              'Zadatak je već obrađen ili nije u fazi izvršenja.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
    );
  }
}
