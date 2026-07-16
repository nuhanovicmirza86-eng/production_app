import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/auth/shared/services/auth_service.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/services/production_station_config_callable_service.dart';
import '../models/process_evidence_analytics_models.dart';
import '../services/process_evidence_analytics_callable_service.dart';
import '../widgets/process_evidence_analytics_filters.dart';
import '../widgets/process_evidence_breakdown_tables.dart';
import '../widgets/process_evidence_kpi_cards.dart';
import '../widgets/worker_performance_kpi_table.dart';
import '../../../modules/workforce/widgets/workforce_screen_help.dart';

/// M2-F2 — read-only analitika profile-driven evidencija procesa.
class ProcessEvidenceAnalyticsScreen extends StatefulWidget {
  const ProcessEvidenceAnalyticsScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<ProcessEvidenceAnalyticsScreen> createState() =>
      _ProcessEvidenceAnalyticsScreenState();
}

class _ProcessEvidenceAnalyticsScreenState
    extends State<ProcessEvidenceAnalyticsScreen> {
  final _analyticsService = ProcessEvidenceAnalyticsCallableService();
  final _stationConfigService = ProductionStationConfigCallableService();
  final _scrollController = ScrollController();

  bool _loading = true;
  Object? _error;
  ProcessEvidenceAnalyticsLoadResult? _result;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _plantKey;
  String? _processProfileType;
  String? _stationConfigId;
  String? _operatorId;

  List<({String plantKey, String label})> _plantOptions = const [];
  List<ProductionStationConfig> _allStationConfigs = const [];
  List<({String id, String label})> _operatorOptions = const [];
  String? _fixedPlantLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

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
        operatorId: _operatorId,
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
    _dateFrom = DateTime(now.year, now.month, 1);
    if (!_canPickPlant && _userPlantKey.isNotEmpty) {
      _plantKey = _userPlantKey;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadReferenceData();
    await _loadAnalytics();
  }

  Future<void> _loadReferenceData() async {
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
    } catch (_) {
      // Reference data failure should not block analytics attempt.
    }
  }

  Future<void> _loadAnalytics() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje kontekst kompanije.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _analyticsService.loadAll(
        companyId: _companyId,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _operatorOptions = result.operators
            .map(
              (o) => (
                id: o.operatorId,
                label: o.operatorDisplayName,
              ),
            )
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
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

  void _onPlantChanged(String? value) {
    setState(() {
      _plantKey = value;
      _stationConfigId = null;
    });
  }

  void _onProfileChanged(String? value) {
    setState(() {
      _processProfileType = value;
      _stationConfigId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitika evidencija procesa'),
        actions: [
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.processEvidenceAnalyticsTitle,
            message: WorkforceHelpTexts.processEvidenceAnalyticsMessage,
          ),
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAnalytics,
          ),
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              ProcessEvidenceAnalyticsFiltersPanel(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                plantKey: _plantKey,
                processProfileType: _processProfileType,
                stationConfigId: _stationConfigId,
                operatorId: _operatorId,
                plantOptions: _plantOptions,
                stationOptions: _stationOptions,
                operatorOptions: _operatorOptions,
                canPickPlant: _canPickPlant,
                fixedPlantLabel: _fixedPlantLabel,
                loading: _loading,
                onPickDateFrom: () => _pickDate(isFrom: true),
                onPickDateTo: () => _pickDate(isFrom: false),
                onPlantChanged: _onPlantChanged,
                onProfileChanged: _onProfileChanged,
                onStationChanged: (v) => setState(() => _stationConfigId = v),
                onOperatorChanged: (v) => setState(() => _operatorId = v),
                onApply: _loadAnalytics,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      processEvidenceAnalyticsErrorMessage(_error!),
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.error,
                      ),
                    ),
                  ),
                )
              else if (_result != null) ...[
                ProcessEvidenceKpiCards(
                  summary: _result!.summary,
                  truncated: _result!.summaryTruncated,
                ),
                const SizedBox(height: 24),
                WorkerPerformanceKpiTable(operators: _result!.operators),
                const SizedBox(height: 24),
                ProcessEvidenceBreakdownTables(
                  breakdowns: _result!.breakdowns,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
