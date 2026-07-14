import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_capacity_load_helper.dart';
import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_session_context.dart';
import '../models/aps_demand_view.dart';
import '../models/aps_capacity_warning_view.dart';
import '../models/aps_resource_capacity_row.dart';
import '../models/aps_rough_capacity_result.dart';
import '../models/aps_scenario_view.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_p1_write_service.dart';
import '../widgets/aps_capacity_load_badge.dart';
import '../widgets/aps_scenario_picker.dart';
import 'aps_gantt_read_only_screen.dart';

/// Operativni P1 ekran — rough capacity, opterećenje resursa i upozorenja.
///
/// Callable-only: [calculateApsRoughCapacity], [listApsCapacityWarnings].
class ApsCapacityScreen extends StatefulWidget {
  const ApsCapacityScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ApsCapacityScreen> createState() => _ApsCapacityScreenState();
}

class _ApsCapacityScreenState extends State<ApsCapacityScreen> {
  final ApsP1WriteService _service = ApsP1WriteService();
  final ApsOperationalCache _cache = ApsOperationalCache.instance;
  late final ApsSessionContext _session;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ApsScenarioView> _scenarios = const [];
  List<ApsDemandView> _demands = const [];
  ApsScenarioView? _selectedScenario;
  ApsRoughCapacityResult? _lastResult;
  List<ApsCapacityWarningView> _warnings = const [];

  Map<String, dynamic> get _companyData => widget.companyData;

  String get _companyId => _session.companyId;
  String get _plantKey => _session.plantKey;

