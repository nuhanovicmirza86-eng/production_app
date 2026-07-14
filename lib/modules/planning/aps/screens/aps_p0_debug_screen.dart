import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../services/aps_p0_debug_service.dart';

/// Interni APS P0 Callable smoke test — **nije** produkcijski UI.
///
/// Ulaz: samo s [PendingUsersScreen] (Registracije) → bug ikona.
/// Vidljivo samo za `production_manager`, `admin`, `super_admin`.
/// **`production_operator` nema Registracije** — negativni role test (T-10) nije ovim putem.
/// Ne koristi direktan Firestore write/read na `aps_*`.
class ApsP0DebugScreen extends StatefulWidget {
  const ApsP0DebugScreen({
    super.key,
    required this.companyData,
    this.embedInHub = false,
  });

  final Map<String, dynamic> companyData;

  /// Kad je u [ApsDebugHubScreen] tabu — bez vlastitog Scaffold/AppBar.
  final bool embedInHub;

  @override
  State<ApsP0DebugScreen> createState() => _ApsP0DebugScreenState();
}

class _ApsP0DebugScreenState extends State<ApsP0DebugScreen> {
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
  late final TextEditingController _resourceIdCtrl;
  late final TextEditingController _calendarIdCtrl;
  late final TextEditingController _constraintIdCtrl;
  late final TextEditingController _profileIdCtrl;
  late final TextEditingController _extensionIdCtrl;
  late final TextEditingController _routingIdCtrl;
  late final TextEditingController _routingVersionCtrl;
  late final TextEditingController _operationKeyCtrl;
  late final TextEditingController _wrongCompanyCtrl;

  @override
  void initState() {
    super.initState();
    final cid = (widget.companyData['companyId'] ?? widget.companyData['id'] ?? '')
        .toString()
        .trim();
    _companyIdCtrl = TextEditingController(text: cid);
    _plantKeyCtrl = TextEditingController();
    _resourceIdCtrl = TextEditingController();
    _calendarIdCtrl = TextEditingController();
    _constraintIdCtrl = TextEditingController();
    _profileIdCtrl = TextEditingController();
    _extensionIdCtrl = TextEditingController();
    _routingIdCtrl = TextEditingController();
    _routingVersionCtrl = TextEditingController(text: 'v1');
    _operationKeyCtrl = TextEditingController();
    _wrongCompanyCtrl = TextEditingController(text: 'WRONG_TENANT_ID');
    _loadUserContext();
  }

  @override
  void dispose() {
    _companyIdCtrl.dispose();
    _plantKeyCtrl.dispose();
    _resourceIdCtrl.dispose();
    _calendarIdCtrl.dispose();
    _constraintIdCtrl.dispose();
    _profileIdCtrl.dispose();
    _extensionIdCtrl.dispose();
    _routingIdCtrl.dispose();
    _routingVersionCtrl.dispose();
    _operationKeyCtrl.dispose();
    _wrongCompanyCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _companyData => widget.companyData;

  bool get _hasAdvancedPlanning =>
      ProductionModuleKeys.hasAdvancedPlanningModule(_companyData);

  bool get _callableAccessOk =>
      ProductionAccessHelper.canAccessApsP0Callable(
        role: _role,
        companyData: _companyData,
      );

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingContext = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
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
            case 'createApsResource':
              _resourceIdCtrl.text = id;
            case 'createApsCalendar':
              _calendarIdCtrl.text = id;
            case 'createApsConstraint':
              _constraintIdCtrl.text = id;
            case 'createApsObjectiveProfile':
              _profileIdCtrl.text = id;
            case 'createApsRoutingExtension':
              _extensionIdCtrl.text = id;
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

  String _uniqueCode(String prefix) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$t';
  }

  Map<String, dynamic> _sampleResourcePayload({
    String? companyId,
    String? plantKey,
    String? resourceType,
    bool omitPlantKey = false,
  }) {
    final base = _basePayload(companyId: companyId, plantKey: plantKey);
    if (omitPlantKey) base.remove('plantKey');
    return {
      ...base,
      'resourceType': resourceType ?? 'machine',
      'resourceCode': _uniqueCode('APS-T-M'),
      'resourceName': 'Debug test resurs',
      'capacityMode': 'finite',
      'isActive': true,
    };
  }

