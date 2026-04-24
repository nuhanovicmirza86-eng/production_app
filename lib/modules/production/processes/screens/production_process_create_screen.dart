import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import '../models/production_process_model.dart';
import '../services/production_process_service.dart';

class ProductionProcessCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String initialPlantKey;

  const ProductionProcessCreateScreen({
    super.key,
    required this.companyData,
    required this.initialPlantKey,
  });

  @override
  State<ProductionProcessCreateScreen> createState() =>
      _ProductionProcessCreateScreenState();
}

class _ProductionProcessCreateScreenState extends State<ProductionProcessCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductionProcessService _service = ProductionProcessService();
  final WorkCenterService _workCenterService = WorkCenterService();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _pfmeaRefCtrl = TextEditingController();
  final _cpRefCtrl = TextEditingController();
  final _wiRefCtrl = TextEditingController();

  late String _plantKey;
  List<({String plantKey, String label})> _plants = const [];

  String _processType = ProductionProcess.typeMachining;
  String _status = ProductionProcess.statusDraft;

  bool _iatf = true;
  bool _trace = true;
  bool _qc = false;
  bool _firstPiece = false;
  bool _params = false;
  bool _operatorQual = false;
  bool _wiReq = false;
  bool _pfmeaReq = false;
  bool _cpReq = false;

  final Set<String> _wcTypeKeys = {};
  final Set<String> _linkedWcIds = {};
  List<WorkCenter> _workCenters = const [];
  bool _wcLoading = false;

  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

  @override
  void initState() {
    super.initState();
    _plantKey = widget.initialPlantKey.trim();
    _loadPlants();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _pfmeaRefCtrl.dispose();
    _cpRefCtrl.dispose();
    _wiRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlants() async {
    if (_companyId.isEmpty) return;
    final list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() {
      _plants = list;
      if (_plantKey.isEmpty && list.isNotEmpty) {
        _plantKey = list.first.plantKey;
      } else if (list.any((p) => p.plantKey == _plantKey)) {
        // keep
      } else if (list.isNotEmpty) {
        _plantKey = list.first.plantKey;
      }
    });
    await _loadWorkCenters();
  }

  Future<void> _loadWorkCenters() async {
    final cid = _companyId;
    final pk = _plantKey;
    if (cid.isEmpty || pk.isEmpty) return;

    setState(() => _wcLoading = true);
    try {
      final list = await _workCenterService.listWorkCentersForPlant(
        companyId: cid,
        plantKey: pk,
        onlyActive: false,
      );
      if (!mounted) return;
      setState(() {
        _workCenters = list;
        _wcLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workCenters = const [];
        _wcLoading = false;
      });
    }
  }

  String? _required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label je obavezno';
    return null;
  }

  Future<void> _pickWorkCenters() async {
    final selected = Set<String>.from(_linkedWcIds);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Dozvoljeni radni centri'),
              content: SizedBox(
                width: double.maxFinite,
                child: _workCenters.isEmpty
                    ? const Text('Nema radnih centara na pogonu.')
                    : ListView(
                        shrinkWrap: true,
                        children: _workCenters.map((wc) {
                          return CheckboxListTile(
                            value: selected.contains(wc.id),
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selected.add(wc.id);
                                } else {
                                  selected.remove(wc.id);
                                }
                              });
                            },
                            title: Text('${wc.workCenterCode} — ${wc.name}'),
                            subtitle: Text(WorkCenter.labelForType(wc.type)),
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Primijeni'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true && mounted) {
      setState(() {
        _linkedWcIds
          ..clear()
          ..addAll(selected);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty || _plantKey.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje kontekst kompanije, pogona ili korisnika.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.createProcess(
        companyId: _companyId,
        plantKey: _plantKey,
        processCode: _codeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        processType: _processType,
        status: _status,
        iatfRelevant: _iatf,
        traceabilityRequired: _trace,
        qualityControlRequired: _qc,
        firstPieceApprovalRequired: _firstPiece,
        processParametersRequired: _params,
        operatorQualificationRequired: _operatorQual,
        workInstructionRequired: _wiReq,
        pfmeaRequired: _pfmeaReq,
        controlPlanRequired: _cpReq,
        linkedWorkCenterTypes: _wcTypeKeys.toList()..sort(),
        linkedWorkCenterIds: _linkedWcIds.toList()..sort(),
        pfmeaReference: _pfmeaRefCtrl.text,
        controlPlanReference: _cpRefCtrl.text,
        workInstructionReference: _wiRefCtrl.text,
        createdBy: _userId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proces je kreiran.')),
      );
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
        title: const Text('Novi proces'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Spremi'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_plants.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _plantKey.isEmpty ? null : _plantKey,
                decoration: const InputDecoration(
                  labelText: 'Pogon *',
                  border: OutlineInputBorder(),
                ),
                items: _plants
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.plantKey,
                        child: Text(p.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _plantKey = v;
                    _linkedWcIds.clear();
                  });
                  _loadWorkCenters();
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Šifra procesa *',
                border: OutlineInputBorder(),
                hintText: 'npr. PROC-CNC-001',
              ),
              validator: (v) => _required(v, 'Šifra procesa'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, 'Naziv'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _processType,
              decoration: const InputDecoration(
                labelText: 'Tip procesa *',
                border: OutlineInputBorder(),
              ),
              items: ProductionProcess.selectableTypes
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _processType = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status *',
                border: OutlineInputBorder(),
              ),
              items: ProductionProcess.selectableStatuses
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _status = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Opis',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const Text(
              'IATF i sljedljivost',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('IATF relevantan'),
              value: _iatf,
              onChanged: (v) => setState(() => _iatf = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obavezna sljedljivost'),
              value: _trace,
              onChanged: (v) => setState(() => _trace = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obavezan QC zapis'),
              value: _qc,
              onChanged: (v) => setState(() => _qc = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preporučena pravila (operativni guardovi kasnije)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prvi komad — odobrenje'),
              value: _firstPiece,
              onChanged: (v) => setState(() => _firstPiece = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obavezni procesni parametri'),
              value: _params,
              onChanged: (v) => setState(() => _params = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kvalifikacija operatera'),
              value: _operatorQual,
              onChanged: (v) => setState(() => _operatorQual = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Radna instrukcija obavezna'),
              value: _wiReq,
              onChanged: (v) => setState(() => _wiReq = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('PFMEA obavezan'),
              value: _pfmeaReq,
              onChanged: (v) => setState(() => _pfmeaReq = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Control Plan obavezan'),
              value: _cpReq,
              onChanged: (v) => setState(() => _cpReq = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tipovi radnih centara (opcionalno — ograničenje „gdje”)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ProductionProcess.selectableWorkCenterTypes.map((e) {
                final on = _wcTypeKeys.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: on,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _wcTypeKeys.add(e.key);
                      } else {
                        _wcTypeKeys.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _wcLoading
                        ? 'Učitavanje radnih centara…'
                        : 'Dozvoljeni radni centri: ${_linkedWcIds.length}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _wcLoading ? null : _pickWorkCenters,
                  child: const Text('Odaberi'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Poveznice na dokumente (kratka verzija)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pfmeaRefCtrl,
              decoration: const InputDecoration(
                labelText: 'PFMEA referenca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cpRefCtrl,
              decoration: const InputDecoration(
                labelText: 'Control Plan referenca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wiRefCtrl,
              decoration: const InputDecoration(
                labelText: 'Radna instrukcija referenca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Spremanje…' : 'Spremi proces'),
            ),
          ],
        ),
      ),
    );
  }
}