  bool get _accessOk => _session.accessOk;

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(_companyData);
    _loadInitial();
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
          service: _service,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
        _cache.demands(
          service: _service,
          companyId: _companyId,
          plantKey: _plantKey,
          forceRefresh: forceRefresh,
        ),
      ]);
      final scenarios = fetched[0] as List<ApsScenarioView>;
      final demands = fetched[1] as List<ApsDemandView>;

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
        _demands = demands;
        _selectedScenario = selected;
        _lastResult = null;
        _warnings = const [];
        _loading = false;
      });

      if (selected != null) {
        await _loadWarningsForScenario(selected);
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

  Future<void> _loadWarningsForScenario(ApsScenarioView scenario) async {
    final snapshotId = scenario.lastSnapshotId;
    if (snapshotId == null || snapshotId.isEmpty) {
      if (mounted) setState(() => _warnings = const []);
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
      setState(() => _warnings = warnings);
    } on ApsP1WriteException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _onScenarioChanged(ApsScenarioView? scenario) async {
    setState(() {
      _selectedScenario = scenario;
      _lastResult = null;
      _warnings = const [];
    });
    if (scenario != null) {
      await _loadWarningsForScenario(scenario);
    }
  }

  Future<void> _runCalculate() async {
    final scenario = _selectedScenario;
    if (scenario == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proračunaj kapacitet'),
        content: const Text(ApsGanttInfoCopy.capacityCalculateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proračunaj'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await _service.calculateRoughCapacity(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      final warnings = await _service.fetchCapacityWarnings(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
        snapshotId: result.snapshotId,
      );
      final scenarios = await _cache.scenarios(
        service: _service,
        companyId: _companyId,
        plantKey: _plantKey,
        forceRefresh: true,
      );
      final demands = await _cache.demands(
        service: _service,
        companyId: _companyId,
        plantKey: _plantKey,
        forceRefresh: true,
      );
      ApsScenarioView? refreshed = scenario;
      for (final s in scenarios) {
        if (s.id == scenario.id) {
          refreshed = s;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _warnings = warnings;
        _scenarios = scenarios;
        _demands = demands;
        _selectedScenario = refreshed;
        _busy = false;
      });
      _showSuccess(
        'Kapacitet procijenjen — iskorištenost ${result.utilizationPercent}%.',
      );
    } on ApsP1WriteException catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.message);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.toString());
    }
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

  ApsCapacityLoadLevel _resourceLoadLevel(
    ApsResourceCapacityRow row,
    List<ApsCapacityWarningView> warnings,
  ) {
    final resourceWarnings =
        warnings.where((w) => w.resourceId == row.resourceId).toList();
    return ApsCapacityLoadHelper.resourceLevel(
      availableMinutes: row.availableMinutes,
      allocatedMinutes: row.allocatedMinutes,
      hasCriticalWarning: resourceWarnings.any((w) => w.isCritical),
      hasWarning: resourceWarnings.any((w) => w.isWarning),
    );
  }

  ApsCapacityLoadLevel? get _displayOverallLevel {
    if (_lastResult != null) return _lastResult!.overallLoadLevel;
    if (_warnings.isEmpty) return null;
    final hasCritical = _warnings.any((w) => w.isCritical);
    if (hasCritical) return ApsCapacityLoadLevel.bottleneck;
    if (_warnings.any((w) => w.isWarning || w.severity == 'info')) {
      return ApsCapacityLoadLevel.warning;
    }
    return ApsCapacityLoadLevel.ok;
  }

  String? _demandLabelForWarning(ApsCapacityWarningView warning) {
    final id = warning.demandId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final d in _demands) {
        if (d.id == id) return d.displayLabel;
      }
    }
    return null;
  }

  String? _resourceLabelForWarning(ApsCapacityWarningView warning) {
    final id = warning.resourceId?.trim();
    if (id != null && id.isNotEmpty) {
      final rows = _lastResult?.summaryByResource ?? const [];
      for (final row in rows) {
        if (row.resourceId == id) return row.displayCode;
      }
    }
    return null;
  }

  String _warningUserText(ApsCapacityWarningView warning) {
    return ApsGanttInfoCopy.capacityWarningUserMessage(
      warningCode: warning.warningCode,
      backendMessage: warning.message,
      demandLabel: _demandLabelForWarning(warning),
      resourceLabel: _resourceLabelForWarning(warning),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text(ApsGanttInfoCopy.capacityScreenTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_accessOk) {
      return Scaffold(
        appBar: AppBar(title: const Text(ApsGanttInfoCopy.capacityScreenTitle)),
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

    final scenario = _selectedScenario;
    final result = _lastResult;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(ApsGanttInfoCopy.capacityScreenTitle),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _busy
                ? null
                : () => _loadInitial(
                    selectScenarioId: scenario?.id,
                    forceRefresh: true,
                  ),
          ),
          IconButton(
            tooltip: 'Informacije',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: ApsGanttInfoCopy.capacityScreenTitle,
              body: ApsGanttInfoCopy.hubCapacityCardInfoBody,
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _loadInitial(
                    selectScenarioId: scenario?.id,
                    forceRefresh: true,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    children: [
                      Text(
                        ApsGanttInfoCopy.capacityIntro,
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
                        _ScenarioStatusRow(scenario: scenario),
                        if (_displayOverallLevel != null) ...[
                          const SizedBox(height: 12),
                          ApsCapacityLoadBadge(level: _displayOverallLevel!),
                        ],
                        if (result != null) ...[
                          const SizedBox(height: 16),
                          _SummaryCard(result: result),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Opterećenje resursa',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (result != null && result.summaryByResource.isNotEmpty)
                          ...result.summaryByResource.map(
                            (row) => _ResourceLoadTile(
                              row: row,
                              level: _resourceLoadLevel(row, _warnings),
                            ),
                          )
                        else
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                ApsGanttInfoCopy.capacityNoResourcesHint,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Upozorenja (${_warnings.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (_warnings.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(ApsGanttInfoCopy.capacityNoWarningsHint),
                            ),
                          )
                        else
                          ..._warnings.map(
                            (w) => _WarningTile(
                              warning: w,
                              userMessage: _warningUserText(w),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _runCalculate,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Proračunaj kapacitet'),
                            ),
                            FilledButton.tonalIcon(
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
                              'Nema scenarija. Kreirajte scenarij u Scenariji i potrebe.',
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
            ),
    );
  }
}

class _ScenarioStatusRow extends StatelessWidget {
  const _ScenarioStatusRow({required this.scenario});

  final ApsScenarioView scenario;

  @override
  Widget build(BuildContext context) {
    final start = scenario.periodStart;
    final end = scenario.periodEnd;
    final theme = Theme.of(context);
    String periodText;
    if (start != null && end != null) {
      periodText =
          'Period planiranja: ${DateFormat('d.M.yyyy.').format(start)} – '
          '${DateFormat('d.M.yyyy.').format(end)}';
    } else {
      periodText = ApsGanttInfoCopy.missingHorizonMessage;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(
            'Status scenarija: ${ApsGanttInfoCopy.scenarioStatusLabel(scenario.status)}',
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 4),
        Text(
          periodText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: start != null && end != null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final ApsRoughCapacityResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final util = result.utilizationPercent;
    final utilClamped = util > 100 ? 1.0 : (util / 100).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sažetak proračuna', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Text('Iskorištenost: $util%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: utilClamped,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              'Potražnja: ${result.totalDemandMinutes} min · '
              'Raspoloživo: ${result.totalAvailableMinutes} min',
            ),
            Text(
              'Potražnji: ${result.demandCount} · Resursi: ${result.resourceCount} · '
              'Upozorenja: ${result.warningCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLoadTile extends StatelessWidget {
  const _ResourceLoadTile({required this.row, required this.level});

  final ApsResourceCapacityRow row;
  final ApsCapacityLoadLevel level;

  @override
  Widget build(BuildContext context) {
    final util = row.utilizationPercent;
    final utilClamped = util > 100 ? 1.0 : (util / 100).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.displayCode,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ApsCapacityLoadBadge(level: level, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text('Opterećenje: $util%'),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: utilClamped,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Text(
              'Alocirano: ${row.allocatedMinutes} min · '
              'Raspoloživo: ${row.availableMinutes} min',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({
    required this.warning,
    required this.userMessage,
  });

  final ApsCapacityWarningView warning;
  final String userMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (warning.severity) {
      'critical' => Icons.error_outline,
      'warning' => Icons.warning_amber_outlined,
      _ => Icons.info_outline,
    };
    final color = switch (warning.severity) {
      'critical' => cs.error,
      'warning' => cs.tertiary,
      _ => cs.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          ApsGanttInfoCopy.warningCodeLabel(warning.warningCode),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(userMessage),
        isThreeLine: userMessage.length > 60,
      ),
    );
  }
}
