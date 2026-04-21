import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_service.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_display_formatters.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';

class _CharBlock {
  _CharBlock()
    : name = TextEditingController(),
      nominal = TextEditingController(text: '0'),
      tolMin = TextEditingController(),
      tolMax = TextEditingController(),
      unit = TextEditingController(text: 'mm');

  final TextEditingController name;
  final TextEditingController nominal;
  final TextEditingController tolMin;
  final TextEditingController tolMax;
  final TextEditingController unit;

  void dispose() {
    name.dispose();
    nominal.dispose();
    tolMin.dispose();
    tolMax.dispose();
    unit.dispose();
  }
}

class _OperationBlock {
  _OperationBlock({bool withDefaultChar = true})
    : operationName = TextEditingController(text: 'Operacija'),
      characteristics =
          withDefaultChar ? <_CharBlock>[_CharBlock()] : <_CharBlock>[];

  final TextEditingController operationName;
  final List<_CharBlock> characteristics;

  void dispose() {
    operationName.dispose();
    for (final c in characteristics) {
      c.dispose();
    }
  }
}

/// Više operacija i više karakteristika po operaciji (indeksi 0:0, 0:1, …).
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
  final _productService = ProductService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _productId;
  late final TextEditingController _plantKey;

  final List<_OperationBlock> _operations = [_OperationBlock()];

  String _status = 'draft';
  String? _approvedAtIso;
  String? _approvedByUid;
  String? _obsoleteAtIso;
  String? _obsoleteByUid;
  String? _productDisplayLine;
  List<({String plantKey, String label})> _plants = [];
  bool _plantsLoading = false;
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
    _loadExisting();
  }

  void _clearOperations() {
    for (final o in _operations) {
      o.dispose();
    }
    _operations.clear();
  }

  Future<void> _loadPlants() async {
    setState(() => _plantsLoading = true);
    var list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _cid,
    );
    final current = _plantKey.text.trim();
    if (current.isNotEmpty && !list.any((p) => p.plantKey == current)) {
      final label = await CompanyPlantDisplayName.resolve(
        companyId: _cid,
        plantKey: current,
      );
      list = [...list, (plantKey: current, label: label)]
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
    }
    if (!mounted) return;
    setState(() {
      _plants = list;
      _plantsLoading = false;
    });
  }

  Future<void> _refreshProductLabel() async {
    final id = _productId.text.trim();
    if (id.isEmpty) {
      setState(() => _productDisplayLine = null);
      return;
    }
    try {
      final p = await _productService.getProductById(
        companyId: _cid,
        productId: id,
      );
      if (!mounted) return;
      if (p == null) {
        setState(() => _productDisplayLine = null);
        return;
      }
      setState(() => _productDisplayLine = QmsDisplayFormatters.productLine(p));
    } catch (_) {
      if (mounted) setState(() => _productDisplayLine = null);
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.controlPlanId;
    if (id == null || id.isEmpty) {
      _approvedAtIso = null;
      _approvedByUid = null;
      _obsoleteAtIso = null;
      _obsoleteByUid = null;
      setState(() => _loading = false);
      await _loadPlants();
      await _refreshProductLabel();
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
      _approvedAtIso = m['approvedAt']?.toString();
      _approvedByUid = m['approvedByUid']?.toString();
      _obsoleteAtIso = m['obsoleteAt']?.toString();
      _obsoleteByUid = m['obsoleteByUid']?.toString();

      _clearOperations();
      final ops = m['operations'] as List? ?? [];
      if (ops.isEmpty) {
        _operations.add(_OperationBlock());
      } else {
        for (final raw in ops) {
          if (raw is! Map) continue;
          final opMap = Map<String, dynamic>.from(raw);
          final ob = _OperationBlock(withDefaultChar: false);
          ob.operationName.text = (opMap['operationName'] ?? 'Operacija').toString();
          final chars = opMap['characteristics'] as List? ?? [];
          if (chars.isEmpty) {
            ob.characteristics.add(_CharBlock());
          } else {
            for (final cr in chars) {
              if (cr is! Map) continue;
              final cMap = Map<String, dynamic>.from(cr);
              final cb = _CharBlock();
              cb.name.text = (cMap['name'] ?? '').toString();
              cb.nominal.text = '${cMap['nominal'] ?? '0'}';
              cb.tolMin.text = '${cMap['toleranceMin'] ?? ''}'.trim();
              cb.tolMax.text = '${cMap['toleranceMax'] ?? ''}'.trim();
              cb.unit.text = (cMap['unit'] ?? 'mm').toString();
              ob.characteristics.add(cb);
            }
          }
          _operations.add(ob);
        }
      }
      await _refreshProductLabel();
      await _loadPlants();
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
    _clearOperations();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildOperationsPayload() {
    final out = <Map<String, dynamic>>[];
    for (final op in _operations) {
      final chars = <Map<String, dynamic>>[];
      for (final ch in op.characteristics) {
        final tolMin = double.tryParse(ch.tolMin.text.trim());
        final tolMax = double.tryParse(ch.tolMax.text.trim());
        final nominal = double.tryParse(ch.nominal.text.trim());
        chars.add({
          'name': ch.name.text.trim(),
          'nominal': nominal,
          'toleranceMin': tolMin,
          'toleranceMax': tolMax,
          'unit': ch.unit.text.trim(),
        });
      }
      out.add({
        'operationName': op.operationName.text.trim(),
        'characteristics': chars,
      });
    }
    return out;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi proizvod.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.upsertControlPlan(
        companyId: _cid,
        plantKey: _plantKey.text.trim().isEmpty ? null : _plantKey.text.trim(),
        controlPlanId: widget.controlPlanId,
        title: _title.text.trim(),
        productId: _productId.text.trim(),
        status: _status,
        operations: _buildOperationsPayload(),
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
        actions: [
          QmsIatfInfoIcon(
            title: 'Kontrolni plan',
            message:
                '${QmsIatfStrings.editControlPlan}\n\n${QmsIatfStrings.termApqp}',
          ),
        ],
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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                  Text(
                    'Proizvod *',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _productId.text.trim().isEmpty
                          ? 'Nije odabran'
                          : (_productDisplayLine ?? 'Učitavanje…'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _productId.text.trim().isEmpty
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final id = await showQmsProductPicker(
                          context: context,
                          companyId: _cid,
                        );
                        if (id != null && mounted) {
                          setState(() => _productId.text = id);
                          await _refreshProductLabel();
                        }
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 20),
                      label: Text(
                        _productId.text.trim().isEmpty
                            ? 'Odaberi proizvod'
                            : 'Promijeni proizvod',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey<String>(
                      'cp_plant_${_plantKey.text}_${_plants.length}',
                    ),
                    initialValue: _plantKey.text.trim().isEmpty
                        ? null
                        : _plantKey.text.trim(),
                    decoration: InputDecoration(
                      labelText: 'Pogon',
                      border: const OutlineInputBorder(),
                      helperText: _plantsLoading ? 'Učitavanje pogona…' : null,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('(bez pogona)'),
                      ),
                      ..._plants.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.plantKey,
                          child: Text(p.label),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _plantKey.text = (v ?? '').trim());
                    },
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
                      DropdownMenuItem(value: 'draft', child: Text('Nacrt')),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Odobreno'),
                      ),
                      DropdownMenuItem(
                        value: 'obsolete',
                        child: Text('Zastarjelo'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  if (!isNew &&
                      ((_approvedAtIso != null && _approvedAtIso!.trim().isNotEmpty) ||
                          (_approvedByUid != null && _approvedByUid!.trim().isNotEmpty) ||
                          (_obsoleteAtIso != null && _obsoleteAtIso!.trim().isNotEmpty) ||
                          (_obsoleteByUid != null && _obsoleteByUid!.trim().isNotEmpty))) ...[
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audit životnog ciklusa (ISO)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if ((_approvedAtIso != null &&
                                    _approvedAtIso!.trim().isNotEmpty) ||
                                (_approvedByUid != null &&
                                    _approvedByUid!.trim().isNotEmpty))
                              Text(
                                'Odobreno: ${_approvedAtIso ?? "—"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if ((_obsoleteAtIso != null &&
                                    _obsoleteAtIso!.trim().isNotEmpty) ||
                                (_obsoleteByUid != null &&
                                    _obsoleteByUid!.trim().isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Zastarjelo: ${_obsoleteAtIso ?? "—"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Operacije i karakteristike',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 4),
                            QmsIatfInfoIcon(
                              title: 'Operacije i karakteristike',
                              message: QmsIatfStrings.editControlPlan,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _operations.add(_OperationBlock()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Operacija'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._operations.asMap().entries.map((entry) {
                    final oi = entry.key;
                    final op = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Operacija ${oi + 1}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Spacer(),
                                if (_operations.length > 1)
                                  IconButton(
                                    tooltip: 'Ukloni operaciju',
                                    onPressed: () {
                                      setState(() {
                                        op.dispose();
                                        _operations.removeAt(oi);
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                            TextFormField(
                              controller: op.operationName,
                              decoration: const InputDecoration(
                                labelText: 'Naziv operacije',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() => op.characteristics.add(_CharBlock()));
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Karakteristika'),
                              ),
                            ),
                            ...op.characteristics.asMap().entries.map((ce) {
                              final ci = ce.key;
                              final ch = ce.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Karakteristika ${ci + 1}',
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: ch.name,
                                            decoration: const InputDecoration(
                                              labelText: 'Naziv',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        if (op.characteristics.length > 1)
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                ch.dispose();
                                                op.characteristics.removeAt(ci);
                                              });
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: ch.nominal,
                                      decoration: const InputDecoration(
                                        labelText: 'Nominalna vrijednost',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: ch.tolMin,
                                            decoration: const InputDecoration(
                                              labelText: 'Tolerancija min',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            controller: ch.tolMax,
                                            decoration: const InputDecoration(
                                              labelText: 'Tolerancija max',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: ch.unit,
                                      decoration: const InputDecoration(
                                        labelText: 'Jedinica',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
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
    );
  }
}
