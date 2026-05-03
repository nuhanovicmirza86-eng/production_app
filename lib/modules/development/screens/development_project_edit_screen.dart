// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';

/// Uređivanje osnovnih polja — Callable `updateDevelopmentProject`.
class DevelopmentProjectEditScreen extends StatefulWidget {
  const DevelopmentProjectEditScreen({
    super.key,
    required this.companyData,
    required this.project,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;

  @override
  State<DevelopmentProjectEditScreen> createState() =>
      _DevelopmentProjectEditScreenState();
}

class _DevelopmentProjectEditScreenState
    extends State<DevelopmentProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DevelopmentProjectService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _customerCtrl;
  late final TextEditingController _productNameCtrl;
  late final TextEditingController _productCodeCtrl;
  late final TextEditingController _stageCtrl;
  late final TextEditingController _progressCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _budgetPlanCtrl;
  late final TextEditingController _budgetActCtrl;
  late final TextEditingController _revCtrl;
  late final TextEditingController _marginCtrl;

  late String _projectType;
  late String _priority;
  late String _status;
  late String _riskLevel;
  late String _strategic;
  late String _currentGate;

  DateTime? _plannedStart;
  DateTime? _plannedEnd;
  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _pmRestrictedBudget {
    final r = ProductionAccessHelper.normalizeRole(
      widget.companyData['role']?.toString(),
    );
    if (ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r)) {
      return false;
    }
    return r == ProductionAccessHelper.roleProjectManager;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl = TextEditingController(text: p.projectName);
    _customerCtrl = TextEditingController(text: p.customerName ?? '');
    _productNameCtrl = TextEditingController(text: p.productName ?? '');
    _productCodeCtrl = TextEditingController(text: p.productCode ?? '');
    _stageCtrl = TextEditingController(
      text: p.currentStage.isEmpty
          ? DevelopmentStageKeys.ideaRequest
          : p.currentStage,
    );
    _progressCtrl = TextEditingController(text: '${p.progressPercent}');
    _currencyCtrl = TextEditingController(text: p.currency);
    _budgetPlanCtrl = TextEditingController(
      text: p.budgetPlanned?.toString() ?? '',
    );
    _budgetActCtrl = TextEditingController(
      text: p.budgetActual?.toString() ?? '',
    );
    _revCtrl = TextEditingController(
      text: p.estimatedRevenue?.toString() ?? '',
    );
    _marginCtrl = TextEditingController(
      text: p.estimatedMargin?.toString() ?? '',
    );

    _projectType = DevelopmentProjectTypes.all.contains(p.projectType)
        ? p.projectType
        : DevelopmentProjectTypes.customerNewProduct;
    _priority = DevelopmentPriorities.medium;
    for (final x in [
      DevelopmentPriorities.low,
      DevelopmentPriorities.medium,
      DevelopmentPriorities.high,
      DevelopmentPriorities.critical,
    ]) {
      if (x == p.priority) _priority = p.priority;
    }

    _status = DevelopmentProjectStatuses.draft;
    for (final s in DevelopmentProjectStatuses.all) {
      if (s == p.status) _status = p.status;
    }

    _riskLevel = DevelopmentRiskLevels.medium;
    for (final r in [
      DevelopmentRiskLevels.low,
      DevelopmentRiskLevels.medium,
      DevelopmentRiskLevels.high,
      DevelopmentRiskLevels.critical,
    ]) {
      if (r == p.riskLevel) _riskLevel = p.riskLevel;
    }

    _strategic = DevelopmentRiskLevels.medium;
    for (final r in [
      DevelopmentRiskLevels.low,
      DevelopmentRiskLevels.medium,
      DevelopmentRiskLevels.high,
      DevelopmentRiskLevels.critical,
    ]) {
      if (r == p.strategicImportance) _strategic = p.strategicImportance;
    }

    final g = p.currentGate.trim().toUpperCase();
    _currentGate = DevelopmentGateCodes.ordered.contains(g)
        ? g
        : DevelopmentGateCodes.g0;

    _plannedStart = p.plannedStartDate;
    _plannedEnd = p.plannedEndDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customerCtrl.dispose();
    _productNameCtrl.dispose();
    _productCodeCtrl.dispose();
    _stageCtrl.dispose();
    _progressCtrl.dispose();
    _currencyCtrl.dispose();
    _budgetPlanCtrl.dispose();
    _budgetActCtrl.dispose();
    _revCtrl.dispose();
    _marginCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{
      'projectName': _nameCtrl.text.trim(),
      'projectType': _projectType,
      'priority': _priority,
      'customerName': _customerCtrl.text.trim(),
      'productName': _productNameCtrl.text.trim(),
      'productCode': _productCodeCtrl.text.trim(),
      'status': _status,
      'riskLevel': _riskLevel,
      'strategicImportance': _strategic,
      'currentGate': _currentGate,
      'currentStage': _stageCtrl.text.trim(),
      'currency': _currencyCtrl.text.trim().isEmpty
          ? 'EUR'
          : _currencyCtrl.text.trim(),
    };

    final pRaw = int.tryParse(_progressCtrl.text.trim());
    if (pRaw != null) {
      patch['progressPercent'] = pRaw.clamp(0, 100);
    }

    void putNum(String key, String t) {
      final s = t.trim();
      if (s.isEmpty) {
        patch[key] = null;
      } else {
        final v = double.tryParse(s.replaceAll(',', '.'));
        if (v != null) patch[key] = v;
      }
    }

    putNum('budgetPlanned', _budgetPlanCtrl.text);
    putNum('budgetActual', _budgetActCtrl.text);
    putNum('estimatedRevenue', _revCtrl.text);
    putNum('estimatedMargin', _marginCtrl.text);

    if (_pmRestrictedBudget) {
      patch.remove('budgetPlanned');
      patch.remove('estimatedRevenue');
      patch.remove('estimatedMargin');
    }

    if (_plannedStart != null) {
      patch['plannedStartDate'] = _plannedStart!.millisecondsSinceEpoch;
    } else {
      patch['plannedStartDate'] = null;
    }
    if (_plannedEnd != null) {
      patch['plannedEndDate'] = _plannedEnd!.millisecondsSinceEpoch;
    } else {
      patch['plannedEndDate'] = null;
    }

    return patch;
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _plannedStart : _plannedEnd;
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        if (start) {
          _plannedStart = d;
        } else {
          _plannedEnd = d;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje podatak o organizaciji ili pogonu.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.updateProjectViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: widget.project.id,
        patch: _buildPatch(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spremanje nije uspjelo: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uredi projekat'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.project.projectCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv projekta *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Obavezno polje.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _projectType,
              decoration: const InputDecoration(
                labelText: 'Tip projekta *',
                border: OutlineInputBorder(),
              ),
              items: DevelopmentProjectTypes.all
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(DevelopmentDisplay.projectTypeLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _projectType = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioritet',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Nizak')),
                DropdownMenuItem(value: 'medium', child: Text('Srednji')),
                DropdownMenuItem(value: 'high', child: Text('Visok')),
                DropdownMenuItem(value: 'critical', child: Text('Kritičan')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: DevelopmentProjectStatuses.all
                  .where((s) => s != DevelopmentProjectStatuses.closed)
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(DevelopmentDisplay.projectStatusLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _riskLevel,
              decoration: const InputDecoration(
                labelText: 'Rizik',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Nizak')),
                DropdownMenuItem(value: 'medium', child: Text('Srednji')),
                DropdownMenuItem(value: 'high', child: Text('Visok')),
                DropdownMenuItem(value: 'critical', child: Text('Kritičan')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _riskLevel = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _strategic,
              decoration: const InputDecoration(
                labelText: 'Strateška važnost',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Niska')),
                DropdownMenuItem(value: 'medium', child: Text('Srednja')),
                DropdownMenuItem(value: 'high', child: Text('Visoka')),
                DropdownMenuItem(value: 'critical', child: Text('Kritična')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _strategic = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentGate,
              decoration: const InputDecoration(
                labelText: 'Gate',
                border: OutlineInputBorder(),
              ),
              items: DevelopmentGateCodes.ordered
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(g),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _currentGate = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stageCtrl,
              decoration: const InputDecoration(
                labelText: 'Faza (slug)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Obavezno polje.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _progressCtrl,
              decoration: const InputDecoration(
                labelText: 'Napredak (0–100)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerCtrl,
              decoration: const InputDecoration(
                labelText: 'Kupac',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv proizvoda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Šifra proizvoda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Valuta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!_pmRestrictedBudget) ...[
              TextFormField(
                controller: _budgetPlanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Budžet plan',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _budgetActCtrl,
              decoration: const InputDecoration(
                labelText: 'Budžet stvarno',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (!_pmRestrictedBudget) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _revCtrl,
                decoration: const InputDecoration(
                  labelText: 'Procjena prihoda',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _marginCtrl,
                decoration: const InputDecoration(
                  labelText: 'Procjena marže',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Plan budžeta i prihod/maržu uređuje samo admin ( Callable ) — voditelj može unositi stvarni budžet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(start: true),
                    child: Text(
                      _plannedStart == null
                          ? 'Planirani početak'
                          : '${_plannedStart!.toLocal()}'.split(' ').first,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(start: false),
                    child: Text(
                      _plannedEnd == null
                          ? 'Planirani kraj'
                          : '${_plannedEnd!.toLocal()}'.split(' ').first,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _plannedStart = null),
                  child: const Text('Očisti početak'),
                ),
                TextButton(
                  onPressed: () => setState(() => _plannedEnd = null),
                  child: const Text('Očisti kraj'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            ),
          ],
        ),
      ),
    );
  }
}
