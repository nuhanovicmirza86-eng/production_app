import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../features/process_evidence_analytics/widgets/process_evidence_analytics_filters.dart';
import '../models/workforce_performance_norm_models.dart';
import '../services/workforce_performance_norms_callable_service.dart';
import 'workforce_performance_norm_detail_screen.dart';

/// M2-G2 — administracija normativa učinka (lista + filteri).
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
  final _normGroupIdController = TextEditingController();

  bool _loading = false;
  Object? _error;
  List<WorkforcePerformanceNorm> _norms = const [];

  String? _statusFilter;
  String? _plantKeyFilter;
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

  @override
  void dispose() {
    _normGroupIdController.dispose();
    super.dispose();
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
        normGroupId: _normGroupIdController.text.trim().isEmpty
            ? null
            : _normGroupIdController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _norms = norms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workforcePerformanceNormsErrorMessage(e);
        _loading = false;
      });
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Normativi rada')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Novi nacrt'),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String?>(
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
                            onChanged: (v) => setState(() => _statusFilter = v),
                          ),
                        ),
                        if (_canPickPlant)
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String?>(
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
                              onChanged: (v) =>
                                  setState(() => _plantKeyFilter = v),
                            ),
                          )
                        else if (_fixedPlantLabel != null)
                          Chip(label: Text('Pogon: $_fixedPlantLabel')),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _normGroupIdController,
                            decoration: const InputDecoration(
                              labelText: 'normGroupId',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _loading ? null : _loadNorms,
                          icon: const Icon(Icons.search),
                          label: const Text('Primijeni'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error.toString(),
                  style: TextStyle(color: t.colorScheme.error),
                ),
              ),
            if (_loading && _norms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_norms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Nema normativa za odabrane filtere.'),
                ),
              )
            else
              ..._norms.map((norm) {
                final profileLabel = workforceNormProfileLabels[
                        norm.processProfileType ?? ''] ??
                    norm.processProfileType ??
                    '—';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      (norm.displayName ?? '').trim().isNotEmpty
                          ? norm.displayName!.trim()
                          : 'Normativ v${norm.version}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'v${norm.version} · ${workforceNormStatusLabel(norm.status)} · $profileLabel',
                        ),
                        if ((norm.plantKey ?? '').isNotEmpty)
                          Text('Pogon: ${norm.plantKey}'),
                        Text(
                          'Grupa: ${norm.normGroupId}',
                          style: t.textTheme.bodySmall,
                        ),
                        if ((norm.validFrom ?? '').isNotEmpty)
                          Text(
                            'Vrijedi od: ${norm.validFrom}'
                            '${(norm.validTo ?? '').isNotEmpty ? ' do ${norm.validTo}' : ''}',
                            style: t.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    isThreeLine: true,
                    onTap: () => _openDetail(norm),
                  ),
                );
              }),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
