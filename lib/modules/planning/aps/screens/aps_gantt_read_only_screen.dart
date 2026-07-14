import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_session_context.dart';
import '../models/aps_gantt_view_data.dart';
import '../models/aps_scenario_view.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_p1_write_service.dart';
import '../services/aps_p4_write_service.dart';
import '../services/aps_schedule_read_service.dart';
import '../widgets/aps_plan_confirm_dialog.dart';
import '../widgets/aps_pilot_release_dialog.dart';
import '../widgets/aps_pilot_validation_badge.dart';
import '../widgets/aps_gantt_resource_row.dart';
import '../widgets/aps_gantt_timeline.dart';
import '../widgets/aps_scenario_picker.dart';

/// P3 Gantt + P4a potvrda plana + P4b pilot release (odvojeni koraci).
///
/// Callable-only: [listApsScenarios], [listApsScheduleOperations],
/// [approveApsScenarioSchedule], [releaseApsScenarioToMesPilot].
/// Bez drag/resize, solvera ili AI.
class ApsGanttReadOnlyScreen extends StatefulWidget {
  const ApsGanttReadOnlyScreen({
    super.key,
    required this.companyData,
    this.initialScenarioId,
  });

  final Map<String, dynamic> companyData;

  /// Ako je zadan, nakon učitavanja odabire ovaj scenarij (npr. iz Scenariji i potrebe).
  final String? initialScenarioId;

  @override
  State<ApsGanttReadOnlyScreen> createState() => _ApsGanttReadOnlyScreenState();
}

class _ApsGanttReadOnlyScreenState extends State<ApsGanttReadOnlyScreen> {
  static const _labelColumnWidth = 128.0;
  static const _rowHeight = 52.0;

  final ApsScheduleReadService _readService = ApsScheduleReadService();
  final ApsP1WriteService _p1 = ApsP1WriteService();
  final ApsOperationalCache _cache = ApsOperationalCache.instance;
  final ApsP4WriteService _p4Write = ApsP4WriteService();
  late final ApsSessionContext _session;
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _bodyVScroll = ScrollController();

  bool _loadingScenarios = true;
  bool _loadingGantt = false;
  bool _confirmingPlan = false;
  bool _releasingPilot = false;
  String? _error;

  List<ApsScenarioView> _scenarios = const [];
  ApsScenarioView? _selectedScenario;
  ApsGanttViewData? _gantt;

  Map<String, dynamic> get _companyData => widget.companyData;

  String get _companyId => _session.companyId;
  String get _plantKey => _session.plantKey;
  String get _role => _session.role;

  bool get _accessOk => _session.accessOk;

  bool get _pilotReleaseEnabled =>
      _companyData['apsPilotReleaseEnabled'] == true;

  bool get _canApprovePlan =>
      ProductionAccessHelper.canApproveApsRelease(_role);

  bool get _canShowConfirmPlanButton =>
      _accessOk &&
      _canApprovePlan &&
      (_selectedScenario?.isReadyForPlanConfirmation ?? false) &&
      (_gantt?.allOperationsDraftPlanned ?? false) &&
      !_confirmingPlan &&
      !_releasingPilot;

  bool get _canShowPilotReleaseButton =>
      _accessOk &&
      _canApprovePlan &&
      _pilotReleaseEnabled &&
      (_selectedScenario?.isApprovedForPilotRelease ?? false) &&
      !_confirmingPlan &&
      !_releasingPilot;

  bool get _showActionBar =>
      _canShowConfirmPlanButton || _canShowPilotReleaseButton;

