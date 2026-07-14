import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/saas/production_module_keys.dart';
import '../helpers/aps_execution_watch_explain_copy.dart';
import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_optimization_goal.dart';
import '../helpers/aps_session_context.dart';
import '../models/aps_objective_profile_view.dart';
import '../models/aps_optimization_run_view.dart';
import '../models/aps_scenario_view.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_optimization_service.dart';
import '../services/aps_p1_write_service.dart';
import '../widgets/aps_info_icon_button.dart';
import '../widgets/aps_optimization_comparison_view.dart';
import '../widgets/aps_optimization_run_view.dart';
import '../widgets/aps_scenario_picker.dart';
import 'aps_gantt_read_only_screen.dart';

/// Operativni P5.3 ekran — prijedlozi optimizacije (Callable P5.1 stub).
class ApsOptimizationScreen extends StatefulWidget {
  const ApsOptimizationScreen({
    super.key,
    required this.companyData,
    this.initialScenarioId,
    this.sourceAlertId,
    this.sourceAlertHeadline,
    this.sourceAlertType,
  });

  final Map<String, dynamic> companyData;
  final String? initialScenarioId;
  final String? sourceAlertId;
  final String? sourceAlertHeadline;
  final String? sourceAlertType;

  @override
  State<ApsOptimizationScreen> createState() => _ApsOptimizationScreenState();
}

class _ApsOptimizationScreenState extends State<ApsOptimizationScreen> {
  final ApsP1WriteService _p1 = ApsP1WriteService();
  final ApsOptimizationService _p5 = ApsOptimizationService();
  final ApsOperationalCache _cache = ApsOperationalCache.instance;
  static final _dateTimeFmt = DateFormat('d.M.yyyy. HH:mm');

  late final ApsSessionContext _session;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ApsScenarioView> _scenarios = const [];
  List<ApsObjectiveProfileView> _objectiveProfiles = const [];
  List<ApsOptimizationRunView> _runs = const [];

  ApsScenarioView? _selectedScenario;
  ApsOptimizationRunView? _selectedRun;
  bool _executionWatchContextBannerVisible = true;

  Map<String, dynamic> get _companyData => widget.companyData;

  String get _companyId => _session.companyId;
  String get _plantKey => _session.plantKey;

  bool get _accessOk => _session.accessOk;

  bool get _hasOptimizationModule => ProductionModuleKeys.hasModule(
    _companyData,
    ProductionModuleKeys.apsOptimization,
  );

  bool get _scenarioEligible =>
      _selectedScenario?.isEligibleForOptimization ?? false;

  bool get _hasExecutionWatchContext =>
      (widget.sourceAlertId?.trim().isNotEmpty ?? false) &&
      _executionWatchContextBannerVisible;

  String? get _executionWatchContextHeadline {
    final headline = widget.sourceAlertHeadline?.trim() ?? '';
    return headline.isNotEmpty ? headline : null;
  }

