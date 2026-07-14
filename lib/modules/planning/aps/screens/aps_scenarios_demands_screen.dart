import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_optimization_goal.dart';
import '../helpers/aps_session_context.dart';
import '../models/aps_capacity_warning_view.dart';
import '../models/aps_objective_profile_view.dart';
import '../models/aps_demand_view.dart';
import '../models/aps_scenario_item_view.dart';
import '../models/aps_scenario_view.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_p1_write_service.dart';
import '../widgets/aps_optimization_goal_section.dart';
import '../widgets/aps_scenario_picker.dart';
import 'aps_gantt_read_only_screen.dart';

/// Operativni P1 ekran — potražnje, scenariji, sastav scenarija, P2 generate, Gantt.
///
/// Callable-only; bez direktnog Firestore write na `aps_*`.
class ApsScenariosDemandsScreen extends StatefulWidget {
  const ApsScenariosDemandsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ApsScenariosDemandsScreen> createState() =>
      _ApsScenariosDemandsScreenState();
}

class _ApsScenariosDemandsScreenState extends State<ApsScenariosDemandsScreen>
    with SingleTickerProviderStateMixin {
  final ApsP1WriteService _service = ApsP1WriteService();
  final ApsOperationalCache _cache = ApsOperationalCache.instance;
  static final _dateFmt = DateFormat('d.M.yyyy.');

  late final ApsSessionContext _session;

  late TabController _tabController;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ApsDemandView> _demands = const [];
  List<ApsScenarioView> _scenarios = const [];
  List<ApsScenarioItemView> _scenarioItems = const [];
  List<ApsObjectiveProfileView> _objectiveProfiles = const [];
  List<ApsCapacityWarningView> _capacityWarningsForSuggestion = const [];

  ApsScenarioView? _selectedScenario;
  String? _dismissedSuggestionScenarioId;

  Map<String, dynamic> get _companyData => widget.companyData;

  String get _companyId => _session.companyId;
  String get _plantKey => _session.plantKey;
  String get _role => _session.role;

  bool get _accessOk => _session.accessOk;

  bool get _scenarioIsDraft => _selectedScenario?.status == 'draft';

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(_companyData);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadAll(fullScreenLoader: true);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  bool _loadingScenarioItems = false;

  Future<void> _loadAll({
    String? selectScenarioId,
    bool fullScreenLoader = false,
    bool forceRefresh = false,
  }) async {
    if (fullScreenLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (!_accessOk) {
        if (mounted && fullScreenLoader) setState(() => _loading = false);
        return;
      }

      if (_plantKey.isEmpty) {
        if (mounted) {
          setState(() {
            if (fullScreenLoader) _loading = false;
            _error = ApsGanttInfoCopy.missingPlantKeyMessage;
          });
        }
        return;
      }

      final fetched = await Future.wait([
        _cache.demands(
          service: _service,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
        _cache.scenarios(
          service: _service,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
        _cache.objectiveProfiles(
          service: _service,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
      ]);
      final demands = fetched[0] as List<ApsDemandView>;
      final scenarios = fetched[1] as List<ApsScenarioView>;
      final objectiveProfiles = fetched[2] as List<ApsObjectiveProfileView>;

      ApsScenarioView? selected = _selectedScenario;
      final pickId = selectScenarioId?.trim() ?? '';
      if (pickId.isNotEmpty) {
        for (final s in scenarios) {
          if (s.id == pickId) {
            selected = s;
            break;
          }
        }
      } else if (selected != null) {
        final prevId = selected.id;
        ApsScenarioView? matched;
        for (final s in scenarios) {
          if (s.id == prevId) {
            matched = s;
            break;
          }
        }
        selected = matched ?? (scenarios.isNotEmpty ? scenarios.first : null);
      } else if (scenarios.isNotEmpty) {
        selected = scenarios.first;
      }

      var items = const <ApsScenarioItemView>[];
      if (selected != null) {
        items = await _service.fetchScenarioItems(
          companyId: _companyId,
          plantKey: _plantKey,
          scenarioId: selected.id,
        );
        await _loadCapacityWarningsForSuggestion(selected);
      } else {
        _capacityWarningsForSuggestion = const [];
      }

      if (!mounted) return;
      setState(() {
        _demands = demands;
        _scenarios = scenarios;
        _objectiveProfiles = objectiveProfiles;
        _selectedScenario = selected;
        _scenarioItems = items;
        if (fullScreenLoader) _loading = false;
      });
    } on ApsP1WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        if (fullScreenLoader) _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (fullScreenLoader) _loading = false;
        _error = e.toString();
      });
    }
  }


  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApsP1WriteException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  String _uniqueCode(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  Map<String, ApsDemandView> get _demandsById {
    return {for (final d in _demands) d.id: d};
  }

  ApsOptimizationGoalSuggestion? _goalSuggestionFor(ApsScenarioView? scenario) {
    if (scenario == null) return null;
    return ApsOptimizationGoalCatalog.suggest(
      scenario: scenario,
      demands: _demands,
      scenarioItems: _scenarioItems,
      capacityWarnings: _capacityWarningsForSuggestion,
    );
  }

  Future<void> _loadCapacityWarningsForSuggestion(ApsScenarioView scenario) async {
    final snapshotId = scenario.lastSnapshotId?.trim() ?? '';
    if (snapshotId.isEmpty) {
      if (mounted) setState(() => _capacityWarningsForSuggestion = const []);
      return;
    }
    try {
      final warnings = await _service.fetchCapacityWarnings(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
        snapshotId: snapshotId,
      );
      if (!mounted) return;
      setState(() => _capacityWarningsForSuggestion = warnings);
    } on ApsP1WriteException {
      if (!mounted) return;
      setState(() => _capacityWarningsForSuggestion = const []);
    }
  }

  Future<void> _setOptimizationGoalKind(ApsOptimizationGoalKind kind) async {
    final scenario = _selectedScenario;
    if (scenario == null) return;
    final profileId = ApsOptimizationGoalCatalog.profileIdForKind(
      kind,
      _objectiveProfiles,
    );
    if (profileId == null || profileId.isEmpty) {
      _showError(ApsGanttInfoCopy.optimizationGoalMissingForCreate);
      return;
    }

    await _runBusy(() async {
      await _service.updateScenarioObjectiveProfile(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
        objectiveProfileId: profileId,
      );
      _showSuccess('Cilj optimizacije je postavljen.');
      await _loadAll(selectScenarioId: scenario.id, forceRefresh: true);
    });
  }

  Future<void> _acceptOptimizationGoalSuggestion() async {
    final suggestion = _goalSuggestionFor(_selectedScenario);
    if (suggestion == null) return;
    await _setOptimizationGoalKind(suggestion.kind);
    if (mounted) {
      setState(() => _dismissedSuggestionScenarioId = _selectedScenario?.id);
    }
  }

  void _dismissOptimizationGoalSuggestion() {
    setState(() => _dismissedSuggestionScenarioId = _selectedScenario?.id);
  }

  Future<void> _showCreateDemandDialog() async {
    final input = await showDialog<_CreateDemandInput>(
      context: context,
      builder: (ctx) => const _CreateDemandDialog(),
    );

    if (input == null || !mounted) return;

    if (input.quantity <= 0) {
      _showError('Količina mora biti veća od nule.');
      return;
    }

    await _runBusy(() async {
      await _service.createDemand(
        companyId: _companyId,
        plantKey: _plantKey,
        demandCode: _uniqueCode('DEM'),
        demandName: input.demandName,
        quantity: input.quantity,
        dueDate: input.dueDate,
        estimatedMinutesPerUnit: input.estimatedMinutesPerUnit,
      );
      _showSuccess('Potražnja je kreirana.');
      await _loadAll(forceRefresh: true);
    });
  }

  Future<void> _showCreateScenarioDialog() async {
    if (_objectiveProfiles.isEmpty) {
      _showError(ApsGanttInfoCopy.optimizationGoalMissingForCreate);
      return;
    }

    final input = await showDialog<_CreateScenarioInput>(
      context: context,
      builder: (ctx) => _CreateScenarioDialog(profiles: _objectiveProfiles),
    );

    if (input == null || !mounted) return;

    if (!input.periodEnd.isAfter(input.periodStart)) {
      _showError('Kraj perioda mora biti nakon početka.');
      return;
    }

    await _runBusy(() async {
      final id = await _service.createScenario(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioCode: _uniqueCode('SC'),
        scenarioName: input.scenarioName,
        periodStart: input.periodStart,
        periodEnd: input.periodEnd,
        objectiveProfileId: input.objectiveProfileId,
      );
      _showSuccess('Scenarij je kreiran.');
      await _loadAll(selectScenarioId: id, forceRefresh: true);
    });
  }

  Future<void> _onScenarioChanged(ApsScenarioView? scenario) async {
    setState(() {
      _selectedScenario = scenario;
      _scenarioItems = const [];
      _dismissedSuggestionScenarioId = null;
      _capacityWarningsForSuggestion = const [];
      _loadingScenarioItems = scenario != null;
    });
    if (scenario == null) return;
    try {
      final items = await _service.fetchScenarioItems(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      if (!mounted) return;
      setState(() {
        _scenarioItems = items;
        _loadingScenarioItems = false;
      });
      await _loadCapacityWarningsForSuggestion(scenario);
    } on ApsP1WriteException catch (e) {
      if (!mounted) return;
      setState(() => _loadingScenarioItems = false);
      _showError(e.message);
    }
  }

  Future<void> _showAddDemandToScenarioDialog() async {
    final scenario = _selectedScenario;
    if (scenario == null) return;
    if (!_scenarioIsDraft) {
      _showError(ApsGanttInfoCopy.scenarioDraftCompositionHint);
      return;
    }

    final linked = _scenarioItems.map((i) => i.demandId).toSet();
    final available =
        _demands.where((d) => d.isActive && !linked.contains(d.id)).toList();
    if (available.isEmpty) {
      _showError('Nema dostupnih potražnji za dodavanje.');
      return;
    }

    ApsDemandView? picked = available.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Dodaj potražnju u scenarij'),
              content: DropdownButtonFormField<ApsDemandView>(
                isExpanded: true,
                value: picked,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Potražnja',
                ),
                items: available
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.displayLabel, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => picked = v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: picked == null ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || picked == null || !mounted) return;

    await _runBusy(() async {
      await _service.addDemandToScenario(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
        demandId: picked!.id,
      );
      _showSuccess('Potražnja je dodana u scenarij.');
      await _loadAll(selectScenarioId: scenario.id, forceRefresh: true);
    });
  }

  Future<void> _removeDemandFromScenario(ApsScenarioItemView item) async {
    final scenario = _selectedScenario;
    if (scenario == null || !_scenarioIsDraft) return;

    final demand = _demandsById[item.demandId];
    final label = demand?.displayLabel ?? item.demandId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni potražnju'),
        content: Text('Ukloniti „$label” iz scenarija „${scenario.displayLabel}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await _runBusy(() async {
      await _service.removeDemandFromScenario(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
        demandId: item.demandId,
      );
      _showSuccess('Potražnja je uklonjena iz scenarija.');
      await _loadAll(selectScenarioId: scenario.id, forceRefresh: true);
    });
  }

  Future<void> _generateSchedule() async {
    final scenario = _selectedScenario;
    if (scenario == null) return;
    if (_scenarioItems.isEmpty) {
      _showError('Scenarij nema potražnji — dodajte potražnje prije generiranja.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generiši početni raspored'),
        content: const Text(ApsGanttInfoCopy.generateScheduleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generiši'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await _runBusy(() async {
      final result = await _service.generateHeuristicSchedule(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      final status =
          ApsGanttInfoCopy.scenarioStatusLabel(result.scenarioStatus);
      _showSuccess(
        'Početni raspored generiran — ${result.operationCount} operacija. Status: $status.',
      );
      await _loadAll(selectScenarioId: scenario.id, forceRefresh: true);
    });
  }

  void _openGantt() {
    final scenario = _selectedScenario;
    if (scenario == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApsGanttReadOnlyScreen(
          companyData: _companyData,
          initialScenarioId: scenario.id,
        ),
      ),
    );
  }

  void _onAppBarAdd() {
    if (_tabController.index == 0) {
      _showCreateScenarioDialog();
    } else {
      _showCreateDemandDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(ApsGanttInfoCopy.scenariosDemandsScreenTitle),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Scenariji'),
              Tab(text: 'Potrebe'),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_accessOk) {
      return Scaffold(
        appBar: AppBar(title: const Text(ApsGanttInfoCopy.scenariosDemandsScreenTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nema pristupa. Potrebna pretplata Napredno planiranje i '
              'Scenariji planiranja te uloga menadžera proizvodnje, administratora '
              'ili super administratora.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(ApsGanttInfoCopy.scenariosDemandsScreenTitle),
        actions: [
          IconButton(
            tooltip: _tabController.index == 0 ? 'Novi scenarij' : 'Nova potražnja',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _onAppBarAdd,
          ),
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _busy
                ? null
                : () => _loadAll(
                    selectScenarioId: _selectedScenario?.id,
                    forceRefresh: true,
                  ),
          ),
          IconButton(
            tooltip: 'Informacije',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: ApsGanttInfoCopy.scenariosDemandsScreenTitle,
              body: ApsGanttInfoCopy.hubScenariosDemandsCardInfoBody,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scenariji'),
            Tab(text: 'Potrebe'),
          ],
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScenariosTab(),
                _buildDemandsTab(),
              ],
            ),
    );
  }

  Widget _buildScenariosTab() {
    final scenario = _selectedScenario;
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadAll(
            selectScenarioId: scenario?.id,
            forceRefresh: true,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                ApsGanttInfoCopy.scenariosDemandsIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ApsScenarioPicker(
                scenarios: _scenarios,
                selected: scenario,
                onChanged: _busy ? (_) {} : _onScenarioChanged,
              ),
              if (scenario != null) ...[
                const SizedBox(height: 12),
                _StatusChip(status: scenario.status),
                const SizedBox(height: 8),
                ApsOptimizationGoalSection(
                  profiles: _objectiveProfiles,
                  objectiveProfileId: scenario.objectiveProfileId,
                  suggestion: _goalSuggestionFor(scenario),
                  suggestionDismissed:
                      _dismissedSuggestionScenarioId == scenario.id,
                  busy: _busy,
                  onKindSelected: _setOptimizationGoalKind,
                  onAcceptSuggestion: _acceptOptimizationGoalSuggestion,
                  onDismissSuggestion: _dismissOptimizationGoalSuggestion,
                ),
                if (!_scenarioIsDraft) ...[
                  const SizedBox(height: 8),
                  Text(
                    ApsGanttInfoCopy.scenarioDraftCompositionHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Potražnje u scenariju (${_scenarioItems.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_loadingScenarioItems)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_scenarioItems.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Scenarij još nema povezanih potražnji. '
                        'Dodajte potražnje prije generiranja rasporeda.',
                      ),
                    ),
                  )
                else
                  ..._scenarioItems.map((item) {
                    final demand = _demandsById[item.demandId];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          demand?.displayLabel ?? item.demandId,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: demand != null
                            ? Text(demand.subtitleLabel)
                            : null,
                        trailing: _scenarioIsDraft && !_busy
                            ? IconButton(
                                tooltip: 'Ukloni',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeDemandFromScenario(item),
                              )
                            : null,
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_scenarioIsDraft)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _showAddDemandToScenarioDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Dodaj potražnju'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: _busy || _scenarioItems.isEmpty
                          ? null
                          : _generateSchedule,
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Generiši početni raspored'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _openGantt,
                      icon: const Icon(Icons.view_timeline_outlined),
                      label: const Text(ApsGanttInfoCopy.openScheduleButtonLabel),
                    ),
                  ],
                ),
              ] else if (_scenarios.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nema scenarija. Kreirajte prvi scenarij planiranja.',
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_busy)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }

  Widget _buildDemandsTab() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadAll(forceRefresh: true),
          child: _demands.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Text(
                      'Nema potražnji. Kreirajte prvu planiranu potražnju.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _demands.length,
                  itemBuilder: (context, index) {
                    final d = _demands[index];
                    final due = d.dueDate;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(d.displayLabel, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            d.subtitleLabel,
                            if (due != null) 'Rok: ${_dateFmt.format(due)}',
                            if (d.estimatedMinutesPerUnit != null)
                              '${d.estimatedMinutesPerUnit} min/jed.',
                          ].join(' · '),
                        ),
                        trailing: Chip(
                          label: Text(
                            d.status.isEmpty ? '—' : d.status,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_busy)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}

class _CreateDemandInput {
  const _CreateDemandInput({
    required this.demandName,
    required this.quantity,
    required this.dueDate,
    this.estimatedMinutesPerUnit,
  });

  final String demandName;
  final num quantity;
  final DateTime dueDate;
  final num? estimatedMinutesPerUnit;
}

class _CreateScenarioInput {
  const _CreateScenarioInput({
    required this.scenarioName,
    required this.periodStart,
    required this.periodEnd,
    required this.objectiveProfileId,
  });

  final String scenarioName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String objectiveProfileId;
}

class _CreateDemandDialog extends StatefulWidget {
  const _CreateDemandDialog();

  @override
  State<_CreateDemandDialog> createState() => _CreateDemandDialogState();
}

class _CreateDemandDialogState extends State<_CreateDemandDialog> {
  static final _dateFmt = DateFormat('d.M.yyyy.');

  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minutesCtrl;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _qtyCtrl = TextEditingController(text: '100');
    _minutesCtrl = TextEditingController(text: '5');
    _dueDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _CreateDemandInput(
        demandName: _nameCtrl.text.trim(),
        quantity: num.tryParse(_qtyCtrl.text.trim()) ?? 0,
        dueDate: _dueDate,
        estimatedMinutesPerUnit: num.tryParse(_minutesCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova potražnja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv potražnje',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Količina',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minutesCtrl,
              decoration: const InputDecoration(
                labelText: 'Procijenjene minute po jedinici',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rok potrebe'),
              subtitle: Text(_dateFmt.format(_dueDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kreiraj'),
        ),
      ],
    );
  }
}

class _CreateScenarioDialog extends StatefulWidget {
  const _CreateScenarioDialog({required this.profiles});

  final List<ApsObjectiveProfileView> profiles;

  @override
  State<_CreateScenarioDialog> createState() => _CreateScenarioDialogState();
}

class _CreateScenarioDialogState extends State<_CreateScenarioDialog> {
  static final _dateFmt = DateFormat('d.M.yyyy.');

  late final TextEditingController _nameCtrl;
  late DateTime _periodStart;
  late DateTime _periodEnd;
  ApsOptimizationGoalKind? _goalKind;

  List<ApsOptimizationGoalKind> get _availableKinds =>
      ApsOptimizationGoalCatalog.allKinds
          .where(
            (k) => ApsOptimizationGoalCatalog.profileForKind(k, widget.profiles) != null,
          )
          .toList();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 0);
    final kinds = _availableKinds;
    _goalKind = kinds.contains(ApsOptimizationGoalKind.balanced)
        ? ApsOptimizationGoalKind.balanced
        : (kinds.isNotEmpty ? kinds.first : null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (!_periodEnd.isAfter(_periodStart)) return;
    final kind = _goalKind;
    if (kind == null) return;
    final profileId = ApsOptimizationGoalCatalog.profileIdForKind(
      kind,
      widget.profiles,
    );
    if (profileId == null || profileId.isEmpty) return;
    Navigator.pop(
      context,
      _CreateScenarioInput(
        scenarioName: _nameCtrl.text.trim(),
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        objectiveProfileId: profileId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novi scenarij'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv scenarija',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ApsOptimizationGoalKind>(
              isExpanded: true,
              value: _goalKind,
              decoration: InputDecoration(
                labelText: ApsGanttInfoCopy.optimizationGoalLabel,
                border: const OutlineInputBorder(),
              ),
              items: _availableKinds
                  .map(
                    (k) => DropdownMenuItem(
                      value: k,
                      child: Text(ApsOptimizationGoalCatalog.label(k)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _goalKind = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Početak perioda'),
              subtitle: Text(_dateFmt.format(_periodStart)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _periodStart,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _periodStart = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kraj perioda'),
              subtitle: Text(_dateFmt.format(_periodEnd)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _periodEnd,
                  firstDate: _periodStart,
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _periodEnd = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _goalKind == null ? null : _submit,
          child: const Text('Kreiraj'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = ApsGanttInfoCopy.scenarioStatusLabel(status);
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(Icons.flag_outlined, size: 18, color: cs.primary),
        label: Text('Status: $label'),
      ),
    );
  }
}