  bool get _showPilotValidationBadge =>
      _selectedScenario?.isPilotReleasedToMes ?? false;

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(_companyData);
    _bodyHScroll.addListener(_syncHeaderFromBody);
    _loadContextAndScenarios();
  }

  void _syncHeaderFromBody() {
    if (!_headerHScroll.hasClients || !_bodyHScroll.hasClients) return;
    if (_headerHScroll.offset != _bodyHScroll.offset) {
      _headerHScroll.jumpTo(_bodyHScroll.offset);
    }
  }

  @override
  void dispose() {
    _bodyHScroll.removeListener(_syncHeaderFromBody);
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    _bodyVScroll.dispose();
    super.dispose();
  }

  Future<void> _loadContextAndScenarios({bool forceRefresh = false}) async {
    setState(() {
      _loadingScenarios = true;
      _error = null;
    });

    try {
      if (!_accessOk) {
        if (mounted) {
          setState(() {
            _loadingScenarios = false;
          });
        }
        return;
      }

      if (_plantKey.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingScenarios = false;
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

      if (!mounted) return;
      final initialId = widget.initialScenarioId?.trim() ?? '';
      setState(() {
        _scenarios = scenarios;
        _loadingScenarios = false;
        if (initialId.isNotEmpty) {
          ApsScenarioView? matched;
          for (final s in scenarios) {
            if (s.id == initialId) {
              matched = s;
              break;
            }
          }
          _selectedScenario =
              matched ?? (scenarios.isNotEmpty ? scenarios.first : null);
        } else if (_selectedScenario == null && scenarios.isNotEmpty) {
          _selectedScenario = scenarios.first;
        } else if (_selectedScenario != null) {
          final prevId = _selectedScenario!.id;
          ApsScenarioView? matched;
          for (final s in scenarios) {
            if (s.id == prevId) {
              matched = s;
              break;
            }
          }
          _selectedScenario =
              matched ?? (scenarios.isNotEmpty ? scenarios.first : null);
        }
      });

      if (_selectedScenario != null) {
        await _loadGantt();
      }
    } on ApsP1WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingScenarios = false;
        _error = e.message;
      });
    } on ApsScheduleReadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingScenarios = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingScenarios = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadGantt() async {
    final scenario = _selectedScenario;
    if (scenario == null || _plantKey.isEmpty) return;

    setState(() {
      _loadingGantt = true;
      _error = null;
    });

    try {
      final data = await _readService.fetchGanttForScenario(
        companyId: _companyId,
        plantKey: _plantKey,
        scenario: scenario,
      );
      if (!mounted) return;
      setState(() {
        _gantt = data;
        _loadingGantt = false;
      });
    } on ApsScheduleReadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGantt = false;
        _error = e.message;
        _gantt = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGantt = false;
        _error = e.toString();
        _gantt = null;
      });
    }
  }

  Future<void> _onScenarioChanged(ApsScenarioView? scenario) async {
    setState(() => _selectedScenario = scenario);
    if (scenario != null) {
      await _loadGantt();
    } else {
      setState(() => _gantt = null);
    }
  }

  Future<void> _onConfirmPlanPressed() async {
    final scenario = _selectedScenario;
    final gantt = _gantt;
    if (scenario == null || gantt == null || !_canShowConfirmPlanButton) {
      return;
    }

    final confirmed = await showApsPlanConfirmDialog(
      context,
      scenarioLabel: scenario.displayLabel,
      operationCount: gantt.operations.length,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _confirmingPlan = true;
      _error = null;
    });

    try {
      final result = await _p4Write.confirmPlan(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      if (!mounted) return;
      await _loadContextAndScenarios(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ApsGanttInfoCopy.planConfirmSuccessPrefix} '
            '${result.operationCount} operacija rasporeda.\n'
            'Scenarij: ${ApsGanttInfoCopy.scenarioStatusLabel(result.scenarioStatus)}',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    } on ApsP4WriteException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _confirmingPlan = false);
      }
    }
  }

  Future<void> _onPilotReleasePressed() async {
    final scenario = _selectedScenario;
    if (scenario == null || !_canShowPilotReleaseButton) return;

    final confirmed = await showApsPilotReleaseConfirmDialog(
      context,
      scenarioLabel: scenario.displayLabel,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _releasingPilot = true;
      _error = null;
    });

    try {
      final result = await _p4Write.releaseToMesPilot(
        companyId: _companyId,
        plantKey: _plantKey,
        scenarioId: scenario.id,
      );
      if (!mounted) return;
      await _loadContextAndScenarios(forceRefresh: true);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${ApsGanttInfoCopy.pilotReleaseSuccessPrefix} '
            'ažurirano ${result.operationsReleased} operacija rasporeda.\n'
            '${ApsGanttInfoCopy.pilotValidationBadge}',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    } on ApsP4WriteException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _releasingPilot = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ApsGanttInfoCopy.hubSectionSubtitle),
            Text(
              ApsGanttInfoCopy.screenTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              ApsGanttInfoCopy.screenSubtitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          if (_showPilotValidationBadge)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(child: ApsPilotValidationBadge(compact: true)),
            ),
          IconButton(
            tooltip: 'Informacije',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: ApsGanttInfoCopy.screenTitle,
              body: ApsGanttInfoCopy.hubScheduleCardInfoBody,
            ),
          ),
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loadingScenarios || _loadingGantt
                ? null
                : () async {
                    await _loadContextAndScenarios(forceRefresh: true);
                  },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _showActionBar ? _buildActionBar() : null,
    );
  }

  Widget _buildActionBar() {
    if (_canShowConfirmPlanButton) {
      return _buildConfirmPlanBar();
    }
    if (_canShowPilotReleaseButton) {
      return _buildPilotReleaseBar();
    }
    return const SizedBox.shrink();
  }

  Widget _buildConfirmPlanBar() {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: _confirmingPlan ? null : _onConfirmPlanPressed,
            icon: _confirmingPlan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Potvrdi plan'),
          ),
        ),
      ),
    );
  }

  Widget _buildPilotReleaseBar() {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: _releasingPilot ? null : _onPilotReleasePressed,
            icon: _releasingPilot
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Pošalji u MES (pilot)'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingScenarios && _scenarios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_accessOk) {
      return _messagePanel(
        icon: Icons.lock_outline,
        title: 'Nema pristupa',
        message:
            'Potrebna pretplata Napredno planiranje i Scenariji planiranja te '
            'uloga menadžera proizvodnje, administratora ili super administratora.',
      );
    }

    if (_error != null && _gantt == null && _scenarios.isEmpty) {
      return _messagePanel(
        icon: Icons.error_outline,
        title: 'Greška',
        message: _error!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ApsScenarioPicker(
            scenarios: _scenarios,
            selected: _selectedScenario,
            loading: _loadingScenarios || _loadingGantt,
            onChanged: _onScenarioChanged,
          ),
        ),
        if (_showPilotValidationBadge)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ApsPilotValidationBadge(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.warning_amber_outlined),
              actions: [
                TextButton(onPressed: _loadGantt, child: const Text('Pokušaj ponovo')),
              ],
            ),
          ),
        Expanded(child: _buildGanttArea()),
      ],
    );
  }

  Widget _buildGanttArea() {
    if (_loadingGantt) {
      return const Center(child: CircularProgressIndicator());
    }

    final gantt = _gantt;
    if (gantt == null || _selectedScenario == null) {
      return _messagePanel(
        icon: Icons.view_timeline_outlined,
        title: 'Odaberite scenarij',
        message: 'Scenarij određuje period planiranja i operacije za prikaz.',
      );
    }

    if (!gantt.hasOperations) {
      return _messagePanel(
        icon: Icons.event_busy_outlined,
        title: 'Nema operacija',
        message: ApsGanttInfoCopy.emptyScheduleMessage,
      );
    }

    final start = gantt.horizonStart;
    final end = gantt.horizonEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return _messagePanel(
        icon: Icons.date_range_outlined,
        title: 'Period nije definisan',
        message: ApsGanttInfoCopy.missingHorizonMessage,
      );
    }

    final viewport = MediaQuery.sizeOf(context).width;
    final timelineWidth = apsGanttTimelineWidth(
      horizonStart: start,
      horizonEnd: end,
      viewportWidth: viewport,
    );
    final bodyHeight = gantt.lanes.length * _rowHeight;

    return Column(
      children: [
        _buildTimelineHeader(start, end, timelineWidth),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _labelColumnWidth,
                child: Scrollbar(
                  controller: _bodyVScroll,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _bodyVScroll,
                    itemCount: gantt.lanes.length,
                    itemExtent: _rowHeight,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) => ApsGanttResourceLabel(
                      lane: gantt.lanes[index],
                      height: _rowHeight,
                      width: _labelColumnWidth,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _bodyHScroll,
                  thumbVisibility: true,
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    controller: _bodyHScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: timelineWidth,
                      height: bodyHeight,
                      child: ListView.builder(
                        controller: _bodyVScroll,
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        itemCount: gantt.lanes.length,
                        itemExtent: _rowHeight,
                        itemBuilder: (context, index) => ApsGanttResourceRow(
                          lane: gantt.lanes[index],
                          horizonStart: start,
                          horizonEnd: end,
                          timelineWidth: timelineWidth,
                          rowHeight: _rowHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (gantt.operations.length <= 12)
          _buildSummaryList(gantt)
        else
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${gantt.operations.length} operacija na ${gantt.lanes.length} resursa',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineHeader(
    DateTime start,
    DateTime end,
    double timelineWidth,
  ) {
    return Row(
      children: [
        SizedBox(
          width: _labelColumnWidth,
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: const Center(
              child: Text('Resurs', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _headerHScroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: ApsGanttTimeline(
              horizonStart: start,
              horizonEnd: end,
              width: timelineWidth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryList(ApsGanttViewData gantt) {
    return Material(
      elevation: 1,
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          itemCount: gantt.operations.length,
          itemBuilder: (context, index) => ApsGanttOperationSummaryTile(
            operation: gantt.operations[index],
          ),
        ),
      ),
    );
  }

  Widget _messagePanel({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