  Widget _wrapScaffold({required Widget body, PreferredSizeWidget? appBar}) {
    if (widget.embedInHub) return body;
    return Scaffold(
      appBar: appBar ??
          AppBar(
            title: const Text('APS P0 Debug / Internal'),
            backgroundColor: Colors.orange.shade900,
          ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return _wrapScaffold(
        appBar: AppBar(
          title: const Text('APS P0 Debug / Internal'),
          backgroundColor: Colors.orange.shade900,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_screenAccessAllowed(_role)) {
      return _wrapScaffold(
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nemaš pristup internom APS P0 debug alatu.\n'
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
                  'Interni alat — samo Callable smoke test. Nije APS hub. '
                  'Bez direktnog Firestore pristupa na aps_*. '
                  'Rezultat svakog klika prikazuje se u panelu ispod.',
                  Colors.orange.shade100,
                ),
                if (!_callableAccessOk)
                  _banner(
                    'Callable gate (oba uslova): '
                    'modul advanced_planning=$_hasAdvancedPlanning, '
                    'uloga=${ProductionAccessHelper.canManageApsMasterData(_role) ? "OK" : "NE"}. '
                    'Bez modula Callable vraća permission-denied (T-01).',
                    Colors.amber.shade100,
                  ),
                _sectionContext(),
                _sectionGateTests(),
                _sectionTenantPlant(),
                _sectionResource(),
                _sectionCalendar(),
                _sectionConstraint(),
                _sectionObjectiveProfile(),
                _sectionRoutingExtension(),
                _sectionAuditNote(),
              ],
            ),
          ),
          _buildLastResultPanel(),
        ],
      ),
    );
  }

  static bool _screenAccessAllowed(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    return ProductionAccessHelper.canManageApsMasterData(r) ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleSuperAdmin;
  }

  Widget _banner(String text, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _sectionContext() {
    return _Section(
      title: '1. Current user context',
      children: [
        Text('uid: $_uid'),
        Text('role: $_role (${ProductionAccessHelper.displayRoleLabel(_role)})'),
        Text('user plantKey: ${_userPlantKey.isEmpty ? "—" : _userPlantKey}'),
        Text(
          'modul advanced_planning (kompanija): $_hasAdvancedPlanning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _hasAdvancedPlanning ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        Text('canManageApsMasterData (uloga): ${ProductionAccessHelper.canManageApsMasterData(_role)}'),
        Text('canAccessApsP0Callable (modul + uloga): $_callableAccessOk'),
        const SizedBox(height: 8),
        TextField(
          controller: _companyIdCtrl,
          decoration: const InputDecoration(
            labelText: 'companyId (test tenant)',
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

  Widget _sectionGateTests() {
    return _Section(
      title: '2. Module / role gate tests',
      children: [
        _btn('T-01 sim: create (trenutni modul/rola)', () {
          return _svc.createApsResource(_sampleResourcePayload());
        }),
        _btn('create bez plantKey (T-70 invalid)', () {
          return _svc.createApsResource(
            _sampleResourcePayload(omitPlantKey: true),
          );
        }),
        _btn('create invalid resourceType (T-71)', () {
          return _svc.createApsResource({
            ..._sampleResourcePayload(),
            'resourceType': 'invalid_type',
          });
        }),
      ],
    );
  }

  Widget _sectionTenantPlant() {
    return _Section(
      title: '3–4. Tenant / plant scope',
      children: [
        TextField(
          controller: _wrongCompanyCtrl,
          decoration: const InputDecoration(
            labelText: 'wrong companyId (T-20)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _btn('T-20 wrong companyId → create', () {
          return _svc.createApsResource(
            _sampleResourcePayload(companyId: _wrongCompanyCtrl.text.trim()),
          );
        }),
        _btn('T-30 wrong plantKey → create', () {
          return _svc.createApsResource(
            _sampleResourcePayload(plantKey: 'WRONG_PLANT_KEY'),
          );
        }),
        _btn('T-31 list (valid scope)', () {
          return _svc.listApsResources({
            ..._basePayload(),
            'isActive': true,
          });
        }),
      ],
    );
  }

  Widget _sectionResource() {
    return _Section(
      title: '5. APS Resource',
      children: [
        TextField(
          controller: _resourceIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last resource id (update)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _btn('Run create', () {
          return _svc.createApsResource(_sampleResourcePayload());
        }),
        _btn('Run list', () {
          return _svc.listApsResources({..._basePayload(), 'isActive': true});
        }),
        _btn('Run update', () {
          final id = _resourceIdCtrl.text.trim();
          return _svc.updateApsResource({
            ..._basePayload(),
            'id': id,
            'resourceName': 'Debug updated ${DateTime.now().toIso8601String()}',
          });
        }),
        _btn('T-72 duplicate resourceCode', () async {
          const code = 'APS-DUP-TEST-CODE';
          await _svc.createApsResource({
            ..._sampleResourcePayload(),
            'resourceCode': code,
          });
          return _svc.createApsResource({
            ..._sampleResourcePayload(),
            'resourceCode': code,
          });
        }),
        _btnClearResult(),
      ],
    );
  }

  Widget _sectionCalendar() {
    return _Section(
      title: '6. APS Calendar',
      children: [
        TextField(
          controller: _calendarIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last calendar id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('Run create', () {
          return _svc.createApsCalendar({
            ..._basePayload(),
            'calendarName': 'Debug kalendar ${_uniqueCode("")}',
            'timezone': 'Europe/Sarajevo',
            'isActive': true,
            'workingDays': [1, 2, 3, 4, 5],
            'shifts': [
              {
                'shiftKey': 'first',
                'start': '06:00',
                'end': '14:00',
                'validDays': [1, 2, 3, 4, 5],
              },
            ],
            'breaks': [],
            'holidays': [],
            'exceptions': [],
          });
        }),
        _btn('Run list', () {
          return _svc.listApsCalendars({..._basePayload(), 'isActive': true});
        }),
        _btn('Run update', () {
          return _svc.updateApsCalendar({
            ..._basePayload(),
            'id': _calendarIdCtrl.text.trim(),
            'calendarName': 'Debug updated calendar',
          });
        }),
        _btnClearResult(),
      ],
    );
  }

  Widget _sectionConstraint() {
    return _Section(
      title: '7. APS Constraint',
      children: [
        TextField(
          controller: _constraintIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last constraint id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('Run create (hard)', () {
          return _svc.createApsConstraint({
            ..._basePayload(),
            'constraintType': 'resource_capacity',
            'severity': 'hard',
            'isActive': true,
            'displayName': 'Debug constraint',
          });
        }),
        _btn('T-73 soft bez weight', () {
          return _svc.createApsConstraint({
            ..._basePayload(),
            'constraintType': 'delivery_due_date',
            'severity': 'soft',
            'isActive': true,
          });
        }),
        _btn('Run list', () {
          return _svc.listApsConstraints({..._basePayload(), 'isActive': true});
        }),
        _btn('Run update', () {
          return _svc.updateApsConstraint({
            ..._basePayload(),
            'id': _constraintIdCtrl.text.trim(),
            'displayName': 'Debug constraint updated',
          });
        }),
        _btnClearResult(),
      ],
    );
  }

  Widget _sectionObjectiveProfile() {
    return _Section(
      title: '8. APS Objective Profile',
      children: [
        TextField(
          controller: _profileIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last profile id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('Run create', () {
          return _svc.createApsObjectiveProfile({
            ..._basePayload(),
            'profileName': 'Debug profil ${_uniqueCode("")}',
            'isActive': true,
            'objectives': {
              'minimizeLateOrders': 'high',
              'minimizeMakespan': 'medium',
            },
          });
        }),
        _btn('T-74 prazan objectives', () {
          return _svc.createApsObjectiveProfile({
            ..._basePayload(),
            'profileName': 'Invalid',
            'isActive': true,
            'objectives': {},
          });
        }),
        _btn('Run list', () {
          return _svc.listApsObjectiveProfiles({
            ..._basePayload(),
            'isActive': true,
          });
        }),
        _btn('Run update', () {
          return _svc.updateApsObjectiveProfile({
            ..._basePayload(),
            'id': _profileIdCtrl.text.trim(),
            'profileName': 'Debug profil updated',
          });
        }),
        _btnClearResult(),
      ],
    );
  }

  Widget _sectionRoutingExtension() {
    return _Section(
      title: '9. APS Routing Extension',
      children: [
        TextField(
          controller: _routingIdCtrl,
          decoration: const InputDecoration(
            labelText: 'routingId (routing_headers)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _routingVersionCtrl,
          decoration: const InputDecoration(
            labelText: 'routingVersion',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _operationKeyCtrl,
          decoration: const InputDecoration(
            labelText: 'operationKey (= operationCode)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _extensionIdCtrl,
          decoration: const InputDecoration(
            labelText: 'last extension id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        _btn('T-40 routing ne postoji', () {
          return _svc.createApsRoutingExtension({
            ..._basePayload(),
            'routingId': 'NONEXISTENT_ROUTING_ID',
            'routingVersion': 'v1',
            'operationKey': 'OP10',
            'isActive': true,
          });
        }),
        _btn('T-41 invalid operationKey', () {
          return _svc.createApsRoutingExtension({
            ..._basePayload(),
            'routingId': _routingIdCtrl.text.trim(),
            'routingVersion': _routingVersionCtrl.text.trim(),
            'operationKey': 'INVALID_OPERATION_KEY',
            'isActive': true,
          });
        }),
        _btn('Run create (valid fixture)', () {
          return _svc.createApsRoutingExtension({
            ..._basePayload(),
            'routingId': _routingIdCtrl.text.trim(),
            'routingVersion': _routingVersionCtrl.text.trim(),
            'operationKey': _operationKeyCtrl.text.trim(),
            'isActive': true,
            if (_resourceIdCtrl.text.trim().isNotEmpty)
              'eligibleResourceIds': [_resourceIdCtrl.text.trim()],
            'standardRunSecondsPerUnit': 60,
          });
        }),
        _btn('Run list', () {
          final body = {..._basePayload(), 'isActive': true};
          final rid = _routingIdCtrl.text.trim();
          if (rid.isNotEmpty) body['routingId'] = rid;
          return _svc.listApsRoutingExtensions(body);
        }),
        _btn('Run update', () {
          return _svc.updateApsRoutingExtension({
            ..._basePayload(),
            'id': _extensionIdCtrl.text.trim(),
            'notes': 'Debug update ${DateTime.now().toIso8601String()}',
          });
        }),
        _btnClearResult(),
      ],
    );
  }

  Widget _sectionAuditNote() {
    return _Section(
      title: '10. Audit (T-60 — ručno u Console)',
      children: const [
        Text(
          'Nakon uspješnog create/update provjeri u Firebase Console:\n'
          'company_audit_logs → action prefiks aps_*\n'
          '(Ekran namjerno ne čita Firestore — samo Callable.)',
          style: TextStyle(fontSize: 13),
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
              InkWell(
                onTap: () {
                  if (_busy || result != null) {
                    setState(() => _resultPanelExpanded = !_resultPanelExpanded);
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Last result / last error',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_busy) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _resultPanelExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ],
                ),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(
                    'Poziv u tijeku: ${_runningCallableName ?? "…"}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    result.summaryLine,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: result.success
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    '— klikni bilo koje dugme; rezultat se prikazuje ovdje —',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (_resultPanelExpanded && !_busy && result != null) ...[
                const SizedBox(height: 4),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _resultPanelExpanded = true),
                    child: const Text('Proširi'),
                  ),
                  TextButton(
                    onPressed: _busy || result == null ? null : _clearResult,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btnClearResult() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: _busy ? null : _clearResult,
          child: const Text('Clear result'),
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
                  setState(() {
                    _runningCallableName = label;
                  });
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

/// Vidljivost ulaza u debug ekran (Registracije → bug ikona).
/// Samo uloge s pristupom Registracijama — ne `production_operator`.
bool apsP0DebugEntryAllowed(String role) {
  return _ApsP0DebugScreenState._screenAccessAllowed(
    ProductionAccessHelper.normalizeRole(role),
  );
}