  String? get _objectiveProfileLabel {
    final scenario = _selectedScenario;
    if (scenario == null || !scenario.hasOptimizationGoal) return null;
    final label = ApsOptimizationGoalCatalog.labelForProfileId(
      scenario.objectiveProfileId,
      _objectiveProfiles,
    );
    return label.isNotEmpty ? label : null;
  }

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(_companyData);
    _loadInitial(selectScenarioId: widget.initialScenarioId);
  }

  Future<void> _loadInitial({
    String? selectScenarioId,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!_accessOk) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (_plantKey.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = ApsGanttInfoCopy.missingPlantKeyMessage;
          });
        }
        return;
      }

      final fetched = await Future.wait([
        _cache.scenarios(
          service: _p1,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
        _cache.objectiveProfiles(
          service: _p1,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
      ]);
      final scenarios = fetched[0] as List<ApsScenarioView>;
      final profiles = fetched[1] as List<ApsObjectiveProfileView>;

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

      if (!mounted) return;
      setState(() {
        _scenarios = scenarios;
        _objectiveProfiles = profiles;
        _selectedScenario = selected;
        _selectedRun = null;
        _runs = const [];
        _loading = false;
      });

      if (selected != null) {
        await _loadRunsForScenario(selected);
      }
    } on ApsP1WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadRunsForScenario(ApsScenarioView scenario) async {
    try {
      final runs = await _p5.listOptimizationRuns(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      ApsOptimizationRunView? selected = _selectedRun;
      if (selected != null) {
        ApsOptimizationRunView? matched;
        for (final r in runs) {
          if (r.id == selected.id) {
            matched = r;
            break;
          }
        }
        selected = matched ?? (runs.isNotEmpty ? runs.first : null);
      } else if (runs.isNotEmpty) {
        selected = runs.first;
      }

      if (!mounted) return;
      setState(() {
        _runs = runs;
        _selectedRun = selected;
      });
    } on ApsOptimizationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _onScenarioChanged(ApsScenarioView? scenario) async {
    setState(() {
      _selectedScenario = scenario;
      _selectedRun = null;
      _runs = const [];
      _error = null;
    });
    if (scenario != null) {
      await _loadRunsForScenario(scenario);
    }
  }

  Future<void> _startOptimization() async {
    final scenario = _selectedScenario;
    if (scenario == null || !_scenarioEligible || !_hasOptimizationModule) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _p5.startOptimizationRun(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      _showSuccess('Prijedlog optimizacije je spreman za pregled.');
      await _loadRunsForScenario(scenario);
      if (result.optimizationRunId.isNotEmpty && mounted) {
        ApsOptimizationRunView? started;
        for (final r in _runs) {
          if (r.id == result.optimizationRunId) {
            started = r;
            break;
          }
        }
        started ??= ApsOptimizationRunView(
          id: result.optimizationRunId,
          scenarioId: scenario.id,
          status: result.status.isNotEmpty ? result.status : 'completed',
          baselineScheduleRunId: result.baselineScheduleRunId,
          candidateScheduleRunId: result.candidateScheduleRunId,
          comparison: result.comparison,
        );
        setState(() => _selectedRun = started);
      }
      _cache.invalidateTenant(companyId: _companyId, plantKey: _plantKey);
    } on ApsOptimizationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applySelectedRun() async {
    final run = _selectedRun;
    if (run == null || !run.canApply) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(ApsGanttInfoCopy.optimizationApplyAction)),
            ApsInfoIconButton(
              tooltip: 'O primjeni prijedloga',
              title: ApsGanttInfoCopy.optimizationApplyAction,
              body: ApsGanttInfoCopy.optimizationApplyConfirmBody,
              size: 18,
            ),
          ],
        ),
        content: Text(ApsGanttInfoCopy.optimizationApplyConfirmBody),
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
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _p5.applyOptimizationResult(
        companyId: _companyId,
        plantKey: _plantKey,
        optimizationRunId: run.id,
      );
      final statusLabel =
          ApsGanttInfoCopy.scenarioStatusLabel(result.scenarioStatus);
      _showSuccess(
        '${ApsGanttInfoCopy.optimizationApplySuccessPrefix} $statusLabel.',
      );
      final scenarioId = _selectedScenario?.id ?? result.scenarioId;
      await _loadInitial(
        selectScenarioId: scenarioId,
        forceRefresh: true,
      );
    } on ApsOptimizationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardSelectedRun() async {
    final run = _selectedRun;
    if (run == null || !run.canDiscard) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ApsGanttInfoCopy.optimizationDiscardAction),
        content: Text(ApsGanttInfoCopy.optimizationDiscardConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odbaci'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _p5.discardOptimizationRun(
        companyId: _companyId,
        plantKey: _plantKey,
        optimizationRunId: run.id,
      );
      _showSuccess(ApsGanttInfoCopy.optimizationDiscardSuccessPrefix);
      final scenarioId = _selectedScenario?.id;
      await _loadInitial(
        selectScenarioId: scenarioId,
        forceRefresh: true,
      );
    } on ApsOptimizationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSchedule() {
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessOk) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(ApsGanttInfoCopy.optimizationScreenTitle),
        ),
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

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedRun = _selectedRun;
    final comparison = selectedRun?.comparison;

    return Scaffold(
      appBar: AppBar(
        title: const Text(ApsGanttInfoCopy.optimizationScreenTitle),
        actions: [
          IconButton(
            tooltip: 'Informacije',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: ApsGanttInfoCopy.optimizationScreenTitle,
              body: ApsGanttInfoCopy.hubOptimizationCardInfoBody,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadInitial(
                selectScenarioId: _selectedScenario?.id,
                forceRefresh: true,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_hasExecutionWatchContext) ...[
                    _ExecutionWatchOptimizationContextBanner(
                      headline: _executionWatchContextHeadline,
                      onDismiss: () => setState(
                        () => _executionWatchContextBannerVisible = false,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    ApsGanttInfoCopy.optimizationOperationalIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (!_hasOptimizationModule) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: cs.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ApsGanttInfoCopy.optimizationModuleHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: cs.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ApsScenarioPicker(
                    scenarios: _scenarios,
                    selected: _selectedScenario,
                    loading: _busy,
                    onChanged: _onScenarioChanged,
                  ),
                  const SizedBox(height: 12),
                  _ObjectiveGoalCard(label: _objectiveProfileLabel),
                  if (_selectedScenario != null && !_scenarioEligible) ...[
                    const SizedBox(height: 8),
                    Text(
                      ApsGanttInfoCopy.optimizationScenarioNotEligibleHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ||
                                  !_hasOptimizationModule ||
                                  !_scenarioEligible
                              ? null
                              : _startOptimization,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow_outlined),
                          label: const Text(
                            ApsGanttInfoCopy.optimizationStartRunAction,
                          ),
                        ),
                      ),
                      ApsInfoIconButton(
                        tooltip: 'O pokretanju prijedloga',
                        title: ApsGanttInfoCopy.optimizationStartRunAction,
                        body: ApsGanttInfoCopy.optimizationStartRunInfoBody,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    ApsGanttInfoCopy.optimizationRunListTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_runs.isEmpty)
                    Text(
                      ApsGanttInfoCopy.optimizationNoRunsHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._runs.map((run) => _RunListTile(
                          run: run,
                          selected: selectedRun?.id == run.id,
                          dateFmt: _dateTimeFmt,
                          onTap: () => setState(() => _selectedRun = run),
                        )),
                  if (selectedRun != null) ...[
                    const SizedBox(height: 16),
                    ApsOptimizationRunDetailView(
                      run: selectedRun,
                      objectiveProfileLabel: _objectiveProfileLabel,
                    ),
                  ],
                  if (comparison != null) ...[
                    const SizedBox(height: 12),
                    ApsOptimizationComparisonView(comparison: comparison),
                  ],
                  if (selectedRun != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (selectedRun.canDiscard)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _discardSelectedRun,
                            icon: const Icon(Icons.close),
                            label: const Text(
                              ApsGanttInfoCopy.optimizationDiscardAction,
                            ),
                          ),
                        if (selectedRun.canApply)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: _busy ? null : _applySelectedRun,
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  ApsGanttInfoCopy.optimizationApplyAction,
                                ),
                              ),
                              ApsInfoIconButton(
                                tooltip: 'O primjeni prijedloga',
                                title: ApsGanttInfoCopy.optimizationApplyAction,
                                body: ApsGanttInfoCopy.optimizationApplyInfoBody,
                              ),
                            ],
                          ),
                        OutlinedButton.icon(
                          onPressed: _selectedScenario == null || _busy
                              ? null
                              : _openSchedule,
                          icon: const Icon(Icons.view_timeline_outlined),
                          label: const Text(
                            ApsGanttInfoCopy.openScheduleButtonLabel,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_selectedScenario != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _openSchedule,
                      icon: const Icon(Icons.view_timeline_outlined),
                      label: const Text(
                        ApsGanttInfoCopy.openScheduleButtonLabel,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _ObjectiveGoalCard extends StatelessWidget {
  const _ObjectiveGoalCard({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:             Row(
              children: [
                Icon(Icons.flag_outlined, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ApsGanttInfoCopy.optimizationGoalLabel,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          ApsInfoIconButton(
                            tooltip: 'O cilju optimizacije',
                            title: ApsGanttInfoCopy.optimizationGoalLabel,
                            body: ApsOptimizationGoalCatalog.generalInfoBody,
                            size: 18,
                          ),
                        ],
                      ),
                  const SizedBox(height: 4),
                  Text(
                    hasLabel
                        ? label!
                        : ApsGanttInfoCopy.optimizationGoalMissingHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasLabel ? null : cs.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P6.3 — kontekst upozorenja pri navigaciji iz Operonix AI APS Asistenta.
class _ExecutionWatchOptimizationContextBanner extends StatelessWidget {
  const _ExecutionWatchOptimizationContextBanner({
    required this.headline,
    required this.onDismiss,
  });

  final String? headline;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology_outlined, size: 22, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ApsExecutionWatchExplainCopy.optimizationContextBannerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (headline != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${ApsExecutionWatchExplainCopy.optimizationContextBannerReasonPrefix} '
                      '$headline',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    ApsExecutionWatchExplainCopy
                        .optimizationContextBannerFootnote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sakrij',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunListTile extends StatelessWidget {
  const _RunListTile({
    required this.run,
    required this.selected,
    required this.dateFmt,
    required this.onTap,
  });

  final ApsOptimizationRunView run;
  final bool selected;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = run.startedAt != null
        ? dateFmt.format(run.startedAt!)
        : run.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        selected: selected,
        title: Text(when, style: theme.textTheme.bodyMedium),
        subtitle: Text(run.statusLabel),
        trailing: run.comparison?.isImprovement == true
            ? Icon(Icons.trending_down, color: theme.colorScheme.primary, size: 20)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
