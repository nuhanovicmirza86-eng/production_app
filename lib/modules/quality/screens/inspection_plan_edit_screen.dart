import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_service.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_display_formatters.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';

/// Plan kontrole: productId + controlPlanId + tip + refs karakteristika (npr. 0:0,0:1).
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
  final _productService = ProductService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _productId;
  late final TextEditingController _controlPlanId;
  late final TextEditingController _plantKey;
  late final TextEditingController _refs;

  String _inspectionType = 'IN_PROCESS';
  String _status = 'draft';
  String? _approvedAtIso;
  String? _approvedByUid;
  String? _obsoleteAtIso;
  String? _obsoleteByUid;
  String? _productDisplayLine;
  String? _controlPlanTitle;
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
    _productId = TextEditingController();
    _controlPlanId = TextEditingController();
    _plantKey = TextEditingController(text: _defaultPlantKey);
    _refs = TextEditingController();
    _loadExisting();
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

  Future<void> _refreshControlPlanLabel() async {
    final id = _controlPlanId.text.trim();
    if (id.isEmpty) {
      setState(() => _controlPlanTitle = null);
      return;
    }
    try {
      final m = await _svc.getQmsControlPlanMap(
        companyId: _cid,
        controlPlanId: id,
      );
      if (!mounted) return;
      final title = (m['title'] ?? '').toString().trim();
      setState(
        () => _controlPlanTitle = title.isEmpty
            ? 'Kontrolni plan (bez naslova)'
            : title,
      );
    } catch (_) {
      if (mounted) setState(() => _controlPlanTitle = null);
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.inspectionPlanId;
    if (id == null || id.isEmpty) {
      _approvedAtIso = null;
      _approvedByUid = null;
      _obsoleteAtIso = null;
      _obsoleteByUid = null;
      setState(() => _loading = false);
      await _loadPlants();
      await _refreshProductLabel();
      await _refreshControlPlanLabel();
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
      _approvedAtIso = m['approvedAt']?.toString();
      _approvedByUid = m['approvedByUid']?.toString();
      _obsoleteAtIso = m['obsoleteAt']?.toString();
      _obsoleteByUid = m['obsoleteByUid']?.toString();
      final it = (m['inspectionType'] ?? 'IN_PROCESS').toString().toUpperCase();
      if (it == 'INCOMING' || it == 'IN_PROCESS' || it == 'FINAL') {
        _inspectionType = it;
      }
      final rawRefs = m['characteristicRefs'];
      if (rawRefs is List && rawRefs.isNotEmpty) {
        _refs.text = rawRefs.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(', ');
      }
      await _refreshProductLabel();
      await _refreshControlPlanLabel();
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

  /// Generiše refove 0:0, 0:1, … iz učitanog kontrolnog plana (isti red kao backend).
  List<({String ref, String label})> _refsFromControlPlanMap(Map<String, dynamic> cp) {
    final out = <({String ref, String label})>[];
    final ops = cp['operations'] as List? ?? [];
    for (var oi = 0; oi < ops.length; oi++) {
      final op = ops[oi];
      if (op is! Map) continue;
      final chars = op['characteristics'] as List? ?? [];
      for (var ci = 0; ci < chars.length; ci++) {
        final ref = '$oi:$ci';
        String name = ref;
        final ch = chars[ci];
        if (ch is Map) {
          name = (ch['name'] ?? ref).toString();
        }
        final display = name.trim().isEmpty ? ref : name;
        out.add((ref: ref, label: display));
      }
    }
    return out;
  }

  Future<void> _pickRefsFromControlPlan() async {
    final cpId = _controlPlanId.text.trim();
    if (cpId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi kontrolni plan.')),
      );
      return;
    }
    try {
      final cp = await _svc.getQmsControlPlanMap(companyId: _cid, controlPlanId: cpId);
      if (!mounted) return;
      final options = _refsFromControlPlanMap(cp);
      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kontrolni plan nema karakteristika.')),
        );
        return;
      }
      final current = _parseRefs(_refs.text).toSet();
      final selected = <String>{...current};
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('Odaberi karakteristike'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((o) {
                      final checked = selected.contains(o.ref);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(o.label, style: const TextStyle(fontSize: 13)),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selected.add(o.ref);
                            } else {
                              selected.remove(o.ref);
                            }
                          });
                        },
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
        final list = selected.toList()..sort();
        setState(() {
          _refs.text = list.join(', ');
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi proizvod.')),
      );
      return;
    }
    if (_controlPlanId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi kontrolni plan.')),
      );
      return;
    }
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
        title: Text(isNew ? 'Novi plan kontrole' : 'Uredi plan kontrole'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Plan kontrole',
            message:
                '${QmsIatfStrings.editInspectionPlan}\n\n${QmsIatfStrings.termInspectionType}',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    Text(
                      'Kontrolni plan *',
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
                        _controlPlanId.text.trim().isEmpty
                            ? 'Nije odabran'
                            : (_controlPlanTitle ?? 'Učitavanje…'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _controlPlanId.text.trim().isEmpty
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final id = await showQmsControlPlanPicker(
                            context: context,
                            companyId: _cid,
                            productIdFilter: _productId.text.trim().isEmpty
                                ? null
                                : _productId.text.trim(),
                          );
                          if (id != null && mounted) {
                            setState(() => _controlPlanId.text = id);
                            await _refreshControlPlanLabel();
                          }
                        },
                        icon: const Icon(Icons.engineering_outlined, size: 20),
                        label: Text(
                          _controlPlanId.text.trim().isEmpty
                              ? 'Odaberi kontrolni plan'
                              : 'Promijeni kontrolni plan',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey<String>(
                        'ip_plant_${_plantKey.text}_${_plants.length}',
                      ),
                      initialValue: _plantKey.text.trim().isEmpty
                          ? null
                          : _plantKey.text.trim(),
                      decoration: InputDecoration(
                        labelText: 'Pogon',
                        border: const OutlineInputBorder(),
                        helperText:
                            _plantsLoading ? 'Učitavanje pogona…' : null,
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
                      key: ValueKey<String>('ip_type_$_inspectionType'),
                      initialValue: _inspectionType,
                      decoration: InputDecoration(
                        labelText: 'Tip kontrole',
                        border: const OutlineInputBorder(),
                        suffixIcon: QmsIatfInfoIcon(
                          title: 'Tip kontrole',
                          message: QmsIatfStrings.termInspectionType,
                          size: 20,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'INCOMING',
                          child: Text('Ulazna'),
                        ),
                        DropdownMenuItem(
                          value: 'IN_PROCESS',
                          child: Text('U procesu'),
                        ),
                        DropdownMenuItem(
                          value: 'FINAL',
                          child: Text('Završna'),
                        ),
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
                    QmsIatfSectionTitle(
                      label:
                          'Karakteristike (npr. 0:0, 0:1 — unutrašnji redoslijed). '
                          'Prazno = sve iz kontrolnog plana.',
                      iatfTitle: 'Karakteristike u kontrolnom planu',
                      iatfMessage: QmsIatfStrings.termCharacteristicRefs,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _refs,
                      decoration: const InputDecoration(
                        labelText: 'Karakteristike (opcionalno)',
                        hintText: 'npr. 0:0, 0:1',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickRefsFromControlPlan,
                      icon: const Icon(Icons.checklist_outlined),
                      label: const Text('Odaberi karakteristike iz kontrolnog plana'),
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
