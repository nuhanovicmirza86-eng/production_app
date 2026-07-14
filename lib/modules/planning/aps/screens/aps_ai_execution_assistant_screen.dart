import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../helpers/aps_execution_watch_outcomes.dart';
import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_session_context.dart';
import '../models/aps_execution_watch_ai_explanation_view.dart';
import '../models/aps_execution_watch_alert_view.dart';
import '../models/aps_scenario_view.dart';
import '../services/aps_execution_watch_service.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_p1_write_service.dart';
import '../widgets/aps_execution_watch_explanation_section.dart';
import '../widgets/aps_execution_watch_resolve_dialog.dart';
import '../widgets/aps_info_icon_button.dart';
import '../widgets/aps_scenario_picker.dart';
import 'aps_gantt_read_only_screen.dart';
import 'aps_optimization_screen.dart';

/// Operativni P6.1 ekran — Operonix AI APS Asistent (nadzor rizika + prilika).
class ApsAiExecutionAssistantScreen extends StatefulWidget {
  const ApsAiExecutionAssistantScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ApsAiExecutionAssistantScreen> createState() =>
      _ApsAiExecutionAssistantScreenState();
}

class _ApsAiExecutionAssistantScreenState
    extends State<ApsAiExecutionAssistantScreen> {
  final ApsP1WriteService _p1 = ApsP1WriteService();
  final ApsExecutionWatchService _p6 = ApsExecutionWatchService();
  final ApsOperationalCache _cache = ApsOperationalCache.instance;

  late final ApsSessionContext _session;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ApsScenarioView> _scenarios = const [];
  ApsScenarioView? _selectedScenario;
  List<ApsExecutionWatchAlertView> _activeAlerts = const [];
  List<ApsExecutionWatchAlertView> _closedAlerts = const [];
  int _openCount = 0;
  int _criticalCount = 0;
  String? _lastEvaluatedAt;
  int _tabIndex = 0;
  final Map<String, ApsExecutionWatchAiExplanationView> _explanations = {};
  String? _explainingAlertId;

  Map<String, dynamic> get _companyData => widget.companyData;

  String get _companyId => _session.companyId;
  String get _plantKey => _session.plantKey;

  bool get _accessOk => ProductionAccessHelper.canAccessApsP6Callable(
    role: _session.role,
    companyData: _companyData,
  );

  bool get _hasAiModule => ProductionModuleKeys.hasApsAiAssistantModule(
    _companyData,
  );

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(_companyData);
    _loadInitial();
  }

  Future<void> _loadInitial({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!_accessOk || !_hasAiModule) {
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

      final scenarios = await _cache.scenarios(
        service: _p1,
        companyId: _companyId,
        plantKey: _plantKey,
        forceRefresh: forceRefresh,
      );

      ApsScenarioView? selected = _selectedScenario;
      if (selected != null) {
        ApsScenarioView? matched;
        for (final s in scenarios) {
          if (s.id == selected.id) {
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
        _selectedScenario = selected;
        _loading = false;
      });

      await _refreshAlerts(evaluateFirst: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshAlerts({bool evaluateFirst = false}) async {
    if (!_accessOk || _plantKey.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (evaluateFirst) {
        final eval = await _p6.evaluate(
          companyId: _companyId,
          plantKey: _plantKey,
          scenarioId: _selectedScenario?.id,
        );
        _lastEvaluatedAt = eval.evaluatedAt;
      }

      final active = await _p6.listAlerts(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: _selectedScenario?.id,
        status: 'open',
      );
      final closed = await _p6.listAlerts(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: _selectedScenario?.id,
        status: 'all',
        limit: 100,
      );
      final closedFiltered = closed.alerts
          .where((a) => a.status == 'resolved' || a.status == 'dismissed')
          .toList();

      if (!mounted) return;
      setState(() {
        _activeAlerts = active.alerts;
        _closedAlerts = closedFiltered;
        _openCount = active.openCount;
        _criticalCount = active.criticalCount;
        _busy = false;
      });
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markInProgress(ApsExecutionWatchAlertView alert) async {
    setState(() => _busy = true);
    try {
      await _p6.resolveAlert(
        companyId: _companyId,
        plantKey: _plantKey,
        alertId: alert.alertId,
        resolution: 'in_progress',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Označeno kao u toku rješavanja.')),
      );
      await _refreshAlerts();
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _confirmResolve(ApsExecutionWatchAlertView alert) async {
    final result = await showApsExecutionWatchResolveDialog(
      context: context,
      alert: alert,
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _p6.resolveAlert(
        companyId: _companyId,
        plantKey: _plantKey,
        alertId: alert.alertId,
        resolution: 'resolved',
        businessOutcome: result.businessOutcome,
        resolutionOutcome: 'helped',
        resolutionNote: result.resolutionNote,
        recommendationAccepted: result.recommendationAccepted,
        valueMetrics: result.valueMetricsPatch(),
      );
      if (!mounted) return;
      final outcomeLabel = ApsExecutionWatchOutcomes.labelForBusinessOutcome(
        result.businessOutcome,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ishod zabilježen: $outcomeLabel')),
      );
      setState(() => _tabIndex = 1);
      await _refreshAlerts();
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _explainAlert(
    ApsExecutionWatchAlertView alert, {
    bool forceRefresh = false,
  }) async {
    setState(() => _explainingAlertId = alert.alertId);
    try {
      final explanation = await _p6.explainAlert(
        companyId: _companyId,
        plantKey: _plantKey,
        alertId: alert.alertId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _explanations[alert.alertId] = explanation;
        _explainingAlertId = null;
      });
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      setState(() => _explainingAlertId = null);
      final msg = e.message.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isNotEmpty && msg.toLowerCase() != 'internal'
                ? msg
                : 'AI objašnjenje trenutno nije dostupno. Pokušaj kasnije.',
          ),
        ),
      );
    }
  }

  ApsExecutionWatchAiExplanationView? _explanationFor(
    ApsExecutionWatchAlertView alert,
  ) {
    final exp = _explanations[alert.alertId] ?? alert.aiExplanation;
    if (exp != null && !exp.isFreshForDisplay) return null;
    return exp;
  }

  Future<void> _dismissAlert(ApsExecutionWatchAlertView alert) async {
    setState(() => _busy = true);
    try {
      await _p6.resolveAlert(
        companyId: _companyId,
        plantKey: _plantKey,
        alertId: alert.alertId,
        resolution: 'dismissed',
        businessOutcome: 'no_impact',
        resolutionOutcome: 'not_helped',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upozorenje odbačeno.')),
      );
      await _refreshAlerts();
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _openSchedule(ApsExecutionWatchAlertView alert) {
    final scenarioId =
        alert.scenarioId ?? _selectedScenario?.id ?? '';
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApsGanttReadOnlyScreen(
          companyData: _companyData,
          initialScenarioId: scenarioId.isNotEmpty ? scenarioId : null,
        ),
      ),
    );
  }

  void _openOptimization(ApsExecutionWatchAlertView alert) async {
    final scenarioId =
        alert.scenarioId ?? _selectedScenario?.id ?? '';
    try {
      await _p6.recordAlertNavigation(
        companyId: _companyId,
        plantKey: _plantKey,
        alertId: alert.alertId,
        navigationTarget: 'aps_optimization',
        targetScreen: 'optimization',
        scenarioId: scenarioId.isNotEmpty ? scenarioId : null,
      );
    } on ApsExecutionWatchException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApsOptimizationScreen(
          companyData: _companyData,
          initialScenarioId: scenarioId.isNotEmpty ? scenarioId : null,
          sourceAlertId: alert.alertId,
          sourceAlertHeadline: alert.headline,
          sourceAlertType: alert.alertType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_accessOk || !_hasAiModule) {
      return Scaffold(
        appBar: AppBar(
          title: Text(ApsGanttInfoCopy.aiApsAssistantModuleName),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nema pristupa. Potrebna pretplata Operonix AI APS Asistent '
              '(aps_ai_assistant) i uloga menadžera proizvodnje, administratora '
              'ili super administratora.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(ApsGanttInfoCopy.aiApsAssistantModuleName),
        actions: [
          IconButton(
            tooltip: 'Osvježi nadzor',
            onPressed: _busy ? null : () => _refreshAlerts(evaluateFirst: true),
            icon: const Icon(Icons.refresh),
          ),
          ApsInfoIconButton(
            tooltip: 'O modulu ${ApsGanttInfoCopy.aiApsAssistantModuleName}',
            title: ApsGanttInfoCopy.aiApsAssistantModuleName,
            body: ApsGanttInfoCopy.hubAiCardInfoBody,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshAlerts(evaluateFirst: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    ApsGanttInfoCopy.aiApsAssistantDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_scenarios.isNotEmpty)
                    ApsScenarioPicker(
                      scenarios: _scenarios,
                      selected: _selectedScenario,
                      onChanged: (s) async {
                        setState(() => _selectedScenario = s);
                        await _refreshAlerts(evaluateFirst: true);
                      },
                    ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    openCount: _openCount,
                    criticalCount: _criticalCount,
                    lastEvaluatedAt: _lastEvaluatedAt,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Aktivna')),
                      ButtonSegment(value: 1, label: Text('Zatvorena')),
                    ],
                    selected: {_tabIndex},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() => _tabIndex = s.first),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    if (_tabIndex == 0 && _activeAlerts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Nema aktivnih upozorenja ni prilika za odabrani kontekst.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    else if (_tabIndex == 1 && _closedAlerts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Nema zatvorenih upozorenja s zabilježenim ishodom.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    else
                      ...(_tabIndex == 0 ? _activeAlerts : _closedAlerts).map(
                        (a) => _AlertCard(
                          alert: a,
                          busy: _busy,
                          showActions: _tabIndex == 0,
                          explanation: _explanationFor(a),
                          explanationLoading: _explainingAlertId == a.alertId,
                          onRequestExplanation: _tabIndex == 0
                              ? () => _explainAlert(
                                    a,
                                    forceRefresh:
                                        _explanationFor(a) != null,
                                  )
                              : null,
                          onViewSchedule: () => _openSchedule(a),
                          onGoOptimization: () => _openOptimization(a),
                          onInProgress: a.status == 'open'
                              ? () => _markInProgress(a)
                              : null,
                          onResolve: () => _confirmResolve(a),
                          onDismiss: () => _dismissAlert(a),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.openCount,
    required this.criticalCount,
    this.lastEvaluatedAt,
  });

  final int openCount;
  final int criticalCount;
  final String? lastEvaluatedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivno: $openCount · Kritično: $criticalCount',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (lastEvaluatedAt != null && lastEvaluatedAt!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Zadnja procjena: $lastEvaluatedAt',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.busy,
    required this.showActions,
    required this.onViewSchedule,
    required this.onGoOptimization,
    required this.onResolve,
    required this.onDismiss,
    this.onInProgress,
    this.explanation,
    this.explanationLoading = false,
    this.onRequestExplanation,
  });

  final ApsExecutionWatchAlertView alert;
  final bool busy;
  final bool showActions;
  final VoidCallback onViewSchedule;
  final VoidCallback onGoOptimization;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  final VoidCallback? onInProgress;
  final ApsExecutionWatchAiExplanationView? explanation;
  final bool explanationLoading;
  final VoidCallback? onRequestExplanation;

  Color _severityColor(ColorScheme cs) {
    switch (alert.severity) {
      case 'critical':
        return cs.error;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.amber.shade800;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _severityColor(cs);
    final kindLabel = alert.isOpportunity ? 'Prilika' : 'Upozorenje';
    final kindIcon = alert.isOpportunity
        ? Icons.trending_up_outlined
        : Icons.warning_amber_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kindIcon, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          kindLabel,
                          alert.severity.toUpperCase(),
                          if (alert.status == 'in_progress')
                            'U TOKU RJEŠAVANJA',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.headline,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (alert.scenarioDisplayName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Scenarij: ${alert.scenarioDisplayName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Utjecaj', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(alert.impact),
            if (alert.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Prijedlog', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...alert.recommendations.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.rank}. ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Expanded(child: Text(r.label)),
                    ],
                  ),
                ),
              ),
            ],
            if (showActions && onRequestExplanation != null)
              ApsExecutionWatchExplanationSection(
                explanation: explanation,
                loading: explanationLoading,
                enabled: !busy,
                onRequestExplanation: onRequestExplanation,
              ),
            if (!showActions) ...[
              const SizedBox(height: 12),
              _ValueTrailSection(alert: alert),
            ],
            if (showActions) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onViewSchedule,
                    icon: const Icon(Icons.view_timeline_outlined, size: 18),
                    label: const Text('Pregledaj raspored'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onGoOptimization,
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text('Idi na Optimizaciju'),
                  ),
                  if (onInProgress != null)
                    OutlinedButton(
                      onPressed: busy ? null : onInProgress,
                      child: const Text('Označi kao u toku rješavanja'),
                    ),
                  FilledButton.tonal(
                    onPressed: busy ? null : onResolve,
                    child: Text(
                      alert.isOpportunity
                          ? 'Označi kao iskorišteno'
                          : 'Označi riješeno',
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : onDismiss,
                    child: const Text('Odbaci'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueTrailSection extends StatelessWidget {
  const _ValueTrailSection({required this.alert});

  final ApsExecutionWatchAlertView alert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = <String>[];

    if (alert.userAction != null) {
      lines.add(
        'Akcija: ${ApsExecutionWatchOutcomes.labelForUserAction(alert.userAction!)}',
      );
    }
    if (alert.businessOutcome != null) {
      lines.add(
        'Poslovni ishod: ${ApsExecutionWatchOutcomes.labelForBusinessOutcome(alert.businessOutcome!)}',
      );
    }
    if (alert.responseTimeSeconds != null) {
      final sec = alert.responseTimeSeconds!;
      final min = (sec / 60).round();
      lines.add(
        min > 0
            ? 'Vrijeme odgovora: $min min'
            : 'Vrijeme odgovora: $sec s',
      );
    }
    if (alert.recommendationAccepted == true) {
      lines.add('Glavni prijedlog: slijeđen');
    }

    final vm = alert.valueMetrics;
    final avoided = vm['estimatedAvoidedDelayMinutes'];
    if (avoided != null && avoided.toString().isNotEmpty) {
      lines.add('Procijenjeno izbjegnuto kašnjenje: $avoided min');
    }
    final freed = vm['freedCapacityMinutes'] ?? vm['earlyCompletionMinutes'];
    if (freed != null && freed.toString().isNotEmpty) {
      lines.add('Oslobođen / iskorišten kapacitet: $freed min');
    }
    if (alert.resolutionNote != null && alert.resolutionNote!.isNotEmpty) {
      lines.add('Napomena: ${alert.resolutionNote}');
    }

    if (lines.isEmpty) {
      return Text(
        'Trag vrijednosti još nije zabilježen.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trag vrijednosti', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
