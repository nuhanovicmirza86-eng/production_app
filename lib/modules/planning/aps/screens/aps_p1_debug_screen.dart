import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import 'aps_p0_debug_screen.dart';
import 'aps_debug_hub_shared_state.dart';
import '../services/aps_p0_debug_service.dart';

/// Interni APS P1 Callable smoke test — scenariji + rough capacity.
///
/// Ulaz: [ApsDebugHubScreen] tab P1 (Registracije → bug ikona).
/// **Callable-only** — bez direktnog Firestore write na `aps_*`.
class ApsP1DebugScreen extends StatefulWidget {
  const ApsP1DebugScreen({
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
  State<ApsP1DebugScreen> createState() => _ApsP1DebugScreenState();
}

class _ApsP1DebugScreenState extends State<ApsP1DebugScreen>
    with AutomaticKeepAliveClientMixin {
  final ApsP0DebugService _svc = ApsP0DebugService();
  bool _busy = false;
  bool _loadingContext = true;
  ApsP0CallResult? _lastResult;
  String? _runningCallableName;
  bool _resultPanelExpanded = true;

  String _uid = '';
  String _role = '';
  String _userPlantKey = '';

  late final TextEditingController _companyIdCtrl;
  late final TextEditingController _plantKeyCtrl;
  late final TextEditingController _wrongCompanyCtrl;
  late final TextEditingController _demandIdCtrl;
  late final TextEditingController _scenarioIdCtrl;
  late final TextEditingController _dueDateCtrl;
  late final TextEditingController _periodStartCtrl;
  late final TextEditingController _periodEndCtrl;
  late final TextEditingController _minutesPerUnitCtrl;

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
    _demandIdCtrl = TextEditingController();
    _scenarioIdCtrl = TextEditingController();
    _applySharedToControllers();
    final now = DateTime.now().toUtc();
    final monthEnd = DateTime.utc(now.year, now.month + 1, 0);
    _dueDateCtrl = TextEditingController(text: monthEnd.toIso8601String());
    _periodStartCtrl = TextEditingController(
      text: DateTime.utc(now.year, now.month, 1).toIso8601String(),
    );
    _periodEndCtrl = TextEditingController(text: monthEnd.toIso8601String());
    _minutesPerUnitCtrl = TextEditingController(text: '5');
    _loadUserContext();
  }

  @override
  void didUpdateWidget(ApsP1DebugScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedInHub && widget.sharedState != null) {
      _applySharedToControllers();
    }
  }

  void _applySharedToControllers() {
    final shared = widget.sharedState;
    if (shared == null) return;
    if (shared.lastDemandId.isNotEmpty) {
      _demandIdCtrl.text = shared.lastDemandId;
    }
    if (shared.lastScenarioId.isNotEmpty) {
      _scenarioIdCtrl.text = shared.lastScenarioId;
    }
  }

  void _publishShared({
    String? lastDemandId,
    String? lastScenarioId,
    String? lastScenarioItemId,
  }) {
    if (!widget.embedInHub || widget.sharedState == null) return;
    widget.sharedState!.applyPatch(
      lastDemandId: lastDemandId ?? _demandIdCtrl.text.trim(),
      lastScenarioId: lastScenarioId ?? _scenarioIdCtrl.text.trim(),
      lastScenarioItemId: lastScenarioItemId,
    );
    widget.onSharedStateChanged?.call();
  }

