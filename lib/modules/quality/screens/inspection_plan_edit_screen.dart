import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';

/// Plan inspekcije: productId + controlPlanId + tip + refs karakteristika (npr. 0:0,0:1).
/// Prazan unos refs = sve karakteristike kontrolnog plana pri izvršenju (backend).
class InspectionPlanEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String? inspectionPlanId;

  const InspectionPlanEditScreen({
    super.key,
    required this.companyData,
    this.inspectionPlanId,
  });

  @override
  State<InspectionPlanEditScreen> createState() => _InspectionPlanEditScreenState();
}

class _InspectionPlanEditScreenState extends State<InspectionPlanEditScreen> {
  final _svc = QualityCallableService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _productId;
  late final TextEditingController _controlPlanId;
  late final TextEditingController _plantKey;
  late final TextEditingController _refs;

  String _inspectionType = 'IN_PROCESS';
  String _status = 'draft';
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _defaultPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _productId = TextEditingController();
    _controlPlanId = TextEditingController();
    _plantKey = TextEditingController(text: _defaultPlantKey);
    _refs = TextEditingController();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.inspectionPlanId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final m = await _svc.getQmsInspectionPlanMap(companyId: _cid, inspectionPlanId: id);
      if (!mounted) return;
      _productId.text = (m['productId'] ?? '').toString();
      _controlPlanId.text = (m['controlPlanId'] ?? '').toString();
      _plantKey.text = (m['plantKey'] ?? _defaultPlantKey).toString();
      _status = (m['status'] ?? 'draft').toString();
      if (_status != 'draft' && _status != 'approved' && _status != 'obsolete') {
        _status = 'draft';
      }
      final it = (m['inspectionType'] ?? 'IN_PROCESS').toString().toUpperCase();
      if (it == 'INCOMING' || it == 'IN_PROCESS' || it == 'FINAL') {
        _inspectionType = it;
      }
      final rawRefs = m['characteristicRefs'];
      if (rawRefs is List && rawRefs.isNotEmpty) {
        _refs.text = rawRefs.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(', ');
      }
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppErrorMapper.toMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _productId.dispose();
    _controlPlanId.dispose();
    _plantKey.dispose();
    _refs.dispose();
    super.dispose();
  }

  List<String> _parseRefs(String s) {
    return s
        .split(RegExp(r'[,\s]+'))
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.upsertInspectionPlan(
        companyId: _cid,
        plantKey: _plantKey.text.trim().isEmpty ? null : _plantKey.text.trim(),
        inspectionPlanId: widget.inspectionPlanId,
        productId: _productId.text.trim(),
        controlPlanId: _controlPlanId.text.trim(),
        inspectionType: _inspectionType,
        characteristicRefs: _parseRefs(_refs.text),
        status: _status,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final isNew = widget.inspectionPlanId == null || widget.inspectionPlanId!.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Novi plan inspekcije' : 'Uredi plan inspekcije'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _productId,
                      decoration: const InputDecoration(
                        labelText: 'ID proizvoda (Firestore) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obavezno' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _controlPlanId,
                      decoration: const InputDecoration(
                        labelText: 'ID kontrolnog plana *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obavezno' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _plantKey,
                      decoration: const InputDecoration(
                        labelText: 'Plant key (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ip_type_$_inspectionType'),
                      initialValue: _inspectionType,
                      decoration: const InputDecoration(
                        labelText: 'Tip inspekcije',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'INCOMING', child: Text('INCOMING (ulazna)')),
                        DropdownMenuItem(value: 'IN_PROCESS', child: Text('IN_PROCESS (u procesu)')),
                        DropdownMenuItem(value: 'FINAL', child: Text('FINAL (završna)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _inspectionType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ip_status_$_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('draft')),
                        DropdownMenuItem(value: 'approved', child: Text('approved')),
                        DropdownMenuItem(value: 'obsolete', child: Text('obsolete')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Karakteristike (refs u formatu operacija:indeks, npr. 0:0). Prazno = sve iz kontrolnog plana.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _refs,
                      decoration: const InputDecoration(
                        labelText: 'characteristicRefs (opcionalno)',
                        hintText: '0:0, 0:1',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Spremanje…' : 'Spremi'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
