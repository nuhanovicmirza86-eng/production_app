import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';

/// Jedna operacija / jedna karakteristika (MVP); proširenje kasnije.
class ControlPlanEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String? controlPlanId;

  const ControlPlanEditScreen({
    super.key,
    required this.companyData,
    this.controlPlanId,
  });

  @override
  State<ControlPlanEditScreen> createState() => _ControlPlanEditScreenState();
}

class _ControlPlanEditScreenState extends State<ControlPlanEditScreen> {
  final _svc = QualityCallableService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _productId;
  late final TextEditingController _plantKey;
  late final TextEditingController _operationName;
  late final TextEditingController _charName;
  late final TextEditingController _nominal;
  late final TextEditingController _tolMin;
  late final TextEditingController _tolMax;
  late final TextEditingController _unit;

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
    _title = TextEditingController();
    _productId = TextEditingController();
    _plantKey = TextEditingController(text: _defaultPlantKey);
    _operationName = TextEditingController(text: 'Operacija 1');
    _charName = TextEditingController(text: 'Karakteristika 1');
    _nominal = TextEditingController(text: '0');
    _tolMin = TextEditingController();
    _tolMax = TextEditingController();
    _unit = TextEditingController(text: 'mm');
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.controlPlanId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final m = await _svc.getQmsControlPlanMap(companyId: _cid, controlPlanId: id);
      if (!mounted) return;
      _title.text = (m['title'] ?? '').toString();
      _productId.text = (m['productId'] ?? '').toString();
      _plantKey.text = (m['plantKey'] ?? _defaultPlantKey).toString();
      _status = (m['status'] ?? 'draft').toString();
      if (_status != 'draft' && _status != 'approved' && _status != 'obsolete') {
        _status = 'draft';
      }
      final ops = m['operations'] as List? ?? [];
      if (ops.isNotEmpty) {
        final op0 = ops.first;
        if (op0 is Map) {
          _operationName.text = (op0['operationName'] ?? 'Operacija 1').toString();
          final chars = op0['characteristics'] as List? ?? [];
          if (chars.isNotEmpty && chars.first is Map) {
            final c0 = Map<String, dynamic>.from(chars.first as Map);
            _charName.text = (c0['name'] ?? '').toString();
            _nominal.text = (c0['nominal'] ?? '0').toString();
            _tolMin.text = '${c0['toleranceMin'] ?? ''}'.trim();
            _tolMax.text = '${c0['toleranceMax'] ?? ''}'.trim();
            _unit.text = (c0['unit'] ?? 'mm').toString();
          }
        }
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
    _title.dispose();
    _productId.dispose();
    _plantKey.dispose();
    _operationName.dispose();
    _charName.dispose();
    _nominal.dispose();
    _tolMin.dispose();
    _tolMax.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tolMin = double.tryParse(_tolMin.text.trim());
      final tolMax = double.tryParse(_tolMax.text.trim());
      final nominal = double.tryParse(_nominal.text.trim());
      final operations = [
        {
          'operationName': _operationName.text.trim(),
          'characteristics': [
            {
              'name': _charName.text.trim(),
              'nominal': nominal,
              'toleranceMin': tolMin,
              'toleranceMax': tolMax,
              'unit': _unit.text.trim(),
            },
          ],
        },
      ];
      await _svc.upsertControlPlan(
        companyId: _cid,
        plantKey: _plantKey.text.trim().isEmpty ? null : _plantKey.text.trim(),
        controlPlanId: widget.controlPlanId,
        title: _title.text.trim(),
        productId: _productId.text.trim(),
        status: _status,
        operations: operations,
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
    final isNew = widget.controlPlanId == null || widget.controlPlanId!.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Novi kontrolni plan' : 'Uredi kontrolni plan'),
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
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Naslov *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obavezno' : null,
                    ),
                    const SizedBox(height: 12),
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
                      controller: _plantKey,
                      decoration: const InputDecoration(
                        labelText: 'Plant key (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('cp_status_$_status'),
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
                      'Operacija i karakteristika (MVP: jedna stavka)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _operationName,
                      decoration: const InputDecoration(
                        labelText: 'Naziv operacije',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _charName,
                      decoration: const InputDecoration(
                        labelText: 'Naziv karakteristike',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nominal,
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tolMin,
                            decoration: const InputDecoration(
                              labelText: 'Tolerancija min',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tolMax,
                            decoration: const InputDecoration(
                              labelText: 'Tolerancija max',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Jedinica',
                        border: OutlineInputBorder(),
                      ),
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
