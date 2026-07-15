import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../features/process_evidence_analytics/widgets/process_evidence_analytics_filters.dart';
import '../models/workforce_performance_norm_models.dart';
import '../services/workforce_performance_norms_callable_service.dart';
import 'workforce_performance_norm_detail_screen.dart';

/// M2-G2 — administracija normativa učinka (filteri + odabir s liste).
class WorkforcePerformanceNormsListScreen extends StatefulWidget {
  const WorkforcePerformanceNormsListScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<WorkforcePerformanceNormsListScreen> createState() =>
      _WorkforcePerformanceNormsListScreenState();
}

class _WorkforcePerformanceNormsListScreenState
    extends State<WorkforcePerformanceNormsListScreen> {
  final _service = WorkforcePerformanceNormsCallableService();

  bool _loading = false;
  Object? _error;
  List<WorkforcePerformanceNorm> _norms = const [];

  String? _statusFilter;
  String? _plantKeyFilter;
  String? _profileFilter;
  String? _selectedNormId;

  List<({String plantKey, String label})> _plantOptions = const [];
  String? _fixedPlantLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canManage =>
      ProductionAccessHelper.canManageWorkforcePerformanceNorms(_userRole);

  bool get _canPickPlant =>
      ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(
        _userRole,
      );

  List<WorkforcePerformanceNorm> get _filteredNorms {
    if (_profileFilter == null) return _norms;
    return _norms
        .where((n) => n.processProfileType == _profileFilter)
        .toList(growable: false);
  }

  WorkforcePerformanceNorm? get _selectedNorm {
    final id = _selectedNormId;
    if (id == null) return null;
    for (final norm in _filteredNorms) {
      if (norm.normId == id) return norm;
    }
    return null;
  }

  static String _normOptionLabel(WorkforcePerformanceNorm norm) {
    final name = (norm.displayName ?? '').trim();
    final title = name.isNotEmpty ? name : 'Normativ v${norm.version}';
    final profile = workforceNormProfileLabels[norm.processProfileType ?? ''] ??
        norm.processProfileType ??
        '';
    final plant = (norm.plantKey ?? '').trim();
    final parts = <String>[
      title,
      'v${norm.version}',
      workforceNormStatusLabel(norm.status),
      if (profile.isNotEmpty) profile,
      if (plant.isNotEmpty) plant,
    ];
    return parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    if (!_canPickPlant && _userPlantKey.isNotEmpty) {
      _plantKeyFilter = _userPlantKey;
    }
    if (_canManage) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = await loadAnalyticsPlantOptions(
        companyId: _companyId,
        userRole: _userRole,
        userPlantKey: _userPlantKey,
      );
      String? fixedLabel;
      if (!_canPickPlant && _userPlantKey.isNotEmpty) {
        fixedLabel = await CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: _userPlantKey,
        );
      }
      if (!mounted) return;
      setState(() {
        _plantOptions = plants;
        _fixedPlantLabel = fixedLabel;
      });
      await _loadNorms();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workforcePerformanceNormsErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadNorms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final norms = await _service.listNorms(
        companyId: _companyId,
        status: _statusFilter,
        plantKey: _plantKeyFilter,
      );
      if (!mounted) return;
      setState(() {
        _norms = norms;
        _loading = false;
        _selectedNormId = _syncSelectedNormId(norms);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workforcePerformanceNormsErrorMessage(e);
        _loading = false;
        _selectedNormId = null;
      });
    }
  }

  String? _syncSelectedNormId(List<WorkforcePerformanceNorm> norms) {
    final current = _selectedNormId;
    if (current == null) return null;
    final stillVisible = norms.any((n) {
      if (n.normId != current) return false;
      if (_profileFilter == null) return true;
      return n.processProfileType == _profileFilter;
    });
    return stillVisible ? current : null;
  }

  void _onProfileChanged(String? value) {
    setState(() {
      _profileFilter = value;
      _selectedNormId = _syncSelectedNormId(_norms);
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkforcePerformanceNormDetailScreen(
          companyData: widget.companyData,
        ),
      ),
    );
    if (created == true) await _loadNorms();
  }

  Future<void> _openDetail(WorkforcePerformanceNorm norm) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkforcePerformanceNormDetailScreen(
          companyData: widget.companyData,
          normId: norm.normId,
        ),
      ),
    );
    if (changed == true) await _loadNorms();
  }

  Future<void> _openSelectedNorm() async {
    final norm = _selectedNorm;
    if (norm == null) return;
    await _openDetail(norm);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Normativi rada')),
        body: const Center(
          child: Text('Nemaš pravo administracije normativa učinka.'),
        ),
      );
    }

    final t = Theme.of(context);
    final options = _filteredNorms;
    final selected = _selectedNorm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Normativi rada'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openCreate,
            icon: const Icon(Icons.add),
            tooltip: 'Novi nacrt',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNorms,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filteri',
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Odaberite vrijednosti s liste — ništa se ne upisuje ručno.',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi statusi'),
                        ),
                        ...workforceNormStatuses.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s,
                            child: Text(workforceNormStatusLabel(s)),
                          ),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() => _statusFilter = v);
                              _loadNorms();
                            },
                    ),
                    const SizedBox(height: 12),
                    if (_canPickPlant)
                      DropdownButtonFormField<String?>(
                        value: _plantKeyFilter,
                        decoration: const InputDecoration(
                          labelText: 'Pogon',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Svi pogoni'),
                          ),
                          ..._plantOptions.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.plantKey,
                              child: Text(p.label),
                            ),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (v) {
                                setState(() => _plantKeyFilter = v);
                                _loadNorms();
                              },
                      )
                    else if (_fixedPlantLabel != null)
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pogon',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(_fixedPlantLabel!),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _profileFilter,
                      decoration: const InputDecoration(
                        labelText: 'Profil procesa',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi profili'),
                        ),
                        ...workforceNormProfileLabels.entries.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: _loading ? null : _onProfileChanged,
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (options.isEmpty)
                      Text(
                        'Nema normativa za odabrane filtere.',
                        style: t.textTheme.bodyMedium,
                      )
                    else ...[
                      DropdownButtonFormField<String?>(
                        value: _selectedNormId,
                        decoration: const InputDecoration(
                          labelText: 'Normativ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: options
                            .map(
                              (norm) => DropdownMenuItem<String?>(
                                value: norm.normId,
                                child: Text(
                                  _normOptionLabel(norm),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) => setState(() => _selectedNormId = v),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: selected == null ? null : _openSelectedNorm,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Otvori normativ'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error.toString(),
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (selected.displayName ?? '').trim().isNotEmpty
                            ? selected.displayName!.trim()
                            : 'Normativ v${selected.version}',
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verzija ${selected.version} · '
                        '${workforceNormStatusLabel(selected.status)}',
                      ),
                      if ((selected.plantKey ?? '').isNotEmpty)
                        Text('Pogon: ${selected.plantKey}'),
                      if ((selected.validFrom ?? '').isNotEmpty)
                        Text(
                          'Vrijedi od: ${selected.validFrom}'
                          '${(selected.validTo ?? '').isNotEmpty ? ' do ${selected.validTo}' : ''}',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
