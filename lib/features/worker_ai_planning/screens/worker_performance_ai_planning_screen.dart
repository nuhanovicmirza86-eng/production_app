import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../features/process_evidence_analytics/models/process_evidence_analytics_models.dart';
import '../../../features/process_evidence_analytics/widgets/process_evidence_analytics_filters.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/services/production_station_config_callable_service.dart';
import '../models/worker_performance_ai_signals_models.dart';
import '../services/worker_performance_ai_signals_callable_service.dart';
import '../../../modules/workforce/widgets/workforce_screen_help.dart';

/// M2-F4-F1 — read-only AI preporuke za planiranje rada (savjetodavno).
class WorkerPerformanceAiPlanningScreen extends StatefulWidget {
  const WorkerPerformanceAiPlanningScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<WorkerPerformanceAiPlanningScreen> createState() =>
      _WorkerPerformanceAiPlanningScreenState();
}

class _WorkerPerformanceAiPlanningScreenState
    extends State<WorkerPerformanceAiPlanningScreen> {
  final _service = WorkerPerformanceAiSignalsCallableService();
  final _stationConfigService = ProductionStationConfigCallableService();
  final _planningQuestionController = TextEditingController();

  bool _loading = false;
  Object? _error;
  WorkerPerformanceAiSignalsResult? _result;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _plantKey;
  String? _processProfileType;
  String? _stationConfigId;

  List<({String plantKey, String label})> _plantOptions = const [];
  List<ProductionStationConfig> _allStationConfigs = const [];
  String? _fixedPlantLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canAccess =>
      ProductionAccessHelper.canViewProfileDrivenEvidence(_userRole);

  bool get _canPickPlant =>
      ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(
        _userRole,
      );

  ProcessEvidenceAnalyticsFilters get _filters =>
      ProcessEvidenceAnalyticsFilters(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        plantKey: _plantKey,
        processProfileType: _processProfileType,
        stationConfigId: _stationConfigId,
      );

  List<ProductionStationConfig> get _stationOptions =>
      filterAnalyticsStationOptions(
        configs: _allStationConfigs,
        plantKey: _plantKey,
        processProfileType: _processProfileType,
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = DateTime(now.year, now.month, now.day);
    _dateFrom = _dateTo.subtract(const Duration(days: 29));
    if (!_canPickPlant && _userPlantKey.isNotEmpty) {
      _plantKey = _userPlantKey;
    }
    if (_canAccess) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _planningQuestionController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final plantsFuture = loadAnalyticsPlantOptions(
        companyId: _companyId,
        userRole: _userRole,
        userPlantKey: _userPlantKey,
      );
      final configsFuture = _stationConfigService.listProductionStationConfigs(
        companyId: _companyId,
      );
      final plants = await plantsFuture;
      final configs = await configsFuture;
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
        _allStationConfigs = configs.configs;
        _fixedPlantLabel = fixedLabel;
      });
      await _loadSignals();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _loadSignals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getSignals(
        companyId: _companyId,
        filters: _filters,
        planningQuestion: _planningQuestionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workerPerformanceAiSignalsErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(_dateTo)) _dateFrom = _dateTo;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI preporuke za planiranje rada')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nemaš pristup ovom ekranu.'),
          ),
        ),
      );
    }

    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI preporuke za planiranje rada'),
        actions: [
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.aiPlanningTitle,
            message: WorkforceHelpTexts.aiPlanningMessage,
          ),
          IconButton(
            tooltip: 'Generiši preporuke',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _loading ? null : _loadSignals,
          ),
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSignals,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProcessEvidenceAnalyticsFiltersPanel(
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            plantKey: _plantKey,
            processProfileType: _processProfileType,
            stationConfigId: _stationConfigId,
            operatorId: null,
            plantOptions: _plantOptions,
            stationOptions: _stationOptions,
            operatorOptions: const [],
            canPickPlant: _canPickPlant,
            fixedPlantLabel: _fixedPlantLabel,
            loading: _loading,
            onPickDateFrom: () => _pickDate(isFrom: true),
            onPickDateTo: () => _pickDate(isFrom: false),
            onPlantChanged: (v) {
              setState(() {
                _plantKey = v;
                _stationConfigId = null;
              });
            },
            onProfileChanged: (v) {
              setState(() {
                _processProfileType = v;
                _stationConfigId = null;
              });
            },
            onStationChanged: (v) => setState(() => _stationConfigId = v),
            onOperatorChanged: (_) {},
            onApply: _loadSignals,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _planningQuestionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Kontekst planiranja (opcionalno)',
              hintText: 'npr. dorada lakiranje proizvod X',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _loadSignals(),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error.toString(),
              style: TextStyle(color: cs.error),
            )
          else if (_result != null) ...[
            _statusCard(context, _result!),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Preporuke'),
            ..._result!.recommendations.map((e) => _recommendationTile(context, e)),
            if (_result!.recommendations.isEmpty)
              _emptyHint(context, 'Nema preporuka za odabrane filtere.'),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Upozorenja'),
            ..._result!.warnings.map((e) => _warningTile(context, e)),
            if (_result!.warnings.isEmpty)
              _emptyHint(context, 'Nema upozorenja.'),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Rizici'),
            ..._result!.risks.map((e) => _riskTile(context, e)),
            if (_result!.risks.isEmpty) _emptyHint(context, 'Nema rizika.'),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Prikladnost radnika'),
            ..._result!.workerSuitability.map((e) => _suitabilityTile(context, e)),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Usklađenost s operacijom'),
            ..._result!.operationFit.map((e) => _operationFitTile(context, e)),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Prijedlozi obuke'),
            ..._result!.trainingSuggestions.map((e) => _trainingTile(context, e)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, WorkerPerformanceAiSignalsResult r) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.disclaimer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Izvor: evidencije procesa'),
            if (r.sessionCountAnalyzed != null)
              Text('Analizirano evidencija: ${r.sessionCountAnalyzed}'),
            if (r.aiUsed)
              Text(
                'AI dopuna: aktivna',
                style: TextStyle(color: cs.primary),
              ),
            for (final note in r.dataQualityNotes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _recommendationTile(
    BuildContext context,
    WorkerPerformanceAiRecommendation item,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.lightbulb_outline),
        title: Text(item.summary ?? '—'),
        subtitle: Text([
          if ((item.type ?? '').isNotEmpty) item.type!,
          if ((item.operatorDisplayName ?? '').isNotEmpty) item.operatorDisplayName!,
          if ((item.confidence ?? '').isNotEmpty) 'pouzdanost: ${item.confidence}',
        ].join(' · ')),
        children: [_evidencePanel(context, item.evidenceRefs)],
      ),
    );
  }

  Widget _warningTile(BuildContext context, WorkerPerformanceAiWarning item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(Icons.warning_amber_outlined, color: _severityColor(context, item.severity)),
        title: Text(item.summary ?? '—'),
        subtitle: Text(item.severity ?? ''),
        children: [_evidencePanel(context, item.evidenceRefs)],
      ),
    );
  }

  Widget _riskTile(BuildContext context, WorkerPerformanceAiRisk item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.report_outlined),
        title: Text(item.summary ?? '—'),
        subtitle: Text(item.riskType ?? ''),
        children: [_evidencePanel(context, item.evidenceRefs)],
      ),
    );
  }

  Widget _suitabilityTile(
    BuildContext context,
    WorkerPerformanceAiWorkerSuitability item,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.person_search_outlined),
        title: Text(item.summary ?? '—'),
        subtitle: Text(item.operationTypes.join(', ')),
      ),
    );
  }

  Widget _operationFitTile(
    BuildContext context,
    WorkerPerformanceAiOperationFit item,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.handyman_outlined),
        title: Text(item.summary ?? '—'),
        subtitle: Text('${item.operatorDisplayName ?? ''} · ${item.operationType ?? ''}'),
      ),
    );
  }

  Widget _trainingTile(
    BuildContext context,
    WorkerPerformanceAiTrainingSuggestion item,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: Text(item.summary ?? '—'),
        subtitle: Text(item.operationTypes.join(', ')),
      ),
    );
  }

  Widget _evidencePanel(
    BuildContext context,
    List<WorkerPerformanceAiEvidenceRef> refs,
  ) {
    if (refs.isEmpty) {
      return const ListTile(title: Text('Nema referenci na evidencije.'));
    }
    return Column(
      children: refs
          .map(
            (ref) => ListTile(
              dense: true,
              title: Text(ref.metric ?? 'metrika'),
              subtitle: Text(
                'Vrijednost: ${ref.value ?? '—'} · '
                'period: ${ref.period?['dateFrom'] ?? '—'} – ${ref.period?['dateTo'] ?? '—'}',
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Color _severityColor(BuildContext context, String? severity) {
    switch (severity) {
      case 'critical':
        return Theme.of(context).colorScheme.error;
      case 'warning':
        return Theme.of(context).colorScheme.tertiary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