  @override
  void dispose() {
    _companyIdCtrl.dispose();
    _plantKeyCtrl.dispose();
    _wrongCompanyCtrl.dispose();
    _demandIdCtrl.dispose();
    _scenarioIdCtrl.dispose();
    _dueDateCtrl.dispose();
    _periodStartCtrl.dispose();
    _periodEndCtrl.dispose();
    _minutesPerUnitCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _companyData => widget.companyData;

  bool get _hasAdvancedPlanning =>
      ProductionModuleKeys.hasAdvancedPlanningModule(_companyData);

  bool get _hasScenarioPlanning =>
      ProductionModuleKeys.hasModule(_companyData, ProductionModuleKeys.apsScenarioPlanning);

  bool get _callableAccessOk => ProductionAccessHelper.canAccessApsP1Callable(
    role: _role,
    companyData: _companyData,
  );

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
      _userPlantKey = _plantKeyFromUser(data);
      if (_plantKeyCtrl.text.trim().isEmpty && _userPlantKey.isNotEmpty) {
        _plantKeyCtrl.text = _userPlantKey;
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

  String _uniqueCode(String prefix) {
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
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
        final id = (result.data!['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          switch (result.callableName) {
            case 'createApsDemand':
              _demandIdCtrl.text = id;
              _publishShared(lastDemandId: id);
            case 'createApsScenario':
              _scenarioIdCtrl.text = id;
              _publishShared(lastScenarioId: id);
            case 'addDemandToApsScenario':
              _publishShared(lastScenarioItemId: id);
          }
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

  Map<String, dynamic> _sampleDemandPayload({String? companyId, String? plantKey}) {
    return {
      ..._basePayload(companyId: companyId, plantKey: plantKey),
      'demandCode': _uniqueCode('DEM'),
      'demandName': 'Testna potražnja',
      'demandType': 'manual',
      'quantity': 100,
      'quantityUom': 'pcs',
      'dueDate': _dueDateCtrl.text.trim(),
      'status': 'active',
      'estimatedMinutesPerUnit': double.tryParse(_minutesPerUnitCtrl.text.trim()) ?? 5,
      'isActive': true,
    };
  }

  Map<String, dynamic> _sampleScenarioPayload({String? companyId, String? plantKey}) {
    return {
      ..._basePayload(companyId: companyId, plantKey: plantKey),
      'scenarioCode': _uniqueCode('SC'),
      'scenarioName': 'Scenarij za test',
      'periodStart': _periodStartCtrl.text.trim(),
      'periodEnd': _periodEndCtrl.text.trim(),
      'isActive': true,
    };
  }

  Widget _wrapScaffold({required Widget body, PreferredSizeWidget? appBar}) {
    if (widget.embedInHub) return body;
    return Scaffold(
      appBar: appBar ??
          AppBar(
            title: const Text('APS P1 Debug / Internal'),
            backgroundColor: Colors.deepOrange.shade900,
          ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loadingContext) {
      return _wrapScaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
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

    return _wrapScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                _banner(
                  'P1 — Callable-only (demands, scenarios, rough capacity). '
                  'Bez Gantt/solver/AI/MES release.',
                  Colors.deepOrange.shade100,
                ),
                if (!_callableAccessOk)
                  _banner(
                    'P1 gate: advanced_planning=$_hasAdvancedPlanning, '
                    'aps_scenario_planning=$_hasScenarioPlanning, '
                    'uloga=${ProductionAccessHelper.canManageApsMasterData(_role) ? "OK" : "NE"}.',
                    Colors.amber.shade100,
                  ),
                _sectionContext(),
                _sectionDemands(),
                _sectionScenarios(),
                _sectionScenarioItems(),
                _sectionRoughCapacity(),
                _sectionNegativeTests(),
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
      title: '1. Kontekst (P1 gate)',
      children: [
        Text('uid: $_uid'),
        Text('role: $_role'),
        Text(
          'advanced_planning: $_hasAdvancedPlanning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _hasAdvancedPlanning ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        Text(
          'aps_scenario_planning: $_hasScenarioPlanning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _hasScenarioPlanning ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        Text('canAccessApsP1Callable: $_callableAccessOk'),
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
      ],
    );
  }

  Widget _sectionDemands() {
    return _Section(
      title: '2. APS Demands',
      children: [
        TextField(
          controller: _dueDateCtrl,
          decoration: const InputDecoration(
            labelText: 'dueDate (ISO)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _minutesPerUnitCtrl,
          decoration: const InputDecoration(
            labelText: 'estimatedMinutesPerUnit (create)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _demandIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last demand id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('Run create', () => _svc.createApsDemand(_sampleDemandPayload())),
        _btn('Run list', () => _svc.listApsDemands({..._basePayload(), 'isActive': true})),
        _btn('Run update', () {
          return _svc.updateApsDemand({
            ..._basePayload(),
            'id': _demandIdCtrl.text.trim(),
            'demandName': 'Debug updated ${DateTime.now().toIso8601String()}',
          });
        }),
      ],
    );
  }

  Widget _sectionScenarios() {
    return _Section(
      title: '3. APS Scenarios',
      children: [
        TextField(
          controller: _periodStartCtrl,
          decoration: const InputDecoration(
            labelText: 'periodStart (ISO)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _periodEndCtrl,
          decoration: const InputDecoration(
            labelText: 'periodEnd (ISO)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _scenarioIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last scenario id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('Run create', () => _svc.createApsScenario(_sampleScenarioPayload())),
        _btn('Run list', () => _svc.listApsScenarios({..._basePayload(), 'isActive': true})),
        _btn('Run update', () {
          return _svc.updateApsScenario({
            ..._basePayload(),
            'id': _scenarioIdCtrl.text.trim(),
            'scenarioName': 'Debug scenario updated',
          });
        }),
      ],
    );
  }

  Widget _sectionScenarioItems() {
    return _Section(
      title: '4. Scenario items',
      children: [
        _btn('addDemandToApsScenario', () {
          return _svc.addDemandToApsScenario({
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
            'demandId': _demandIdCtrl.text.trim(),
          });
        }),
        _btn('listApsScenarioItems', () {
          return _svc.listApsScenarioItems({
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
          });
        }),
        _btn('removeDemandFromApsScenario', () {
          return _svc.removeDemandFromApsScenario({
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
            'demandId': _demandIdCtrl.text.trim(),
          });
        }),
        _btn('P1-23 dupli add', () async {
          final body = {
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
            'demandId': _demandIdCtrl.text.trim(),
          };
          await _svc.addDemandToApsScenario(body);
          return _svc.addDemandToApsScenario(body);
        }),
      ],
    );
  }

  Widget _sectionRoughCapacity() {
    return _Section(
      title: '5. Rough capacity',
      children: [
        _btn('calculateApsRoughCapacity', () {
          return _svc.calculateApsRoughCapacity({
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
          });
        }),
        _btn('listApsCapacityWarnings', () {
          return _svc.listApsCapacityWarnings({
            ..._basePayload(),
            'scenarioId': _scenarioIdCtrl.text.trim(),
          });
        }),
      ],
    );
  }

  Widget _sectionNegativeTests() {
    return _Section(
      title: '6. Negativni testovi (P1-40 / P1-50 / P1-51)',
      children: [
        TextField(
          controller: _wrongCompanyCtrl,
          decoration: const InputDecoration(
            labelText: 'wrong companyId (P1-40)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _btn('P1-40 wrong companyId → create demand', () {
          return _svc.createApsDemand(
            _sampleDemandPayload(companyId: _wrongCompanyCtrl.text.trim()),
          );
        }),
        const Divider(height: 24),
        _btn('P1-50 invalid period → create scenario', () {
          return _svc.createApsScenario({
            ..._sampleScenarioPayload(),
            'periodStart': _periodEndCtrl.text.trim(),
            'periodEnd': _periodStartCtrl.text.trim(),
          });
        }),
        _btn('P1-51 quantity=0 → create demand', () {
          return _svc.createApsDemand({
            ..._sampleDemandPayload(),
            'quantity': 0,
          });
        }),
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

  Widget _btn(String label, Future<ApsP0CallResult> Function() action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: _busy
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
