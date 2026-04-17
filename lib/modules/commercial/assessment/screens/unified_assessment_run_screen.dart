import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/core/errors/app_error_mapper.dart';
import 'package:production_app/modules/commercial/assessment/services/assessment_engine_service.dart';

/// Jedinstveni UI za procjenu prema `assessment_templates` + Callable `computeAssessment`.
///
/// Vidi: `docs/architecture/ASSESSMENT_ENGINE_UNIFIED_MODEL.md`
class UnifiedAssessmentRunScreen extends StatefulWidget {
  const UnifiedAssessmentRunScreen({
    super.key,
    required this.companyId,
    this.plantKey = '',
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.userRole,
  });

  final String companyId;
  final String plantKey;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String userRole;

  @override
  State<UnifiedAssessmentRunScreen> createState() =>
      _UnifiedAssessmentRunScreenState();
}

class _PfmeaRow {
  int s = 5;
  int o = 5;
  int d = 5;
}

class _UnifiedAssessmentRunScreenState
    extends State<UnifiedAssessmentRunScreen> {
  final AssessmentEngineService _engine = AssessmentEngineService();
  final Map<String, TextEditingController> _textCtrls = {};
  final Map<String, bool> _boolVals = {};
  final Map<String, int> _scaleVals = {};

  String _role = '';

  /// Grubo usklađeno s backend `canComputeAssessment` (samo UX; Callable i dalje validira).
  bool get _canCompute {
    final r = _role;
    if (ProductionAccessHelper.isSuperAdminRole(r)) return true;
    if (ProductionAccessHelper.isAdminRole(r)) {
      return true;
    }
    final et = _et;
    if (et == 'supplier' || et == 'customer') {
      return r == 'purchasing' ||
          r == 'production_manager' ||
          r == 'supervisor' ||
          r == 'logistics_manager';
    }
    if (et == 'production_order') {
      return r == 'production_manager' || r == 'supervisor';
    }
    if (et == 'asset') {
      return r == 'maintenance_manager' || r == 'maintenance';
    }
    if (et == 'process_step' || et == 'quality_event') {
      return r == 'maintenance_manager' ||
          r == 'production_manager' ||
          r == 'supervisor';
    }
    return false;
  }

  String? _selectedTemplateId;
  Map<String, dynamic>? _templateDoc;

  final List<_PfmeaRow> _pfmeaRows = [_PfmeaRow()];

  bool _computing = false;
  bool _creatingTemplate = false;
  String? _error;
  AssessmentComputeResult? _lastResult;

  String get _cid => widget.companyId.trim();
  String get _et => widget.entityType.trim().toLowerCase();
  String get _eid => widget.entityId.trim();
  String get _pk => widget.plantKey.trim();

  @override
  void initState() {
    super.initState();
    _role = ProductionAccessHelper.normalizeRole(widget.userRole);
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearTemplateFields() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    _textCtrls.clear();
    _boolVals.clear();
    _scaleVals.clear();
    _pfmeaRows
      ..clear()
      ..add(_PfmeaRow());
  }

  void _onTemplateSelected(String? id, Map<String, dynamic>? doc) {
    setState(() {
      _clearTemplateFields();
      _selectedTemplateId = id;
      _templateDoc = doc;
      if (doc == null) return;

      final crit = doc['criteria'];
      if (crit is! List) return;

      for (final raw in crit) {
        if (raw is! Map) continue;
        final c = Map<String, dynamic>.from(raw);
        final code = (c['code'] ?? '').toString().trim();
        if (code.isEmpty) continue;
        final type = (c['type'] ?? 'scale').toString().toLowerCase();
        final method = (doc['calculationMethod'] ?? '')
            .toString()
            .toLowerCase();

        if (method == 'threshold_bands' || type == 'kpi_threshold') {
          _textCtrls[code] = TextEditingController();
        } else if (type == 'boolean') {
          _boolVals[code] = false;
        } else if (type == 'number') {
          _textCtrls[code] = TextEditingController();
        } else {
          final smin = _numOr(c['scaleMin'], 1).round();
          _scaleVals[code] = smin;
        }
      }
    });
  }

  double _numOr(dynamic v, double d) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? d;
  }

  bool _isPfmeaTemplate(Map<String, dynamic>? d) {
    if (d == null) return false;
    final at = (d['assessmentType'] ?? '').toString().toUpperCase();
    final cm = (d['calculationMethod'] ?? '').toString().toLowerCase();
    return at == 'PFMEA' || cm == 'fmea_rpn';
  }

  bool get _canManageTemplates {
    final r = _role;
    return ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == 'production_manager' ||
        r == 'supervisor' ||
        r == 'purchasing' ||
        r == 'logistics_manager';
  }

  Map<String, dynamic> _starterTemplatePayload() {
    final et = _et;
    final nameSuffix = switch (et) {
      'customer' => 'Customer',
      'supplier' => 'Supplier',
      'production_order' => 'Production Order',
      'asset' => 'Asset',
      'process_step' => 'Process Step',
      'quality_event' => 'Quality Event',
      _ => et.toUpperCase(),
    };
    // Mora odgovarati backend `upperEnum` u upsertAssessmentTemplate:
    // assessmentType ∈ {RISK, KPI, PFMEA}, calculationMethod ∈ {WEIGHTED_SUM, THRESHOLD_BANDS, FMEA_RPN}.
    return <String, dynamic>{
      'name': 'Starter $nameSuffix',
      'entityType': et,
      'assessmentType': 'KPI',
      'calculationMethod': 'WEIGHTED_SUM',
      'active': true,
      'criteria': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'quality',
          'label': 'Kvalitet',
          'type': 'scale',
          'scaleMin': 1,
          'scaleMax': 5,
          'weight': 0.40,
        },
        <String, dynamic>{
          'code': 'delivery',
          'label': 'Isporuka / rok',
          'type': 'scale',
          'scaleMin': 1,
          'scaleMax': 5,
          'weight': 0.35,
        },
        <String, dynamic>{
          'code': 'responsiveness',
          'label': 'Responsivnost',
          'type': 'scale',
          'scaleMin': 1,
          'scaleMax': 5,
          'weight': 0.25,
        },
      ],
    };
  }

  Future<void> _createStarterTemplate() async {
    if (_cid.isEmpty || _et.isEmpty) return;
    setState(() {
      _creatingTemplate = true;
      _error = null;
    });
    try {
      await _engine.upsertAssessmentTemplate(
        companyId: _cid,
        payload: _starterTemplatePayload(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Početni šablon je kreiran. Sada ga možeš odabrati i pokrenuti procjenu.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapComputeError(e));
    } finally {
      if (mounted) {
        setState(() => _creatingTemplate = false);
      }
    }
  }

  Map<String, dynamic> _buildInputs(Map<String, dynamic> tpl) {
    final out = <String, dynamic>{};
    final crit = tpl['criteria'];
    if (crit is! List) return out;

    for (final raw in crit) {
      if (raw is! Map) continue;
      final c = Map<String, dynamic>.from(raw);
      final code = (c['code'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      final type = (c['type'] ?? 'scale').toString().toLowerCase();
      final method = (tpl['calculationMethod'] ?? '').toString().toLowerCase();

      if (method == 'threshold_bands' || type == 'kpi_threshold') {
        final t = _textCtrls[code];
        final v = double.tryParse(t?.text.trim().replaceAll(',', '.') ?? '');
        if (v == null) {
          throw Exception('Kriterij $code: unesi broj.');
        }
        out[code] = v;
      } else if (type == 'boolean') {
        out[code] = _boolVals[code] ?? false;
      } else if (type == 'number') {
        final t = _textCtrls[code];
        final v = double.tryParse(t?.text.trim().replaceAll(',', '.') ?? '');
        if (v == null) {
          throw Exception('Kriterij $code: unesi broj.');
        }
        out[code] = v;
      } else {
        out[code] = _scaleVals[code] ?? 1;
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _buildPfmeaLines() {
    return _pfmeaRows
        .map((e) => <String, dynamic>{'s': e.s, 'o': e.o, 'd': e.d})
        .toList();
  }

  String _mapComputeError(Object e) {
    if (e is FirebaseFunctionsException) {
      final m = e.message?.trim();
      if (m != null && m.isNotEmpty) return m;
      return e.code;
    }
    return AppErrorMapper.toMessage(e);
  }

  Future<void> _runCompute() async {
    final tid = _selectedTemplateId?.trim() ?? '';
    final tpl = _templateDoc;
    if (_cid.isEmpty || tid.isEmpty || tpl == null) {
      setState(() => _error = 'Odaberi šablon.');
      return;
    }

    setState(() {
      _computing = true;
      _error = null;
    });

    try {
      Map<String, dynamic> inputs = const {};
      List<Map<String, dynamic>> pfmea = const [];

      if (_isPfmeaTemplate(tpl)) {
        pfmea = _buildPfmeaLines();
      } else {
        inputs = _buildInputs(tpl);
      }

      final res = await _engine.computeAssessment(
        companyId: _cid,
        plantKey: _pk,
        templateId: tid,
        entityType: _et,
        entityId: _eid,
        inputs: inputs,
        pfmeaLines: pfmea,
        status: 'draft',
      );

      if (!mounted) return;
      setState(() {
        _lastResult = res;
        _computing = false;
      });
      if (!mounted) return;
      final syncNote = res.legacyAssetRiskSynced
          ? ' PFMEA (najgori red) upisan u polje rizika uređaja.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sačuvano. Skor: ${res.totalScore.toStringAsFixed(1)} • ${res.riskLevel}.$syncNote',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _computing = false;
        _error = _mapComputeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty || _eid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Procjena')),
        body: const Center(child: Text('Nedostaje companyId ili entityId.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Procjena: $_et'),
            Text(
              widget.entityLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_canCompute)
            Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Vaša uloga možda nema pravo na izračun za ovaj tip entiteta. '
                  'Ako je potrebno, obratite se Adminu.',
                ),
              ),
            ),
          if (!_canCompute) const SizedBox(height: 8),
          if (_error != null) ...[
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_lastResult != null)
            Card(
              child: ListTile(
                title: const Text('Zadnji izračun'),
                subtitle: Text(
                  'Skor: ${_lastResult!.totalScore.toStringAsFixed(1)} • '
                  'Nivo: ${_lastResult!.riskLevel}'
                  '${_lastResult!.maxRpn != null ? ' • max RPN: ${_lastResult!.maxRpn}' : ''}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('assessment_templates')
                .where('companyId', isEqualTo: _cid)
                .where('entityType', isEqualTo: _et)
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Šabloni: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nema aktivnih šablona za ovaj tip entiteta.',
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Možeš kreirati starter šablon direktno iz ovog ekrana.',
                        ),
                        if (_canManageTemplates) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _creatingTemplate
                                ? null
                                : _createStarterTemplate,
                            icon: _creatingTemplate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_task_outlined),
                            label: const Text('Kreiraj starter šablon'),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Za kreiranje šablona potreban je manager/admin pristup '
                            '(production_manager, logistics_manager, supervisor, '
                            'purchasing, admin).',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              final items = docs
                  .map(
                    (d) => DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(
                        (d.data()['name'] ?? d.id).toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList();

              final currentId = _selectedTemplateId;
              final validId =
                  currentId != null && docs.any((d) => d.id == currentId)
                  ? currentId
                  : null;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Šablon',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: validId,
                        decoration: const InputDecoration(),
                        items: items,
                        onChanged: (v) {
                          if (v == null) return;
                          final doc = docs.firstWhere((e) => e.id == v).data();
                          _onTemplateSelected(v, doc);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_templateDoc != null) ...[
            if (_isPfmeaTemplate(_templateDoc)) ...[
              _pfmeaCard(),
            ] else ...[
              _criteriaCard(_templateDoc!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_computing || !_canCompute) ? null : _runCompute,
              icon: _computing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: const Text('Izračunaj i sačuvaj'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Historija procjena',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _historySection(),
        ],
      ),
    );
  }

  Widget _criteriaCard(Map<String, dynamic> tpl) {
    final crit = tpl['criteria'];
    if (crit is! List || crit.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Šablon nema kriterija (prazan skor).'),
        ),
      );
    }

    final children = <Widget>[];
    for (final raw in crit) {
      if (raw is! Map) continue;
      final c = Map<String, dynamic>.from(raw);
      final code = (c['code'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      final label = (c['label'] ?? code).toString();
      final type = (c['type'] ?? 'scale').toString().toLowerCase();
      final method = (tpl['calculationMethod'] ?? '').toString().toLowerCase();
      final weight = c['weight'];

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      if (weight != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Težina: $weight',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        );
      }

      if (method == 'threshold_bands' || type == 'kpi_threshold') {
        children.add(
          TextField(
            controller: _textCtrls[code],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Broj (KPI / pragovi)'),
          ),
        );
      } else if (type == 'boolean') {
        children.add(
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Da / Ne'),
            value: _boolVals[code] ?? false,
            onChanged: (v) => setState(() => _boolVals[code] = v),
          ),
        );
      } else if (type == 'number') {
        children.add(
          TextField(
            controller: _textCtrls[code],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Broj'),
          ),
        );
      } else {
        final smin = _numOr(c['scaleMin'], 1).round();
        final smax = _numOr(c['scaleMax'], 5).round();
        final cur = _scaleVals[code] ?? smin;
        children.add(
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: cur.toDouble(),
                  min: smin.toDouble(),
                  max: smax.toDouble(),
                  divisions: smax > smin ? smax - smin : null,
                  label: '$cur',
                  onChanged: (v) =>
                      setState(() => _scaleVals[code] = v.round()),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('$cur', textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unos kriterija',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _pfmeaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PFMEA linije (S, O, D)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...List.generate(_pfmeaRows.length, (i) {
              final row = _pfmeaRows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      '#${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sodDropdown(
                        'S',
                        row.s,
                        (v) => setState(() => row.s = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sodDropdown(
                        'O',
                        row.o,
                        (v) => setState(() => row.o = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sodDropdown(
                        'D',
                        row.d,
                        (v) => setState(() => row.d = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ukloni red',
                      onPressed: _pfmeaRows.length <= 1
                          ? null
                          : () => setState(() => _pfmeaRows.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => setState(() => _pfmeaRows.add(_PfmeaRow())),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj red'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sodDropdown(String label, int value, void Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      // ignore: deprecated_member_use
      value: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: List.generate(
        10,
        (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
      ),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _historySection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('risk_assessments')
          .where('companyId', isEqualTo: _cid)
          .where('entityType', isEqualTo: _et)
          .where('entityId', isEqualTo: _eid)
          .orderBy('calculatedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Historija: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('Još nema sačuvanih procjena.');
        }
        return Column(
          children: docs.map((d) {
            final m = d.data();
            final scores = (m['scores'] as Map?) ?? {};
            final ts = m['calculatedAt'];
            String when = '';
            if (ts is Timestamp) {
              when = ts.toDate().toLocal().toString().split('.').first;
            }
            return Card(
              child: ListTile(
                title: Text(
                  'v${m['version'] ?? '?'} • ${scores['riskLevel'] ?? ''}',
                ),
                subtitle: Text(
                  'Skor: ${scores['totalScore'] ?? ''} • šablon: ${m['templateId'] ?? ''}\n$when',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
