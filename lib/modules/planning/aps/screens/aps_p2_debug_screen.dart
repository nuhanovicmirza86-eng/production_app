import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../helpers/aps_gantt_info_copy.dart';
import 'aps_debug_hub_shared_state.dart';
import 'aps_p0_debug_screen.dart';
import '../services/aps_p0_debug_service.dart';

/// Interni APS P2 Callable smoke test — heuristic scheduling.
///
/// Ulaz: [ApsDebugHubScreen] tab P2 (Registracije → bug ikona).
class ApsP2DebugScreen extends StatefulWidget {
  const ApsP2DebugScreen({
    super.key,
    required this.companyData,
    this.embedInHub = false,
    this.sharedState,
    this.onSharedStateChanged,
  });

  final Map<String, dynamic> companyData;
  final bool embedInHub;
  final ApsDebugHubSharedState? sharedState;
  final VoidCallback? onSharedStateChanged;

  @override
  State<ApsP2DebugScreen> createState() => _ApsP2DebugScreenState();
}

class _ApsP2DebugScreenState extends State<ApsP2DebugScreen>
    with AutomaticKeepAliveClientMixin {
  final ApsP0DebugService _svc = ApsP0DebugService();
  bool _busy = false;
  bool _loadingContext = true;
  ApsP0CallResult? _lastResult;
  String? _runningCallableName;
  String? _loadedScenarioLabel;
  String? _loadedObjectiveProfileId;
  bool _resultPanelExpanded = true;

  String _uid = '';
  String _role = '';

  late final TextEditingController _companyIdCtrl;
  late final TextEditingController _plantKeyCtrl;
  late final TextEditingController _wrongCompanyCtrl;
  late final TextEditingController _scenarioIdCtrl;
  late final TextEditingController _scheduleRunIdCtrl;
  late final TextEditingController _planningSnapshotIdCtrl;
  late final TextEditingController _optimizationRunIdCtrl;
  late final TextEditingController _candidateScheduleRunIdCtrl;

  @override
  bool get wantKeepAlive => widget.embedInHub;

  @override
  void initState() {
    super.initState();
    final cid = (widget.companyData['companyId'] ?? widget.companyData['id'] ?? '')
        .toString()
        .trim();
    _companyIdCtrl = TextEditingController(text: cid);
    _plantKeyCtrl = TextEditingController();
    _wrongCompanyCtrl = TextEditingController(text: 'WRONG_TENANT_ID');
    _scenarioIdCtrl = TextEditingController();
    _scheduleRunIdCtrl = TextEditingController();
    _planningSnapshotIdCtrl = TextEditingController();
    _optimizationRunIdCtrl = TextEditingController();
    _candidateScheduleRunIdCtrl = TextEditingController();
    _applySharedToControllers();
    _loadUserContext();
  }

  @override
  void didUpdateWidget(ApsP2DebugScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedInHub && widget.sharedState != null) {
      _applySharedToControllers();
    }
  }

  void _applySharedToControllers() {
    final shared = widget.sharedState;
    if (shared == null) return;
    if (shared.lastScenarioId.isNotEmpty) {
      _scenarioIdCtrl.text = shared.lastScenarioId;
    }
    if (shared.lastScheduleRunId.isNotEmpty) {
      _scheduleRunIdCtrl.text = shared.lastScheduleRunId;
    }
    if (shared.lastPlanningInputSnapshotId.isNotEmpty) {
      _planningSnapshotIdCtrl.text = shared.lastPlanningInputSnapshotId;
    }
    if (shared.lastOptimizationRunId.isNotEmpty) {
      _optimizationRunIdCtrl.text = shared.lastOptimizationRunId;
    }
    if (shared.lastCandidateScheduleRunId.isNotEmpty) {
      _candidateScheduleRunIdCtrl.text = shared.lastCandidateScheduleRunId;
    }
  }

  void _publishShared({
    String? lastScenarioId,
    String? lastScheduleRunId,
    String? lastPlanningInputSnapshotId,
    String? lastOptimizationRunId,
    String? lastCandidateScheduleRunId,
  }) {
    if (!widget.embedInHub || widget.sharedState == null) return;
    widget.sharedState!.applyPatch(
      lastScenarioId: lastScenarioId ?? _scenarioIdCtrl.text.trim(),
      lastScheduleRunId: lastScheduleRunId ?? _scheduleRunIdCtrl.text.trim(),
      lastPlanningInputSnapshotId:
          lastPlanningInputSnapshotId ?? _planningSnapshotIdCtrl.text.trim(),
      lastOptimizationRunId:
          lastOptimizationRunId ?? _optimizationRunIdCtrl.text.trim(),
      lastCandidateScheduleRunId:
          lastCandidateScheduleRunId ?? _candidateScheduleRunIdCtrl.text.trim(),
    );
    widget.onSharedStateChanged?.call();
  }

  @override
  void dispose() {
    _companyIdCtrl.dispose();
    _plantKeyCtrl.dispose();
    _wrongCompanyCtrl.dispose();
    _scenarioIdCtrl.dispose();
    _scheduleRunIdCtrl.dispose();
    _planningSnapshotIdCtrl.dispose();
    _optimizationRunIdCtrl.dispose();
    _candidateScheduleRunIdCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _companyData => widget.companyData;

  bool get _hasAdvancedPlanning =>
      ProductionModuleKeys.hasAdvancedPlanningModule(_companyData);

  bool get _hasScenarioPlanning =>
      ProductionModuleKeys.hasModule(_companyData, ProductionModuleKeys.apsScenarioPlanning);

  bool get _hasApsOptimization =>
      ProductionModuleKeys.hasModule(_companyData, ProductionModuleKeys.apsOptimization);

  bool get _callableAccessOk => ProductionAccessHelper.canAccessApsP1Callable(
    role: _role,
    companyData: _companyData,
  );

  String get _effectiveScenarioId {
    final fromCtrl = _scenarioIdCtrl.text.trim();
    if (fromCtrl.isNotEmpty) return fromCtrl;
    return widget.sharedState?.lastScenarioId ?? '';
  }

  String get _effectiveOptimizationRunId {
    final fromCtrl = _optimizationRunIdCtrl.text.trim();
    if (fromCtrl.isNotEmpty) return fromCtrl;
    return widget.sharedState?.lastOptimizationRunId ?? '';
  }

  bool get _missingOptimizationRunId => _effectiveOptimizationRunId.isEmpty;

  bool get _missingOptimizationGoal =>
      _loadedObjectiveProfileId == null || _loadedObjectiveProfileId!.trim().isEmpty;

  String _activeScheduleRunIdFromScenario(Map<String, dynamic> scenario) {
    final active = (scenario['activeScheduleRunId'] ?? '').toString().trim();
    if (active.isNotEmpty) return active;
    return (scenario['lastScheduleRunId'] ?? '').toString().trim();
  }

  String _scenarioDisplayLabel(Map<String, dynamic> scenario) {
    final name = (scenario['scenarioName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final code = (scenario['scenarioCode'] ?? '').toString().trim();
    if (code.isNotEmpty) return code;
    return (scenario['id'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> _scenariosReadyForOptimizationLoad(List<dynamic> items) {
    final out = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final status = (map['status'] ?? '').toString().trim().toLowerCase();
      if (status != 'solved') continue;
      if (_activeScheduleRunIdFromScenario(map).isEmpty) continue;
      out.add(map);
    }
    return out;
  }

  void _applyLoadedScenarioForOptimization(Map<String, dynamic> scenario) {
    final scenarioId = (scenario['id'] ?? '').toString().trim();
    final runId = _activeScheduleRunIdFromScenario(scenario);
    final snapId = (scenario['lastPlanningInputSnapshotId'] ?? '').toString().trim();
    final objectiveProfileId = (scenario['objectiveProfileId'] ?? '').toString().trim();
    setState(() {
      _scenarioIdCtrl.text = scenarioId;
      _scheduleRunIdCtrl.text = runId;
      if (snapId.isNotEmpty) {
        _planningSnapshotIdCtrl.text = snapId;
      }
      _loadedScenarioLabel = _scenarioDisplayLabel(scenario);
      _loadedObjectiveProfileId =
          objectiveProfileId.isNotEmpty ? objectiveProfileId : null;
    });
    _publishShared(
      lastScenarioId: scenarioId,
      lastScheduleRunId: runId,
      lastPlanningInputSnapshotId: snapId.isNotEmpty ? snapId : null,
    );
  }

  Future<Map<String, dynamic>?> _pickScenarioForOptimization(
    List<Map<String, dynamic>> candidates,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odaberi scenarij'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Više scenarija ima status Raspored generiran. '
                'Odaberite koji želite testirati u P5.',
              ),
              const SizedBox(height: 12),
              for (final scenario in candidates)
                ListTile(
                  title: Text(_scenarioDisplayLabel(scenario)),
                  subtitle: Text(
                    'id: ${(scenario['id'] ?? '').toString().trim()}\n'
                    'run: ${_activeScheduleRunIdFromScenario(scenario)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => Navigator.pop(ctx, scenario),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Odustani'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadScenarioForOptimization() async {
    if (_busy) return;
    final companyId = _companyIdCtrl.text.trim();
    final plantKey = _plantKeyCtrl.text.trim();
    if (companyId.isEmpty || plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unesite companyId i plantKey prije učitavanja scenarija.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _svc.listApsScenarios({
        'companyId': companyId,
        'plantKey': plantKey,
        'isActive': true,
      });
      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Neuspjelo učitavanje scenarija.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        return;
      }

      final items = result.data?['items'];
      if (items is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nema scenarija za ovaj pogon.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        return;
      }

      final candidates = _scenariosReadyForOptimizationLoad(items);
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Nema scenarija sa statusom Raspored generiran i početnim '
              'scheduleRunId. Generirajte početni raspored u Scenariji i potrebe.',
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      Map<String, dynamic> picked;
      if (candidates.length == 1) {
        picked = candidates.first;
      } else {
        final chosen = await _pickScenarioForOptimization(candidates);
        if (chosen == null || !mounted) return;
        picked = chosen;
      }

      _applyLoadedScenarioForOptimization(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Učitano: ${_scenarioDisplayLabel(picked)} '
            '(run: ${_activeScheduleRunIdFromScenario(picked)})',
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingContext = false);
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = snap.data() ?? {};
    if (!mounted) return;
    setState(() {
      _uid = user.uid;
      _role = ProductionAccessHelper.normalizeRole(data['role']);
      final pk = _plantKeyFromUser(data);
      if (_plantKeyCtrl.text.trim().isEmpty && pk.isNotEmpty) {
        _plantKeyCtrl.text = pk;
      }
      _loadingContext = false;
    });
  }

  String _plantKeyFromUser(Map<String, dynamic> data) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final pk = s(data['plantKey']);
    if (pk.isNotEmpty) return pk;
    final home = s(data['homePlantKey']);
    if (home.isNotEmpty) return home;
    final aa = data['appAccess'];
    if (aa is Map) {
      final apk = s(aa['plantKey']);
      if (apk.isNotEmpty) return apk;
      return s(aa['homePlantKey']);
    }
    return '';
  }

  Map<String, dynamic> _basePayload({String? companyId, String? plantKey}) {
    return {
      'companyId': (companyId ?? _companyIdCtrl.text).trim(),
      'plantKey': (plantKey ?? _plantKeyCtrl.text).trim(),
    };
  }

  Future<void> _run(Future<ApsP0CallResult> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _resultPanelExpanded = true;
    });
    ApsP0CallResult result;
    try {
      result = await action();
    } catch (e) {
      result = ApsP0CallResult(
        callableName: _runningCallableName ?? '(unknown)',
        success: false,
        errorMessage: e.toString(),
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _runningCallableName = null;
      _lastResult = result;
      if (result.success && result.data != null) {
        final data = result.data!;
        final runId = (data['scheduleRunId'] ?? '').toString().trim();
        final snapId = (data['planningInputSnapshotId'] ?? '').toString().trim();
        final optRunId = (data['optimizationRunId'] ?? '').toString().trim();
        final candRunId = (data['candidateScheduleRunId'] ?? '').toString().trim();
        final activeRunId = (data['activeScheduleRunId'] ?? '').toString().trim();

        if (runId.isNotEmpty) {
          _scheduleRunIdCtrl.text = runId;
        }
        if (activeRunId.isNotEmpty) {
          _scheduleRunIdCtrl.text = activeRunId;
        }
        if (snapId.isNotEmpty) {
          _planningSnapshotIdCtrl.text = snapId;
        }
        if (optRunId.isNotEmpty) {
          _optimizationRunIdCtrl.text = optRunId;
        }
        if (candRunId.isNotEmpty) {
          _candidateScheduleRunIdCtrl.text = candRunId;
        }

        final runFromNested = data['run'];
        if (runFromNested is Map) {
          final nestedId = (runFromNested['id'] ?? '').toString().trim();
          final nestedCand = (runFromNested['candidateScheduleRunId'] ?? '')
              .toString()
              .trim();
          if (nestedId.isNotEmpty && optRunId.isEmpty) {
            _optimizationRunIdCtrl.text = nestedId;
          }
          if (nestedCand.isNotEmpty && candRunId.isEmpty) {
            _candidateScheduleRunIdCtrl.text = nestedCand;
          }
        }

        final items = data['items'];
        if (items is List && items.isNotEmpty && optRunId.isEmpty) {
          final first = items.first;
          if (first is Map) {
            final listId = (first['id'] ?? '').toString().trim();
            if (listId.isNotEmpty && _optimizationRunIdCtrl.text.trim().isEmpty) {
              _optimizationRunIdCtrl.text = listId;
            }
          }
        }

        if (runId.isNotEmpty ||
            snapId.isNotEmpty ||
            optRunId.isNotEmpty ||
            candRunId.isNotEmpty ||
            activeRunId.isNotEmpty) {
          _publishShared(
            lastScheduleRunId: (activeRunId.isNotEmpty
                    ? activeRunId
                    : runId.isNotEmpty
                    ? runId
                    : null),
            lastPlanningInputSnapshotId: snapId.isNotEmpty ? snapId : null,
            lastScenarioId: _effectiveScenarioId.isNotEmpty ? _effectiveScenarioId : null,
            lastOptimizationRunId: _optimizationRunIdCtrl.text.trim().isNotEmpty
                ? _optimizationRunIdCtrl.text.trim()
                : null,
            lastCandidateScheduleRunId:
                _candidateScheduleRunIdCtrl.text.trim().isNotEmpty
                ? _candidateScheduleRunIdCtrl.text.trim()
                : null,
          );
        }
      }
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.summaryLine),
          backgroundColor: result.success ? Colors.green.shade800 : Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearResult() => setState(() => _lastResult = null);

  Widget _wrapScaffold({required Widget body}) {
    if (widget.embedInHub) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('APS P2 Debug / Internal'),
        backgroundColor: Colors.purple.shade900,
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loadingContext) {
      return _wrapScaffold(body: const Center(child: CircularProgressIndicator()));
    }

    if (!apsP0DebugEntryAllowed(_role)) {
      return _wrapScaffold(
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nemaš pristup APS debug alatu.\n'
              'Potrebna uloga: admin ili menadžer proizvodnje.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final missingScenario = _effectiveScenarioId.isEmpty;

    return _wrapScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                _banner(
                  'P2 — initial deterministic schedule (draft_planned). '
                  'scenarioId dolazi iz P1 taba / hub shared state.',
                  Colors.purple.shade100,
                ),
                if (missingScenario)
                  _banner(
                    'Nema scenarioId — u P1 tabu: create scenario + add demand, '
                    'pa se vrati ovdje (hub čuva lastScenarioId).',
                    Colors.red.shade100,
                  ),
                if (!_callableAccessOk)
                  _banner(
                    'P2 gate = P1 gate: advanced_planning=$_hasAdvancedPlanning, '
                    'aps_scenario_planning=$_hasScenarioPlanning.',
                    Colors.amber.shade100,
                  ),
                _sectionContext(),
                _sectionSchedule(missingScenario: missingScenario),
                _sectionP4aApprove(missingScenario: missingScenario),
                _sectionP4bPilotRelease(missingScenario: missingScenario),
                _sectionP5Optimization(missingScenario: missingScenario),
                _sectionNegativeTests(missingScenario: missingScenario),
              ],
            ),
          ),
          _buildLastResultPanel(),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _sectionContext() {
    return _Section(
      title: '1. Kontekst (P2 = P1 gate)',
      children: [
        Text('uid: $_uid'),
        Text('role: $_role'),
        Text('canAccessApsP1Callable: $_callableAccessOk'),
        if (widget.sharedState != null) ...[
          Text('hub lastScenarioId: ${widget.sharedState!.lastScenarioId.isEmpty ? "—" : widget.sharedState!.lastScenarioId}'),
          Text('hub lastDemandId: ${widget.sharedState!.lastDemandId.isEmpty ? "—" : widget.sharedState!.lastDemandId}'),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _companyIdCtrl,
          decoration: const InputDecoration(
            labelText: 'companyId',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _plantKeyCtrl,
          decoration: const InputDecoration(
            labelText: 'plantKey',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _scenarioIdCtrl,
          onChanged: (v) => _publishShared(lastScenarioId: v.trim()),
          decoration: const InputDecoration(
            labelText: 'scenarioId (sync s P1 / hub)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _sectionSchedule({required bool missingScenario}) {
    return _Section(
      title: '2. Heuristic schedule',
      children: [
        TextField(
          controller: _scheduleRunIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last scheduleRunId (opcionalno za list filter)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _planningSnapshotIdCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'last planningInputSnapshotId (read-only)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn(
          'P2-10 generateApsHeuristicSchedule',
          missingScenario,
          () {
            return _svc.generateApsHeuristicSchedule({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'P2-11 listApsScheduleOperations',
          missingScenario,
          () {
            final body = {
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            };
            final runId = _scheduleRunIdCtrl.text.trim();
            if (runId.isNotEmpty) {
              body['scheduleRunId'] = runId;
            }
            return _svc.listApsScheduleOperations(body);
          },
        ),
        _btn(
          'P2-11b verify status = draft_planned',
          missingScenario,
          () async {
            final body = {
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            };
            final runId = _scheduleRunIdCtrl.text.trim();
            if (runId.isNotEmpty) {
              body['scheduleRunId'] = runId;
            }
            final result = await _svc.listApsScheduleOperations(body);
            final mismatch = ApsP0CallResult.scheduleOpsStatusMismatch(result);
            if (mismatch != null) {
              return ApsP0CallResult(
                callableName: 'listApsScheduleOperations',
                success: false,
                errorMessage: mismatch,
                data: result.data,
                durationMs: result.durationMs,
              );
            }
            return result;
          },
        ),
        _btn(
          'P2-12 ponovi generate (determinizam)',
          missingScenario,
          () {
            return _svc.generateApsHeuristicSchedule({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'P2-20 clearApsScenarioSchedule',
          missingScenario,
          () {
            return _svc.clearApsScenarioSchedule({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'listApsCapacityWarnings (schedule warnings)',
          missingScenario,
          () {
            return _svc.listApsCapacityWarnings({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
      ],
    );
  }

  Widget _sectionP4aApprove({required bool missingScenario}) {
    return _Section(
      title: '3. P4a — potvrda plana (approve)',
      children: [
        const Text(
          'Samo approveApsScenarioSchedule — bez MES release. '
          'Pilot flag nije potreban za potvrdu.',
        ),
        _btn(
          'P4-10 approveApsScenarioSchedule → planned',
          missingScenario,
          () {
            return _svc.approveApsScenarioSchedule({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'targetStatus': 'planned',
            });
          },
        ),
        _btn(
          'P4-10b approveApsScenarioSchedule → firm_planned',
          missingScenario,
          () {
            return _svc.approveApsScenarioSchedule({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'targetStatus': 'firm_planned',
            });
          },
        ),
        _btn(
          'P4-12 wrong companyId → approve',
          false,
          () {
            return _svc.approveApsScenarioSchedule({
              ..._basePayload(companyId: _wrongCompanyCtrl.text),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
      ],
    );
  }

  Widget _sectionP4bPilotRelease({required bool missingScenario}) {
    return _Section(
      title: '4. P4b — pilot release u MES',
      children: [
        const Text(
          'Samo releaseApsScenarioToMesPilot — odvojeno od approve (P4a). '
          'Zahtijeva apsPilotReleaseEnabled === true na kompaniji. '
          'Pilot — kontrolisana validacija, ne full production release.',
        ),
        _btn(
          'P4-20 releaseApsScenarioToMesPilot (nakon approve)',
          missingScenario,
          () {
            return _svc.releaseApsScenarioToMesPilot({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'pilotAcknowledgement': true,
            });
          },
        ),
        _btn(
          'P4-21 release bez approve (draft_planned) → FAIL',
          missingScenario,
          () {
            return _svc.releaseApsScenarioToMesPilot({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'pilotAcknowledgement': true,
            });
          },
        ),
        _btn(
          'P4-23 release bez pilot flaga → FAIL',
          missingScenario,
          () {
            return _svc.releaseApsScenarioToMesPilot({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'pilotAcknowledgement': true,
            });
          },
        ),
        _btn(
          'P4-24 release bez pilotAcknowledgement → FAIL',
          missingScenario,
          () {
            return _svc.releaseApsScenarioToMesPilot({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'P4-25 wrong companyId → release',
          false,
          () {
            return _svc.releaseApsScenarioToMesPilot({
              ..._basePayload(companyId: _wrongCompanyCtrl.text),
              'scenarioId': _effectiveScenarioId,
              'pilotAcknowledgement': true,
            });
          },
        ),
        const Text(
          'P4-22 (in_progress/completed nalog): ručno — fixture s blokiranim nalogom.\n'
          'P4-26 (production_operator): testirati prijavom kao operater.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _sectionP5Optimization({required bool missingScenario}) {
    return _Section(
      title: '5. P5 — Optimizacija',
      children: [
        const Text(
          'Interni test P5.1 stub lifecycle. Ako ste scenarij napravili kroz '
          'operativni ekran Scenariji i potrebe, prvo kliknite '
          '„Učitaj scenario za optimizaciju“. Scenarij mora imati status '
          'Raspored generiran, početni scheduleRunId i cilj optimizacije.',
        ),
        if (!_hasApsOptimization)
          _banner(
            'P5 gate: modul aps_optimization nije aktivan na kompaniji.',
            Colors.amber.shade100,
          ),
        if (missingScenario)
          _banner(
            'scenarioId nije učitan — kliknite Učitaj scenario za optimizaciju '
            '(hub shared state se puni samo kroz debug P1/P2 tok).',
            Colors.orange.shade100,
          ),
        if (!missingScenario && _missingOptimizationGoal)
          _banner(
            ApsGanttInfoCopy.optimizationGoalMissingHint,
            Colors.red.shade100,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : _loadScenarioForOptimization,
              child: const Text('Učitaj scenario za optimizaciju'),
            ),
          ),
        ),
        if (_loadedScenarioLabel != null && _loadedScenarioLabel!.isNotEmpty)
          Text(
            'Učitano: $_loadedScenarioLabel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
        Text(
          'scenarioId: ${_effectiveScenarioId.isEmpty ? "—" : _effectiveScenarioId}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          'početni scheduleRunId: '
          '${_scheduleRunIdCtrl.text.trim().isEmpty ? "—" : _scheduleRunIdCtrl.text.trim()}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '${ApsGanttInfoCopy.optimizationGoalLabel}: '
          '${_missingOptimizationGoal ? "—" : _loadedObjectiveProfileId}',
          style: TextStyle(
            fontSize: 12,
            color: _missingOptimizationGoal ? Colors.red.shade900 : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _optimizationRunIdCtrl,
          onChanged: (v) => _publishShared(lastOptimizationRunId: v.trim()),
          decoration: const InputDecoration(
            labelText: 'optimizationRunId (P5-11 / P5-13 / P5-15)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _candidateScheduleRunIdCtrl,
          onChanged: (v) => _publishShared(lastCandidateScheduleRunId: v.trim()),
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'candidateScheduleRunId — predloženi raspored (read-only)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn(
          'P5-10 Pokreni prijedlog optimizacije',
          missingScenario ||
              _missingOptimizationGoal ||
              !_hasApsOptimization,
          () {
            return _svc.startApsOptimizationRun({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'P5-11 Učitaj prijedlog optimizacije',
          missingScenario || _missingOptimizationRunId || !_hasApsOptimization,
          () {
            return _svc.getApsOptimizationRun({
              ..._basePayload(),
              'optimizationRunId': _effectiveOptimizationRunId,
            });
          },
        ),
        _btn(
          'P5-12 Lista prijedloga',
          missingScenario || !_hasApsOptimization,
          () {
            return _svc.listApsOptimizationRuns({
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
            });
          },
        ),
        _btn(
          'P5-13 Odbaci prijedlog',
          missingScenario || _missingOptimizationRunId || !_hasApsOptimization,
          () {
            return _svc.discardApsOptimizationRun({
              ..._basePayload(),
              'optimizationRunId': _effectiveOptimizationRunId,
            });
          },
        ),
        _btn(
          'P5-15 Primijeni prijedlog',
          missingScenario || _missingOptimizationRunId || !_hasApsOptimization,
          () {
            return _svc.applyApsOptimizationResult({
              ..._basePayload(),
              'optimizationRunId': _effectiveOptimizationRunId,
            });
          },
        ),
        _btn(
          'P5 verify — list ops (predloženi scheduleRunId)',
          missingScenario || _candidateScheduleRunIdCtrl.text.trim().isEmpty,
          () {
            final body = {
              ..._basePayload(),
              'scenarioId': _effectiveScenarioId,
              'scheduleRunId': _candidateScheduleRunIdCtrl.text.trim(),
            };
            return _svc.listApsScheduleOperations(body);
          },
        ),
      ],
    );
  }

  Widget _sectionNegativeTests({required bool missingScenario}) {
    return _Section(
      title: '6. Negativni testovi',
      children: [
        TextField(
          controller: _wrongCompanyCtrl,
          decoration: const InputDecoration(
            labelText: 'wrong companyId (P2-40)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn(
          'P2-40 wrong companyId → generate',
          false,
          () {
            return _svc.generateApsHeuristicSchedule({
              ..._basePayload(companyId: _wrongCompanyCtrl.text.trim()),
              'scenarioId': _effectiveScenarioId.isNotEmpty ? _effectiveScenarioId : 'MISSING',
            });
          },
        ),
      ],
    );
  }

  Widget _buildLastResultPanel() {
    final result = _lastResult;
    final borderColor = _busy
        ? Colors.orange.shade700
        : result == null
        ? Colors.grey.shade400
        : result.success
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Last result / last error',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      _resultPanelExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() => _resultPanelExpanded = !_resultPanelExpanded);
                    },
                  ),
                ],
              ),
              if (_busy)
                Text(
                  'Poziv: ${_runningCallableName ?? "…"}',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                )
              else if (result != null)
                Text(
                  result.summaryLine,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: result.success
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                )
              else
                const Text(
                  '— klikni dugme; rezultat ispod —',
                  style: TextStyle(fontSize: 12),
                ),
              if (_resultPanelExpanded && !_busy && result != null) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.28,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.displayText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: result.success
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy || result == null ? null : _clearResult,
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(
    String label,
    bool disabled,
    Future<ApsP0CallResult> Function() action,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: _busy || disabled
              ? null
              : () {
                  setState(() => _runningCallableName = label);
                  _run(action);
                },
          child: Text(label),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
