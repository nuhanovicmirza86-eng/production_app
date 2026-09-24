import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../modules/production/bom/bom_item_traceability.dart';
import '../../../modules/production/bom/services/bom_service.dart';
import '../../../modules/production/bom/widgets/omp_lot_traceability_help.dart';
import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../core/user_display_label.dart';
import '../../../modules/production/station_pages/models/production_evidence_config.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_pages/services/production_station_config_callable_service.dart';
import '../../../modules/production/station_pages/utils/production_operator_profile_resolver.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_work/services/production_station_work_session_service.dart';
import '../../station_evidence/screens/profile_driven_evidence_detail_screen.dart';
import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../../profile_driven_structured_runtime/models/structured_repeatable_row.dart';
import '../../profile_driven_structured_runtime/services/production_evidence_entity_search_service.dart';
import '../../profile_driven_structured_runtime/utils/structured_datetime_value.dart';
import '../../profile_driven_structured_runtime/widgets/structured_datetime_field.dart';
import '../../profile_driven_structured_runtime/widgets/structured_header_section.dart';
import '../../profile_driven_structured_runtime/widgets/structured_repeatable_table_section.dart';
import '../services/catalog_evidence_session_service.dart';
import '../services/omp_wms_lot_lookup_service.dart';
import '../utils/catalog_evidence_help_texts.dart';
import '../utils/catalog_evidence_table_payload.dart';
import '../utils/catalog_evidence_start_access.dart';
import '../utils/cleaning_checklist_mode.dart';
import '../utils/cleaning_handoff_persistence.dart';
import '../utils/controlled_evidence_person_role_keys.dart';
import '../utils/line_clearance_line_name.dart';
import '../utils/line_clearance_verification.dart';
import '../utils/logged_in_performer.dart';
import '../utils/evidence_input_empty.dart';
import '../utils/evidence_outcome_action_helper.dart';
import '../utils/final_control_bom_product_picker.dart';
import '../utils/operation_material_preparation_bom_picker.dart';
import '../utils/recent_production_operators_store.dart';
import '../utils/workspace_5s_cleaning_fields.dart';
import '../widgets/catalog_evidence_records_table.dart';
import '../widgets/catalog_evidence_viewport_split.dart';
import '../widgets/line_clearance_site_verification_card.dart';
import '../widgets/omp_wms_lot_section.dart';

/// M1-F3 — generički operator runtime za Admin-konfigurisane catalog evidence stanice.
class CatalogEvidenceStationScreen extends StatefulWidget {
  const CatalogEvidenceStationScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.profileCatalogVersion = 0,
    this.onCloseStation,
    this.preloadedActiveSession,
    this.skipLiveCatalogRefresh = false,
  })  : evidenceConfig = null;

  const CatalogEvidenceStationScreen.companyEvidence({
    super.key,
    required this.companyData,
    required this.evidenceConfig,
    required this.profile,
    this.profileCatalogVersion = 0,
    this.onCloseStation,
    this.preloadedActiveSession,
    this.skipLiveCatalogRefresh = false,
  })  : stationConfig = null;

  final Map<String, dynamic> companyData;
  final ProductionStationConfig? stationConfig;
  final ProductionEvidenceConfig? evidenceConfig;
  final ProductionStationProfileCatalogEntry profile;
  /// Hub/live katalog verzija — za M1-I3-H1 refresh forme (npr. Mašina).
  final int profileCatalogVersion;
  final VoidCallback? onCloseStation;
  /// HOTFIX-21 — već učitana aktivna sesija (deep-link verifikacije).
  final ActiveStructuredSessionResult? preloadedActiveSession;
  /// HOTFIX-21 — ne čekati listu kataloga prije prikaza forme.
  final bool skipLiveCatalogRefresh;

  bool get isCompanyEvidence => evidenceConfig != null;

  @override
  State<CatalogEvidenceStationScreen> createState() =>
      _CatalogEvidenceStationScreenState();
}

class _CatalogEvidenceStationScreenState
    extends State<CatalogEvidenceStationScreen> {
  final _sessionStream = ProductionStationWorkSessionService();
  final _catalogService = CatalogEvidenceSessionService();
  final _searchService = ProductionEvidenceEntitySearchCallableService();
  final _profileCatalogService = ProductionStationConfigCallableService();
  final _bomService = BomService();

  StructuredProfileSessionState _state = StructuredProfileSessionState();
  final Map<String, StructuredEntitySelection?> _headerEntitySelections = {};
  final Map<String, String?> _headerEnumSelections = {};
  final Map<String, DateTime?> _headerDateTimes = {};
  final Map<String, TextEditingController> _headerTextControllers = {};

  bool _busy = false;
  String? _hydratedSessionId;
  String _plantDisplayLabel = '';
  ProductionStationWorkSession? _closedSession;
  ProductionStationWorkSession? _callableActiveSession;
  Map<String, dynamic> _savedHandoffFieldValues = const {};
  List<ProductionStationWorkSession> _callableClosedSessions = const [];
  bool _recordsLoading = false;
  int _recordsLimit = catalogEvidenceDefaultRecordLimit;
  ProductionStationProfileCatalogEntry? _runtimeProfile;
  int _profileCatalogVersion = 0;
  String? _lastFirstPieceOrderIdApplied;
  String? _lastMaterialPrepOrderIdApplied;
  List<StructuredEntitySearchResult> _recentProductionOperators = const [];
  List<StructuredEntitySearchResult> _plantWorkplaceZones = const [];

  /// M1-I9-B — PRIMARY BOM picker za operation_material_preparation.
  OmpBomPickerState _ompBomPicker = const OmpBomPickerState();
  String? _ompBomLoadedForProductId;
  String? _lastOmpMaterialIdForPrefill;

  /// M1-I14-F — PRIMARY BOM picker proizvoda za Finalna kontrola / Kontrolisani komadi.
  OmpBomPickerState _fcBomPicker = const OmpBomPickerState();
  String? _fcBomLoadedForProductId;

  bool get _supportsOsWindowChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey => widget.isCompanyEvidence
      ? widget.evidenceConfig!.plantKey.trim()
      : widget.stationConfig!.assignedPlantKey.trim();

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _plantAccessOk {
    if (ProductionAccessHelper.isCompanyWideContextRole(_userRole)) {
      return true;
    }
    if (_userPlantKey.isEmpty || _plantKey.isEmpty) return false;
    return _userPlantKey == _plantKey;
  }

  /// Operater kvaliteta nema Firestore read na sesije — koristi Callable.
  /// HOTFIX-21 deep-link također koristi već učitanu sesiju, bez čekanja streama.
  bool get _usesCallableEvidenceRuntime =>
      widget.preloadedActiveSession != null ||
      (widget.isCompanyEvidence &&
          ProductionAccessHelper.canAccessQualityControlEvidenceHub(_userRole));

  ProductionStationProfileCatalogEntry get _effectiveProfile =>
      _runtimeProfile ?? widget.profile;

  bool get _isStructuredLite => _effectiveProfile.isStructuredLiteInputModel;

  List<StructuredRepeatableTableDefinition> get _tables =>
      _effectiveProfile.repeatableTableDefinitions;

  bool get _isPackagingControl =>
      _effectiveProfile.profileKey.trim() == 'packaging_control';

  bool get _isFirstPieceApproval =>
      _effectiveProfile.profileKey.trim() == 'first_piece_approval';

  bool get _isInProcessQualityCheck =>
      _effectiveProfile.profileKey.trim() == 'in_process_quality_check';

  bool get _isFinalControl =>
      _effectiveProfile.profileKey.trim() == 'final_control';

  bool get _isLineClearance =>
      isOperatorStartedLineClearanceProfile(_effectiveProfile.profileKey);

  bool get _canStartEvidence => canStartCatalogEvidenceSession(
        profileKey: _effectiveProfile.profileKey,
        userRole: _userRole,
        runtimeAllowedRoles: widget.evidenceConfig?.runtimeAllowedRoles ??
            widget.stationConfig?.runtimeAllowedRoles ??
            const [],
      );

  bool get _isWorkspace5sCleaning =>
      _effectiveProfile.profileKey.trim() == 'workspace_5s_cleaning';

  bool get _hasSignedLoggedInVerifier =>
      _effectiveProfile.hasSignedLoggedInVerifier;

  bool get _canSignVerification {
    if (!_hasSignedLoggedInVerifier) return true;
    return _effectiveVerifierRoleKeys.contains(_userRole);
  }

  String get _performedByDisplayName {
    final snap = sanitizeEvidenceFormInput(
      (_state.fieldValues['performedByNameSnapshot'] ?? '').toString(),
    );
    if (snap.isNotEmpty) return snap;
    final label = sanitizeEvidenceFormInput(
      (_headerEntitySelections['performedByEmployeeId']?.displayLabel ?? '')
          .toString(),
    );
    return label;
  }

  bool get _lockPerformedByForVerifier =>
      _hasSignedLoggedInVerifier &&
      _canSignVerification &&
      _performedByDisplayName.isNotEmpty;

  bool get _autofillLoggedInPerformer =>
      shouldAutofillPerformedByFromLoggedInOperator(
        profileKey: _effectiveProfile.profileKey,
        userRole: _userRole,
      );

  bool get _lockPerformedByField => shouldLockPerformedByField(
        autofillFromLoggedInOperator: _autofillLoggedInPerformer,
        verifierHandoff: _lockPerformedByForVerifier,
      );

  bool get _lockCleaningHandoffHeader =>
      _lockPerformedByForVerifier &&
      (_isLineClearance || _isWorkspace5sCleaning);

  bool get _isLineClearanceVerifierHandoff =>
      _isLineClearance && _lockCleaningHandoffHeader;

  void _rememberSavedHandoff(Map<String, dynamic>? fieldValues) {
    _savedHandoffFieldValues = snapshotCleaningHandoffFieldValues(
      profileKey: _effectiveProfile.profileKey,
      fieldValues: fieldValues,
    );
  }

  void _restoreSavedHandoffIntoState() {
    restoreCleaningHandoffFieldValues(
      target: _state.fieldValues,
      preserved: _savedHandoffFieldValues,
    );
    mergeCleaningHandoffFieldValues(
      profileKey: _effectiveProfile.profileKey,
      target: _state.fieldValues,
      source: _callableActiveSession?.fieldValues,
    );
  }

  List<String> get _effectiveVerifierRoleKeys {
    return widget.evidenceConfig?.effectiveVerifierRoleKeys(
          _effectiveProfile.verifierRoleKeys,
        ) ??
        _effectiveProfile.verifierRoleKeys;
  }

  String get _cleaningChecklistMode {
    final profileKey = _effectiveProfile.profileKey;
    if (!profileSupportsCleaningChecklistMode(profileKey)) {
      return cleaningChecklistModeExtended;
    }
    return normalizeCleaningChecklistMode(
      widget.evidenceConfig?.cleaningChecklistMode,
      profileKey,
    );
  }

  bool get _isCleaningQuickList =>
      profileSupportsCleaningChecklistMode(_effectiveProfile.profileKey) &&
      _cleaningChecklistMode == cleaningChecklistModeQuick;

  Set<String> get _hiddenCleaningFieldKeys {
    final hidden = {
      ...hiddenCleaningChecklistFieldKeys(
        profileKey: _effectiveProfile.profileKey,
        mode: _cleaningChecklistMode,
        outcome: (_headerEnumSelections['outcome'] ??
                _state.fieldValues['outcome'] ??
                '')
            .toString(),
        fieldKeys: _effectiveProfile.structuredHeaderFields.map((f) => f.key),
      ),
    };
    if (_isLineClearance) {
      hidden.addAll(lineClearanceHiddenOrderFieldKeys);
      if (hasSelectedLineClearanceWorkCenter(
        workCenterId: _headerEntitySelections['workCenterId']?.entityId,
        fieldValues: _state.fieldValues,
      )) {
        hidden.add(lineClearanceLineNameFieldKey);
      }
    }
    return hidden;
  }

  void _applyLineClearanceLineNameFromWorkCenter() {
    if (!_isLineClearance) return;
    applyLineClearanceLineNameFromWorkCenter(
      fieldValues: _state.fieldValues,
      workCenter: _headerEntitySelections['workCenterId'],
      setLineNameText: (text) {
        final controller = _headerTextControllers.putIfAbsent(
          lineClearanceLineNameFieldKey,
          TextEditingController.new,
        );
        if (controller.text != text) {
          controller.text = text;
        }
      },
    );
  }

  bool get _isToolChangeover =>
      _effectiveProfile.profileKey.trim() == 'tool_changeover';

  bool get _isMaterialPreparation =>
      _effectiveProfile.profileKey.trim() == 'material_preparation';

  bool get _isOperationMaterialPreparation =>
      _effectiveProfile.profileKey.trim() == 'operation_material_preparation';

  bool get _isBatchMixing =>
      _effectiveProfile.profileKey.trim() == 'batch_mixing';

  /// I7 generička + I8 operation-bound — nalog → proizvod.
  bool get _isMaterialPrepFamily =>
      _isMaterialPreparation || _isOperationMaterialPreparation;

  /// M1-I15-C5 — BOM-first materijal / komponenta (OMP + MP + miješanje šarže).
  bool get _usesOmpBomMaterialPicker =>
      _isMaterialPrepFamily || _isBatchMixing;

  /// I4 + I8 — mašina ili radni sto.
  bool get _usesWorkPlaceContext =>
      _isInProcessQualityCheck || _isOperationMaterialPreparation;

  bool get _autoInspectorFromSession =>
      _isFirstPieceApproval || _isInProcessQualityCheck;

  String get _processControllerDisplayName =>
      UserDisplayLabel.fromSessionMap(widget.companyData);

  void _applyRuntimeProfile(ProductionStationProfileCatalogEntry profile) {
    _runtimeProfile = profile;
  }

  /// M1-I3-H1 — forma mora koristiti najnoviji live katalog (npr. polje Mašina).
  Future<void> _refreshLiveProfileCatalog() async {
    if (_companyId.isEmpty) return;
    try {
      final catalog = await _profileCatalogService.listProductionStationProfiles(
        companyId: _companyId,
      );
      final live = catalog.byKey(_effectiveProfile.profileKey);
      if (live == null || !live.isComplete) return;

      final refreshed = ProductionOperatorProfileResolver.resolveNewest(
        baseline: live,
        baselineCatalogVersion: catalog.catalogVersion,
        configSnapshot: widget.evidenceConfig?.profileSnapshot,
      );
      if (!mounted) return;
      final beforeKeys =
          _effectiveProfile.structuredHeaderFields.map((f) => f.key).toSet();
      final afterKeys = refreshed.structuredHeaderFields.map((f) => f.key).toSet();
      final changed = catalog.catalogVersion != _profileCatalogVersion ||
          beforeKeys.length != afterKeys.length ||
          !beforeKeys.containsAll(afterKeys);
      setState(() {
        _profileCatalogVersion = catalog.catalogVersion;
        _applyRuntimeProfile(refreshed);
        _restoreSavedHandoffIntoState();
        _syncHeaderControllersFromState();
        if (changed) {
          _ensureFirstPieceDefaults();
          _ensureFirstPieceInspectorFromSession();
          _ensurePackagingControllerFromSession();
          _syncInProcessWorkPlaceFields();
        }
      });
    } catch (_) {
      // Soft-fail — ostaje profil s kojim je ekran otvoren.
    }
  }

  @override
  void initState() {
    super.initState();
    _profileCatalogVersion = widget.profileCatalogVersion;
    _applyRuntimeProfile(
      widget.isCompanyEvidence
          ? ProductionOperatorProfileResolver.resolveNewest(
              baseline: widget.profile,
              baselineCatalogVersion: widget.profileCatalogVersion,
              configSnapshot: widget.evidenceConfig!.profileSnapshot,
            )
          : widget.profile,
    );
    unawaited(_loadPlantDisplayLabel());
    if (!widget.skipLiveCatalogRefresh) {
      unawaited(_refreshLiveProfileCatalog());
    }
    unawaited(_loadRecentProductionOperators());
    unawaited(_loadPlantWorkplaceZones());
    final preloaded = widget.preloadedActiveSession;
    if (preloaded != null && preloaded.session.isActive) {
      _callableActiveSession = preloaded.session;
      _hydrateFromSession(preloaded.session);
      if (preloaded.structuredTables.isNotEmpty) {
        _state = hydrateCatalogEvidenceState(
          fieldValues: preloaded.session.fieldValues,
          structuredTables: preloaded.structuredTables,
          profile: _effectiveProfile,
        );
        _syncHeaderControllersFromState();
      }
    }
    unawaited(_loadCallableEvidenceRuntime());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_supportsOsWindowChrome) {
        unawaited(windowManager.setFullScreen(true));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _headerTextControllers.values) {
      c.dispose();
    }
    if (_supportsOsWindowChrome) {
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  Future<void> _loadRecentProductionOperators() async {
    if (!_isInProcessQualityCheck || _companyId.isEmpty) return;
    final stored = await RecentProductionOperatorsStore.load(_companyId);
    if (stored.isEmpty) {
      if (!mounted) return;
      setState(() => _recentProductionOperators = const []);
      return;
    }
    List<StructuredEntitySearchResult> allowed = const [];
    try {
      allowed = await _searchService.searchPlantOperators(
        companyId: _companyId,
        query: '',
        assignedPlantKey: _plantKey,
        roleKeys: controlledEvidenceRoleKeysForPersonField(
          'productionOperatorEmployeeId',
        )!,
        recentIds: stored
            .map((e) => e.id.trim())
            .where((id) => id.isNotEmpty)
            .take(10)
            .toList(growable: false),
      );
    } catch (_) {
      allowed = const [];
    }
    final byId = {
      for (final e in allowed)
        if (e.id.trim().isNotEmpty) e.id.trim(): e,
    };
    final items = stored
        .map((e) => byId[e.id.trim()])
        .whereType<StructuredEntitySearchResult>()
        .toList(growable: false);
    if (!mounted) return;
    setState(() => _recentProductionOperators = items);
  }

  Future<void> _rememberProductionOperatorSelection(
    StructuredEntitySelection? selection,
  ) async {
    if (!_isInProcessQualityCheck || selection == null) return;
    await RecentProductionOperatorsStore.remember(
      companyId: _companyId,
      entityId: selection.entityId,
      displayLabel: selection.displayLabel,
    );
    await _loadRecentProductionOperators();
  }

  Future<void> _loadPlantDisplayLabel() async {
    if (_plantKey.isEmpty) return;
    final label = await CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    if (!mounted) return;
    setState(() => _plantDisplayLabel = label.trim());
  }

  Future<void> _loadCallableEvidenceRuntime() async {
    if (!widget.isCompanyEvidence || _companyId.isEmpty) return;
    if (!_usesCallableEvidenceRuntime) return;
    final evidenceConfigId = widget.evidenceConfig!.evidenceConfigId;
    final preloaded = widget.preloadedActiveSession;
    if (preloaded != null) {
      if (!mounted) return;
      setState(() {
        _callableActiveSession = preloaded.session;
        _recordsLoading = true;
      });
      try {
        final closed = await _catalogService.listClosedEvidenceSessions(
          companyId: _companyId,
          evidenceConfigId: evidenceConfigId,
          limit: _recordsLimit,
        );
        if (!mounted) return;
        setState(() {
          _callableClosedSessions = closed;
          _recordsLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _recordsLoading = false;
        });
      }
      return;
    }
    setState(() => _recordsLoading = true);
    try {
      ActiveStructuredSessionResult? active;
      try {
        active = await _catalogService.getActiveEvidenceSession(
          companyId: _companyId,
          evidenceConfigId: evidenceConfigId,
        );
      } catch (_) {
        active = null;
      }
      if (!mounted) return;
      setState(() {
        _callableActiveSession = active?.session;
      });
      final loaded = active;
      final session = loaded?.session;
      if (loaded != null && session != null && session.isActive) {
        _hydrateFromSession(session);
        if (loaded.structuredTables.isNotEmpty) {
          setState(() {
            _state = hydrateCatalogEvidenceState(
              fieldValues: session.fieldValues,
              structuredTables: loaded.structuredTables,
              profile: _effectiveProfile,
            );
            _syncHeaderControllersFromState();
            _ensurePackagingControllerFromSession();
            _ensureFirstPieceInspectorFromSession();
            _syncInProcessWorkPlaceFields();
          });
        }
      }
      unawaited(_reloadClosedEvidenceRecords());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _callableActiveSession = null;
        _callableClosedSessions = const [];
        _recordsLoading = false;
      });
    }
  }

  Future<void> _reloadClosedEvidenceRecords() async {
    if (!_usesCallableEvidenceRuntime || _companyId.isEmpty) return;
    setState(() => _recordsLoading = true);
    try {
      final closed = await _catalogService.listClosedEvidenceSessions(
        companyId: _companyId,
        evidenceConfigId: widget.evidenceConfig!.evidenceConfigId,
        limit: _recordsLimit,
      );
      if (!mounted) return;
      setState(() {
        _callableClosedSessions = closed;
        _recordsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _callableClosedSessions = const [];
        _recordsLoading = false;
      });
    }
  }

  Future<void> _closeStation() async {
    if (_supportsOsWindowChrome) {
      try {
        await windowManager.setFullScreen(false);
      } catch (_) {}
    }
    if (!mounted) return;
    if (widget.onCloseStation != null) {
      widget.onCloseStation!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productionStationWorkSessionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetFormForNewEvidence() {
    _state = StructuredProfileSessionState();
    _headerEntitySelections.clear();
    _headerEnumSelections.clear();
    _headerDateTimes.clear();
    _savedHandoffFieldValues = const {};
    _lastFirstPieceOrderIdApplied = null;
    for (final c in _headerTextControllers.values) {
      c.clear();
    }
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _ensureFirstPieceDefaults();
    _syncInProcessWorkPlaceFields();
    _syncHeaderControllersFromState();
  }

  /// M1-I3-D — odobrenje prvog komada: default 1 komad.
  void _ensureFirstPieceDefaults() {
    if (!_isFirstPieceApproval) return;
    if (_state.fieldValues['qtySubmitted'] != null) return;
    _state.fieldValues['qtySubmitted'] = 1;
  }

  void _ensureLoggedInPerformerFromSession() {
    if (!_autofillLoggedInPerformer) return;
    if (_lockPerformedByForVerifier) return;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) return;
    final name = loggedInPerformerDisplayName(widget.companyData);
    _state.fieldValues[performedByEmployeeFieldKey] = uid;
    if (name.isNotEmpty) {
      _state.fieldValues[performedByNameSnapshotFieldKey] = name;
    } else {
      _state.fieldValues.remove(performedByNameSnapshotFieldKey);
    }
    _headerEntitySelections[performedByEmployeeFieldKey] =
        StructuredEntitySelection(
      fieldKey: performedByEmployeeFieldKey,
      entityId: uid,
      displayLabel: name,
    );
  }

  /// Procesni kontrolor / Finalna kontrola = prijavljeni korisnik
  /// (M1-I2-F3 / F6 / HOTFIX-30).
  /// Samo [controllerEmployeeId] ide u payload — snapshot ime popunjava backend.
  void _ensurePackagingControllerFromSession() {
    if (!_isPackagingControl && !_isFinalControl) return;
    final name = _processControllerDisplayName.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    _state.fieldValues.remove('controllerNameSnapshot');
    if (uid.isEmpty) return;
    _state.fieldValues['controllerEmployeeId'] = uid;
    _headerEntitySelections['controllerEmployeeId'] = StructuredEntitySelection(
      fieldKey: 'controllerEmployeeId',
      entityId: uid,
      displayLabel: name.isNotEmpty ? name : 'Operater kvaliteta',
    );
  }

  /// M1-I3-E / M1-I4-C — kontrolor kvaliteta = prijavljeni korisnik (ne ručni search).
  /// Samo [inspectorEmployeeId] u payloadu — snapshot ime popunjava backend.
  void _ensureFirstPieceInspectorFromSession() {
    if (!_autoInspectorFromSession) return;
    final name = _processControllerDisplayName.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    _state.fieldValues.remove('inspectorNameSnapshot');
    if (uid.isEmpty) return;
    _state.fieldValues['inspectorEmployeeId'] = uid;
    _headerEntitySelections['inspectorEmployeeId'] = StructuredEntitySelection(
      fieldKey: 'inspectorEmployeeId',
      entityId: uid,
      displayLabel: name.isNotEmpty ? name : 'Operater kvaliteta',
    );
  }

  /// M1-I4-C / M1-I8-B — očisti polja drugog tipa mjesta rada.
  void _syncInProcessWorkPlaceFields() {
    if (!_usesWorkPlaceContext) return;
    final type = (_headerEnumSelections['workContextType'] ??
            _state.fieldValues['workContextType'] ??
            '')
        .toString()
        .trim();
    if (type == 'machine') {
      _headerEntitySelections.remove('workbenchId');
      _state.fieldValues.remove('workbenchId');
      _state.fieldValues.remove('workbenchNameSnapshot');
      _state.fieldValues.remove('workbenchCodeSnapshot');
    } else if (type == 'workbench') {
      _headerEntitySelections.remove('machineId');
      _state.fieldValues.remove('machineId');
      _state.fieldValues.remove('machineNameSnapshot');
      _state.fieldValues.remove('machineCodeSnapshot');
    }
  }

  /// M1-I4-C — sken/odabir naloga: proizvod (za linije) + mašina ako je tip = mašina.
  void _applyInProcessHeaderFromOrderSelection({
    bool forceFromOrder = false,
  }) {
    if (!_isInProcessQualityCheck) return;

    _state.fieldValues.remove('productionOrderCode');
    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');
    _state.fieldValues.remove('machineNameSnapshot');
    _state.fieldValues.remove('machineCodeSnapshot');
    _state.fieldValues.remove('workbenchNameSnapshot');
    _state.fieldValues.remove('workbenchCodeSnapshot');
    _state.fieldValues.remove('workLocationNameSnapshot');
    _state.fieldValues.remove('productionOperatorNameSnapshot');

    final order = _headerEntitySelections['productionOrderId'];
    if (order == null) {
      _lastFirstPieceOrderIdApplied = null;
      _headerEntitySelections.remove('productId');
      _fcBomPicker = const OmpBomPickerState();
      _fcBomLoadedForProductId = null;
      _ensureFirstPieceInspectorFromSession();
      _syncInProcessWorkPlaceFields();
      _stripNonOperatorEditableFieldValues();
      return;
    }
    final orderId = order.entityId.trim();
    final orderChanged = orderId != (_lastFirstPieceOrderIdApplied ?? '');
    final shouldApply = forceFromOrder || orderChanged;
    final raw = order.raw;

    // Proizvod nije header polje — drži se za nasljeđivanje u inspection_lines.
    final productId = (raw['productId'] ?? '').toString().trim();
    final productCode = (raw['productCode'] ?? '').toString().trim();
    final productName =
        (raw['productName'] ?? raw['displayName'] ?? '').toString().trim();
    final existingProduct =
        (_headerEntitySelections['productId']?.entityId ?? '').trim();
    if (productId.isNotEmpty && (shouldApply || existingProduct.isEmpty)) {
      final productRaw = {
        'id': productId,
        'productCode': productCode,
        'productName': productName,
        'displayName': productName,
      };
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: productId,
        displayLabel:
            StructuredEntitySearchResult.productDisplayLabel(productRaw),
        raw: productRaw,
      );
    }

    // Soft autofill proizvodnog operatera ako nalog nosi poznato polje.
    final existingOp =
        (_headerEntitySelections['productionOperatorEmployeeId']?.entityId ??
                '')
            .trim();
    final opId = (raw['productionOperatorEmployeeId'] ??
            raw['operatorEmployeeId'] ??
            raw['assignedOperatorId'] ??
            '')
        .toString()
        .trim();
    if (opId.isNotEmpty && (shouldApply || existingOp.isEmpty)) {
      final opName = (raw['productionOperatorName'] ??
              raw['operatorName'] ??
              raw['assignedOperatorName'] ??
              '')
          .toString()
          .trim();
      _state.fieldValues['productionOperatorEmployeeId'] = opId;
      _headerEntitySelections['productionOperatorEmployeeId'] =
          StructuredEntitySelection(
        fieldKey: 'productionOperatorEmployeeId',
        entityId: opId,
        displayLabel: opName.isNotEmpty ? opName : 'Proizvodni operater',
        raw: {
          'id': opId,
          'displayName': opName,
        },
      );
    }

    final type = (_headerEnumSelections['workContextType'] ??
            _state.fieldValues['workContextType'] ??
            '')
        .toString()
        .trim();
    if (type == 'machine' || type.isEmpty) {
      final machineId = (raw['machineId'] ?? '').toString().trim();
      final existingMachine =
          (_state.fieldValues['machineId'] ?? '').toString().trim();
      if (machineId.isNotEmpty && (shouldApply || existingMachine.isEmpty)) {
        final machineCode = (raw['machineCode'] ?? '').toString().trim();
        final machineName = (raw['machineName'] ?? '').toString().trim();
        final labelParts = <String>[
          if (machineCode.isNotEmpty) machineCode,
          if (machineName.isNotEmpty) machineName,
        ];
        final displayLabel = labelParts.isNotEmpty
            ? labelParts.join(' — ')
            : (machineName.isNotEmpty ? machineName : 'Mašina');
        _state.fieldValues['machineId'] = machineId;
        if (type.isEmpty) {
          _headerEnumSelections['workContextType'] = 'machine';
          _state.fieldValues['workContextType'] = 'machine';
        }
        _headerEntitySelections['machineId'] = StructuredEntitySelection(
          fieldKey: 'machineId',
          entityId: machineId,
          displayLabel: displayLabel,
          raw: {
            'id': machineId,
            'machineCode': machineCode,
            'machineName': machineName,
            'displayName': machineName,
          },
        );
      } else if (shouldApply && machineId.isEmpty) {
        // Novi nalog bez mašine — ne briši ručni odabir osim na force.
        if (forceFromOrder) {
          _headerEntitySelections.remove('machineId');
          _state.fieldValues.remove('machineId');
        }
      }
    }

    if (shouldApply) {
      _lastFirstPieceOrderIdApplied = orderId;
    }
    _ensureFirstPieceInspectorFromSession();
    _syncInProcessWorkPlaceFields();
    _stripNonOperatorEditableFieldValues();
    unawaited(_reloadFinalControlBomPicker());
  }

  /// M1-I7-B / M1-I8-B — nalog → proizvod u zaglavlju (materijal ostaje zaseban izbor).
  void _applyMaterialPreparationHeaderFromOrderSelection({
    bool forceFromOrder = false,
  }) {
    if (!_isMaterialPrepFamily) return;

    _state.fieldValues.remove('productionOrderCode');
    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');

    final order = _headerEntitySelections['productionOrderId'];
    if (order == null) {
      _lastMaterialPrepOrderIdApplied = null;
      _clearOmpMaterialSelectionForProductChange();
      _ompBomPicker = const OmpBomPickerState();
      _ompBomLoadedForProductId = null;
      _stripNonOperatorEditableFieldValues();
      return;
    }
    final orderId = order.entityId.trim();
    final orderChanged = orderId != (_lastMaterialPrepOrderIdApplied ?? '');
    final shouldApply = forceFromOrder || orderChanged;
    final raw = order.raw;

    final productId = (raw['productId'] ?? '').toString().trim();
    final productCode = (raw['productCode'] ?? '').toString().trim();
    final productName = (raw['productName'] ??
            raw['displayName'] ??
            '')
        .toString()
        .trim();
    final existingProduct =
        (_headerEntitySelections['productId']?.entityId ?? '').trim();
    if (productId.isNotEmpty && (shouldApply || existingProduct.isEmpty)) {
      final productRaw = {
        'id': productId,
        'productCode': productCode,
        'productName': productName,
        'displayName': productName,
      };
      _state.fieldValues['productId'] = productId;
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: productId,
        displayLabel:
            StructuredEntitySearchResult.productDisplayLabel(productRaw),
        raw: productRaw,
      );
    }

    // M1-I8-B — soft autofill mašine iz naloga kad je mjesto rada = mašina.
    if (_isOperationMaterialPreparation) {
      final type = (_headerEnumSelections['workContextType'] ??
              _state.fieldValues['workContextType'] ??
              '')
          .toString()
          .trim();
      if (type == 'machine' || type.isEmpty) {
        final machineId = (raw['machineId'] ?? '').toString().trim();
        final existingMachine =
            (_state.fieldValues['machineId'] ?? '').toString().trim();
        if (machineId.isNotEmpty && (shouldApply || existingMachine.isEmpty)) {
          final machineCode = (raw['machineCode'] ?? '').toString().trim();
          final machineName = (raw['machineName'] ?? '').toString().trim();
          final labelParts = <String>[
            if (machineCode.isNotEmpty) machineCode,
            if (machineName.isNotEmpty) machineName,
          ];
          _state.fieldValues['machineId'] = machineId;
          if (type.isEmpty) {
            _headerEnumSelections['workContextType'] = 'machine';
            _state.fieldValues['workContextType'] = 'machine';
          }
          _headerEntitySelections['machineId'] = StructuredEntitySelection(
            fieldKey: 'machineId',
            entityId: machineId,
            displayLabel: labelParts.isNotEmpty
                ? labelParts.join(' · ')
                : 'Mašina',
            raw: {
              'id': machineId,
              'machineCode': machineCode,
              'displayName': machineName,
            },
          );
        } else if (shouldApply && machineId.isEmpty) {
          if (forceFromOrder) {
            _headerEntitySelections.remove('machineId');
            _state.fieldValues.remove('machineId');
          }
        }
      }
      _syncInProcessWorkPlaceFields();
    }

    if (shouldApply) {
      _lastMaterialPrepOrderIdApplied = orderId;
      _clearOmpMaterialSelectionForProductChange();
    }
    _stripNonOperatorEditableFieldValues();
    unawaited(_reloadOmpPrimaryBomPicker());
  }

  void _clearOmpMaterialSelectionForProductChange() {
    _headerEntitySelections.remove('materialId');
    _state.fieldValues.remove('materialId');
    _state.fieldValues.remove('materialCodeSnapshot');
    _state.fieldValues.remove('materialNameSnapshot');
    _state.fieldValues.remove('bomId');
    _state.fieldValues.remove('bomVersion');
    _state.fieldValues.remove('bomItemLineId');
    _state.fieldValues.remove('normativeQtyPerUnit');
    _state.fieldValues.remove('normativeUnit');
    _state.fieldValues.remove('materialSource');
    _clearOmpWmsLotFields();
    _clearOmpTraceabilitySnapshots();
    _lastOmpMaterialIdForPrefill = null;
  }

  /// M1-I11-B — obriši lot / WMS snapshot pri promjeni materijala.
  void _clearOmpWmsLotFields() {
    _state.fieldValues.remove('materialLot');
    _state.fieldValues.remove('materialLotSource');
    _state.fieldValues.remove('inventoryLotDocId');
    _state.fieldValues.remove('batchNumberSnapshot');
    _state.fieldValues.remove('warehouseNameSnapshot');
    _state.fieldValues.remove('inventoryLotStatusSnapshot');
    _state.fieldValues.remove('lotAvailableQtySnapshot');
    _state.fieldValues.remove('lotUnitSnapshot');
    _headerEnumSelections.remove('materialLotSource');
    final lotCtrl = _headerTextControllers['materialLot'];
    if (lotCtrl != null && lotCtrl.text.isNotEmpty) {
      lotCtrl.text = '';
    }
  }

  /// M1-I11-C — snimci klasifikacije BOM stavke.
  void _clearOmpTraceabilitySnapshots() {
    _state.fieldValues.remove(ompBomItemKindSnapshot);
    _state.fieldValues.remove(ompTraceabilityModeSnapshot);
    _state.fieldValues.remove(ompLotRequiredSnapshot);
  }

  void _applyOmpTraceabilitySnapshots(
    ({String kind, String mode, bool lotRequired}) resolved,
  ) {
    final snaps = ompTraceabilitySnapshotsFromResolved(resolved);
    _state.fieldValues.addAll(snaps);
  }

  void _ensureOmpTraceabilityPersisted() {
    if (!_isOperationMaterialPreparation) return;
    if (_state.fieldValues.containsKey(ompLotRequiredSnapshot) &&
        _state.fieldValues.containsKey(ompTraceabilityModeSnapshot) &&
        _state.fieldValues.containsKey(ompBomItemKindSnapshot)) {
      return;
    }
    final materialId = (_headerEntitySelections['materialId']?.entityId ??
            _state.fieldValues['materialId'] ??
            '')
        .toString()
        .trim();
    if (materialId.isEmpty) return;
    final raw = _headerEntitySelections['materialId']?.raw;
    if (raw != null && raw.isNotEmpty) {
      _applyOmpTraceabilitySnapshots(resolveBomItemTraceability(raw));
    } else {
      _applyOmpTraceabilitySnapshots(resolveBomItemTraceability(const {}));
    }
  }

  void _applyOmpWmsLotSelection(OmpWmsLotRow lot) {
    _state.fieldValues['materialLot'] = lot.lotId;
    _state.fieldValues['materialLotSource'] = 'wms';
    _headerEnumSelections['materialLotSource'] = 'wms';
    _state.fieldValues['inventoryLotDocId'] = lot.lotDocId;
    if ((lot.batchNumber ?? '').trim().isNotEmpty) {
      _state.fieldValues['batchNumberSnapshot'] = lot.batchNumber!.trim();
    } else {
      _state.fieldValues.remove('batchNumberSnapshot');
    }
    _state.fieldValues['warehouseNameSnapshot'] = lot.warehouseDisplay;
    _state.fieldValues['inventoryLotStatusSnapshot'] = lot.statusLabel;
    _state.fieldValues['lotAvailableQtySnapshot'] = lot.availableQty;
    if ((lot.unit ?? '').trim().isNotEmpty) {
      _state.fieldValues['lotUnitSnapshot'] = lot.unit!.trim();
    } else {
      _state.fieldValues.remove('lotUnitSnapshot');
    }
    final lotCtrl = _headerTextControllers.putIfAbsent(
      'materialLot',
      TextEditingController.new,
    );
    if (lotCtrl.text != lot.lotId) lotCtrl.text = lot.lotId;
  }

  void _applyOmpManualLot(String lotText) {
    final t = lotText.trim();
    if (t.isEmpty) {
      _state.fieldValues.remove('materialLot');
    } else {
      _state.fieldValues['materialLot'] = t;
    }
    _state.fieldValues['materialLotSource'] = 'manual';
    _headerEnumSelections['materialLotSource'] = 'manual';
    _state.fieldValues.remove('inventoryLotDocId');
    _state.fieldValues.remove('batchNumberSnapshot');
    _state.fieldValues.remove('warehouseNameSnapshot');
    _state.fieldValues.remove('inventoryLotStatusSnapshot');
    _state.fieldValues.remove('lotAvailableQtySnapshot');
    _state.fieldValues.remove('lotUnitSnapshot');
  }

  String get _ompBomContextProductId {
    final fromHeader = (_headerEntitySelections['productId']?.entityId ??
            _state.fieldValues['productId'] ??
            '')
        .toString()
        .trim();
    if (fromHeader.isNotEmpty) return fromHeader;
    final fromOrder = (_headerEntitySelections['productionOrderId']?.raw['productId'] ??
            '')
        .toString()
        .trim();
    if (fromOrder.isNotEmpty) return fromOrder;
    return (_headerEntitySelections['recipeId']?.entityId ??
            _state.fieldValues['recipeId'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _reloadOmpPrimaryBomPicker() async {
    if (!_usesOmpBomMaterialPicker) return;
    final productId = _ompBomContextProductId;
    if (productId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _ompBomPicker = const OmpBomPickerState();
        _ompBomLoadedForProductId = null;
      });
      return;
    }
    if (_ompBomLoadedForProductId == productId &&
        (_ompBomPicker.mode == OmpBomPickerMode.bomBound ||
            _ompBomPicker.mode == OmpBomPickerMode.softFallback)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _ompBomPicker = OmpBomPickerState(
        mode: OmpBomPickerMode.loading,
        productId: productId,
      );
    });
    final next = await loadOmpPrimaryBomPickerState(
      bomService: _bomService,
      companyId: _companyId,
      productId: productId,
    );
    if (!mounted) return;
    setState(() {
      _ompBomPicker = next;
      _ompBomLoadedForProductId = productId;
    });
  }

  Future<List<StructuredEntitySearchResult>> _searchOmpMaterial(
    String query,
  ) async {
    if (_ompBomPicker.isBomBound) {
      return filterOmpBomSearchResults(
        items: _ompBomPicker.items,
        query: query,
      );
    }
    return _searchService.searchByCallable(
      callableName: 'searchProducts',
      companyId: _companyId,
      query: query,
    );
  }

  void _applyOmpMaterialSelectionSideEffects() {
    if (!_isOperationMaterialPreparation) return;
    final selection = _headerEntitySelections['materialId'];
    final materialId = (selection?.entityId ?? '').trim();
    if (materialId.isEmpty) {
      _lastOmpMaterialIdForPrefill = null;
      _state.fieldValues.remove('bomId');
      _state.fieldValues.remove('bomVersion');
      _state.fieldValues.remove('bomItemLineId');
      _state.fieldValues.remove('normativeQtyPerUnit');
      _state.fieldValues.remove('normativeUnit');
      _state.fieldValues.remove('materialSource');
      _clearOmpWmsLotFields();
      _clearOmpTraceabilitySnapshots();
      return;
    }
    if (materialId == (_lastOmpMaterialIdForPrefill ?? '')) return;
    _clearOmpWmsLotFields();
    _lastOmpMaterialIdForPrefill = materialId;

    final raw = selection?.raw ?? const <String, dynamic>{};
    final code = (raw['productCode'] ??
            raw['componentCode'] ??
            raw['materialCode'] ??
            '')
        .toString()
        .trim();
    final name = (raw['productName'] ??
            raw['componentName'] ??
            raw['displayName'] ??
            '')
        .toString()
        .trim();
    if (code.isNotEmpty) {
      _state.fieldValues['materialCodeSnapshot'] = code;
    }
    if (name.isNotEmpty) {
      _state.fieldValues['materialNameSnapshot'] = name;
    }

    final fromBom = (raw['source'] ?? '').toString() == 'bom_primary' ||
        (_ompBomPicker.isBomBound &&
            _ompBomPicker.items.any((e) => e.id == materialId));

    if (fromBom) {
      final bomId = (raw['bomId'] ?? _ompBomPicker.bomId).toString().trim();
      final bomVersion =
          (raw['bomVersion'] ?? _ompBomPicker.bomVersion).toString().trim();
      final lineId =
          (raw['bomItemLineId'] ?? raw['lineId'] ?? '').toString().trim();
      final qty = raw['qtyPerUnit'];
      final unit = (raw['unit'] ?? '').toString().trim();

      if (bomId.isNotEmpty) _state.fieldValues['bomId'] = bomId;
      if (bomVersion.isNotEmpty) {
        _state.fieldValues['bomVersion'] = bomVersion;
      }
      if (lineId.isNotEmpty) {
        _state.fieldValues['bomItemLineId'] = lineId;
      }
      _state.fieldValues['materialSource'] = 'bom_primary';
      _applyOmpTraceabilitySnapshots(resolveBomItemTraceability(raw));

      if (qty is num && qty > 0) {
        _state.fieldValues['normativeQtyPerUnit'] = qty;
        final qtyText =
            qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        final qtyCtrl = _headerTextControllers.putIfAbsent(
          'preparedQuantity',
          () => TextEditingController(),
        );
        qtyCtrl.text = qtyText;
        _state.fieldValues['preparedQuantity'] = qty.toDouble();
      }
      if (unit.isNotEmpty) {
        _state.fieldValues['normativeUnit'] = unit;
        final allowed = _effectiveProfile.allowedUnits;
        if (allowed.contains(unit)) {
          _headerEnumSelections['unit'] = unit;
          _state.fieldValues['unit'] = unit;
        }
      }
    } else {
      _state.fieldValues['materialSource'] = 'catalog_fallback';
      _state.fieldValues.remove('bomId');
      _state.fieldValues.remove('bomVersion');
      _state.fieldValues.remove('bomItemLineId');
      _state.fieldValues.remove('normativeQtyPerUnit');
      _state.fieldValues.remove('normativeUnit');
      // Katalog fallback — siguran default (lot obavezan).
      _applyOmpTraceabilitySnapshots(resolveBomItemTraceability(const {}));
    }
  }

  Widget? _buildOmpBomHeaderNotice(BuildContext context) {
    if (!_isMaterialPrepFamily) return null;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_ompBomPicker.mode == OmpBomPickerMode.loading) {
      return Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Učitavanje primarne sastavnice…')),
            ],
          ),
        ),
      );
    }
    if (_ompBomPicker.isBomBound) {
      final ver = _ompBomPicker.bomVersion.isEmpty
          ? ''
          : ' (${_ompBomPicker.bomVersion})';
      return Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _isOperationMaterialPreparation
                ? 'Materijal birajte iz primarne sastavnice$ver — '
                    '${_ompBomPicker.items.length} stavki. '
                    'Normativna količina i JM predlažu se pri odabiru; '
                    'lot unosite samo ako je stavka lot-sljediva.'
                : 'Materijal birajte iz primarne sastavnice$ver — '
                    '${_ompBomPicker.items.length} stavki. '
                    'Katalog se koristi samo ako sastavnica nije dostupna.',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (_ompBomPicker.isSoftFallback) {
      return Material(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _ompBomPicker.errorMessage ??
                'Nema aktivne primarne sastavnice — izbor iz kataloga (privremeno).',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }
    return null;
  }

  /// M1-I15-C5 — miješanje šarže: komponente iz sastavnice naloga / recepta.
  void _applyBatchMixingBomContextFromHeader() {
    if (!_isBatchMixing) return;
    final order = _headerEntitySelections['productionOrderId'];
    final orderProductId =
        (order?.raw['productId'] ?? '').toString().trim();
    if (orderProductId.isNotEmpty) {
      final productCode =
          (order!.raw['productCode'] ?? '').toString().trim();
      final productName = (order.raw['productName'] ??
              order.raw['displayName'] ??
              '')
          .toString()
          .trim();
      final productRaw = {
        'id': orderProductId,
        'productCode': productCode,
        'productName': productName,
        'displayName': productName,
      };
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: orderProductId,
        displayLabel:
            StructuredEntitySearchResult.productDisplayLabel(productRaw),
        raw: productRaw,
      );
    } else {
      final recipe = _headerEntitySelections['recipeId'];
      final recipeId = (recipe?.entityId ?? '').trim();
      if (recipeId.isNotEmpty) {
        _headerEntitySelections['productId'] = StructuredEntitySelection(
          fieldKey: 'productId',
          entityId: recipeId,
          displayLabel: recipe!.displayLabel,
          raw: Map<String, dynamic>.from(recipe.raw),
        );
      } else {
        _headerEntitySelections.remove('productId');
      }
    }
    unawaited(_reloadOmpPrimaryBomPicker());
  }

  Widget? _buildBatchMixingBomTableNotice(BuildContext context) {
    if (!_isBatchMixing) return null;
    final cs = Theme.of(context).colorScheme;
    if (_ompBomPicker.mode == OmpBomPickerMode.loading) {
      return Text(
        'Učitavanje sastavnice…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      );
    }
    if (_ompBomPicker.isBomBound) {
      final ver = _ompBomPicker.bomVersion.isEmpty
          ? ''
          : ' (${_ompBomPicker.bomVersion})';
      return Text(
        'Komponente se nude iz primarne sastavnice$ver — '
        '${_ompBomPicker.items.length} stavki. '
        'Katalog se koristi samo ako sastavnica nije dostupna.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      );
    }
    if (_ompBomPicker.isSoftFallback) {
      return Text(
        _ompBomPicker.errorMessage ??
            'Nema aktivne primarne sastavnice — izbor iz kataloga (privremeno).',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.tertiary,
            ),
      );
    }
    final order = _headerEntitySelections['productionOrderId'];
    if (order != null) {
      return Text(
        'Nalog nema proizvod — kontrolisani izbor iz kataloga (privremeno).',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.tertiary,
            ),
      );
    }
    return null;
  }

  ProductionStationProfileField _ompMaterialFieldOverride({
    int? minSearchChars,
    required String helperText,
  }) {
    ProductionStationProfileField? base;
    for (final f in _effectiveProfile.structuredHeaderFields) {
      if (f.key == 'materialId') {
        base = f;
        break;
      }
    }
    if (base == null) {
      return ProductionStationProfileField(
        key: 'materialId',
        label: 'Materijal',
        type: 'entity_search_select',
        required: true,
        minSearchChars: minSearchChars ?? 2,
        helperText: helperText,
      );
    }
    return base.copyWith(
      minSearchChars: minSearchChars,
      helperText: helperText,
    );
  }

  /// M1-I5-B — nalog → proizvod u zaglavlju (bez tipkanja šifre).
  void _applyFinalControlHeaderFromOrderSelection({
    bool forceFromOrder = false,
  }) {
    if (!_isFinalControl) return;

    _state.fieldValues.remove('productionOrderCode');
    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');
    _state.fieldValues.remove('controllerNameSnapshot');

    final order = _headerEntitySelections['productionOrderId'];
    if (order == null) {
      _lastFirstPieceOrderIdApplied = null;
      _fcBomPicker = const OmpBomPickerState();
      _fcBomLoadedForProductId = null;
      _ensurePackagingControllerFromSession();
      _stripNonOperatorEditableFieldValues();
      return;
    }
    final orderId = order.entityId.trim();
    final orderChanged = orderId != (_lastFirstPieceOrderIdApplied ?? '');
    final shouldApply = forceFromOrder || orderChanged;
    final raw = order.raw;

    final productId = (raw['productId'] ?? '').toString().trim();
    final productCode = (raw['productCode'] ?? '').toString().trim();
    final productName = (raw['productName'] ??
            raw['displayName'] ??
            '')
        .toString()
        .trim();
    final existingProduct =
        (_headerEntitySelections['productId']?.entityId ?? '').trim();
    if (productId.isNotEmpty && (shouldApply || existingProduct.isEmpty)) {
      final productRaw = {
        'id': productId,
        'productCode': productCode,
        'productName': productName,
        'displayName': productName,
      };
      _state.fieldValues['productId'] = productId;
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: productId,
        displayLabel:
            StructuredEntitySearchResult.productDisplayLabel(productRaw),
        raw: productRaw,
      );
    }

    if (shouldApply) {
      _lastFirstPieceOrderIdApplied = orderId;
    }
    _ensurePackagingControllerFromSession();
    _stripNonOperatorEditableFieldValues();
    unawaited(_reloadFinalControlBomPicker());
  }

  Future<void> _reloadFinalControlBomPicker() async {
    // M1-I15-C — BOM soft-fallback za FC / packaging / in_process.
    if (!_isFinalControl && !_isPackagingControl && !_isInProcessQualityCheck) {
      return;
    }
    final productId =
        (_headerEntitySelections['productId']?.entityId ??
                _state.fieldValues['productId'] ??
                '')
            .toString()
            .trim();
    if (productId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _fcBomPicker = const OmpBomPickerState();
        _fcBomLoadedForProductId = null;
      });
      return;
    }
    if (_fcBomLoadedForProductId == productId &&
        (_fcBomPicker.mode == OmpBomPickerMode.bomBound ||
            _fcBomPicker.mode == OmpBomPickerMode.softFallback)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _fcBomPicker = OmpBomPickerState(
        mode: OmpBomPickerMode.loading,
        productId: productId,
      );
    });
    final next = await loadFinalControlBomProductPickerState(
      bomService: _bomService,
      companyId: _companyId,
      productId: productId,
    );
    if (!mounted) return;
    setState(() {
      _fcBomPicker = next;
      _fcBomLoadedForProductId = productId;
    });
  }

  /// M1-I15-C1 — Operater proizvodnje na pakovanju: samo production_operator.
  Future<List<StructuredEntitySearchResult>> _searchPackagingOperator(
    String query,
  ) {
    return _searchService.searchPlantOperators(
      companyId: _companyId,
      query: query,
      assignedPlantKey: _plantKey,
      roleKeys:
          controlledEvidenceRoleKeysForPersonField('packagingOperatorEmployeeId')!,
    );
  }

  /// M1-I15-C2 — Proizvodni operater (procesna kontrola): samo production_operator.
  Future<List<StructuredEntitySearchResult>> _searchProductionOperator(
    String query,
  ) {
    return _searchService.searchPlantOperators(
      companyId: _companyId,
      query: query,
      assignedPlantKey: _plantKey,
      roleKeys: controlledEvidenceRoleKeysForPersonField(
        'productionOperatorEmployeeId',
      )!,
    );
  }

  /// M1-I15-C4 — person picker po I15-B mapi (Izvršio / Verifikovao).
  Future<List<StructuredEntitySearchResult>> _searchPersonForField(
    String fieldKey,
    String query,
  ) {
    return _searchService.searchPlantOperators(
      companyId: _companyId,
      query: query,
      assignedPlantKey: _plantKey,
      roleKeys: controlledEvidenceRoleKeysForPersonField(
            fieldKey,
            profileKey: _effectiveProfile.profileKey,
          ) ??
          const [],
    );
  }

  /// M1-I15-C3 / C4 — proizvod iz naloga kad postoji, inače katalog.
  Future<List<StructuredEntitySearchResult>> _searchFirstPieceProduct(
    String query,
  ) async {
    final order = _headerEntitySelections['productionOrderId'];
    final orderProductId =
        (order?.raw['productId'] ?? '').toString().trim();
    if (orderProductId.isNotEmpty) {
      final sel = _headerEntitySelections['productId'];
      if (sel != null && sel.entityId.trim().isNotEmpty) {
        final item = StructuredEntitySearchResult(
          id: sel.entityId.trim(),
          displayLabel: sel.displayLabel,
          secondaryLabel: 'Proizvod naloga',
          raw: Map<String, dynamic>.from(sel.raw),
        );
        return filterOmpBomSearchResults(items: [item], query: query);
      }
    }
    return _searchService.searchByCallable(
      callableName: 'searchProducts',
      companyId: _companyId,
      query: query,
    );
  }

  Future<void> _loadPlantWorkplaceZones() async {
    if (!_isWorkspace5sCleaning || _companyId.isEmpty) return;
    try {
      final items = await _searchService.searchProductionWorkbenches(
        companyId: _companyId,
        query: '',
        assignedPlantKey: _plantKey,
      );
      if (!mounted) return;
      setState(() => _plantWorkplaceZones = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _plantWorkplaceZones = const []);
    }
  }

  Widget? _buildWorkspace5sHeaderNotice(BuildContext context) {
    if (!_isWorkspace5sCleaning) return null;
    final modeLabel = cleaningChecklistModeLabel(_cleaningChecklistMode);
    final body = _isCleaningQuickList
        ? 'Odaberite zonu, smjenu i osnovne korake čišćenja. '
            'Komentar je obavezan samo ako ishod nije zadovoljan.'
        : 'Odaberite zonu pogona ili Drugo. Svaka 5S stavka: U redu, Nije u redu '
            'ili Nije primjenjivo. Opis odstupanja je obavezan samo ako je stavka '
            'Nije u redu.';
    return Text(
      '$modeLabel. $body',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  Future<List<StructuredEntitySearchResult>> _searchWorkspace5sZones(
    String query,
  ) async {
    List<StructuredEntitySearchResult> workbenches = _plantWorkplaceZones;
    try {
      workbenches = await _searchService.searchProductionWorkbenches(
        companyId: _companyId,
        query: query,
        assignedPlantKey: _plantKey,
      );
    } catch (_) {
      // Šifrarnik pogona nije obavezan — ostaju 5S zone + Drugo.
    }
    return mergeWorkspace5sZoneChoices(
      plantWorkbenches: workbenches,
      query: query,
    );
  }

  Widget? _buildLineClearanceHeaderNotice(BuildContext context) {
    if (!_isLineClearance || _isLineClearanceVerifierHandoff) return null;
    final modeLabel = cleaningChecklistModeLabel(_cleaningChecklistMode);
    final body = _isCleaningQuickList
        ? 'Odaberite radni centar ili mašinu, smjenu i osnovne korake čišćenja.'
        : 'Unesite mjesto čišćenja, smjenu, vrijeme i potvrdu liste. '
            'Prethodni i sljedeći proizvod se prikazuju samo pri tipu Promjena proizvoda.';
    return Text(
      '$modeLabel. $body',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget? _buildFirstPieceHeaderNotice(BuildContext context) {
    if (!_isFirstPieceApproval && !_isToolChangeover) return null;
    final order = _headerEntitySelections['productionOrderId'];
    final orderProductId =
        (order?.raw['productId'] ?? '').toString().trim();
    final cs = Theme.of(context).colorScheme;
    if (orderProductId.isNotEmpty) {
      return Text(
        'Proizvod je vezan za odabrani nalog — kontrolisani izbor, nije slobodan unos.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      );
    }
    if (order != null) {
      return Text(
        'Nalog nema proizvod — privremeno kontrolisani izbor iz kataloga.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.tertiary,
            ),
      );
    }
    return null;
  }

  Future<List<StructuredEntitySearchResult>> _searchFinalControlProduct(
    String query,
  ) async {
    if (_fcBomPicker.isBomBound) {
      final headerSel = _headerEntitySelections['productId'];
      StructuredEntitySearchResult? orderProduct;
      if (headerSel != null && headerSel.entityId.trim().isNotEmpty) {
        orderProduct = StructuredEntitySearchResult(
          id: headerSel.entityId.trim(),
          displayLabel: headerSel.displayLabel,
          secondaryLabel: 'Proizvod naloga',
          raw: Map<String, dynamic>.from(headerSel.raw),
        );
      }
      final choices = buildFinalControlBomProductChoices(
        bom: _fcBomPicker,
        orderProduct: orderProduct,
      );
      return filterOmpBomSearchResults(items: choices, query: query);
    }
    return _searchService.searchByCallable(
      callableName: 'searchProducts',
      companyId: _companyId,
      query: query,
    );
  }

  Widget? _buildFinalControlBomTableNotice(BuildContext context) {
    if (!_isFinalControl) return null;
    return _buildEvidenceBomTableNotice(
      context,
      bomBoundMessage: (ver, count) =>
          'Proizvod se nudi iz primarne sastavnice$ver — '
          '$count stavki (+ proizvod naloga).',
    );
  }

  /// M1-I15-C1 — packaging: redovi nasljeđuju proizvod; banner za BOM / soft fallback.
  Widget? _buildPackagingBomTableNotice(BuildContext context) {
    if (!_isPackagingControl) return null;
    return _buildEvidenceBomTableNotice(
      context,
      bomBoundMessage: (ver, count) =>
          'Proizvod u redovima nasljeđuje proizvod naloga '
          '(usklađeno s primarnom sastavnicom$ver — $count stavki).',
    );
  }

  /// M1-I15-C2 — inspection_lines: BOM-first prijedlozi.
  Widget? _buildInProcessBomTableNotice(BuildContext context) {
    if (!_isInProcessQualityCheck) return null;
    return _buildEvidenceBomTableNotice(
      context,
      bomBoundMessage: (ver, count) =>
          'Proizvod se nudi iz primarne sastavnice$ver — '
          '$count stavki (+ proizvod naloga).',
    );
  }

  Widget? _buildEvidenceBomTableNotice(
    BuildContext context, {
    required String Function(String versionSuffix, int itemCount) bomBoundMessage,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (_fcBomPicker.mode == OmpBomPickerMode.loading) {
      return Text(
        'Učitavanje sastavnice…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      );
    }
    if (_fcBomPicker.isBomBound) {
      final ver = _fcBomPicker.bomVersion.isEmpty
          ? ''
          : ' (${_fcBomPicker.bomVersion})';
      return Text(
        bomBoundMessage(ver, _fcBomPicker.items.length),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      );
    }
    if (_fcBomPicker.isSoftFallback) {
      return Text(
        _fcBomPicker.errorMessage ?? finalControlBomNoBomMessage,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.tertiary,
            ),
      );
    }
    return null;
  }

  ProductionStationProfileField _packagingOperatorFieldOverride(
    ProductionStationProfileField base,
  ) {
    return base.copyWith(
      label: 'Operater proizvodnje',
      minSearchChars: 0,
      helperText: controlledEvidencePersonHelperText('packagingOperatorEmployeeId'),
    );
  }

  ProductionStationProfileField _productionOperatorFieldOverride(
    ProductionStationProfileField base,
  ) {
    return base.copyWith(
      minSearchChars: 2,
      helperText: productionOperatorWorkforceSearchHelper,
    );
  }

  ProductionStationProfileField _personFieldOverride(
    ProductionStationProfileField base,
  ) {
    final productionPerformer = base.key == 'performedByEmployeeId' ||
        base.key == 'operatorId';
    final fiveSVerifier =
        _isWorkspace5sCleaning && base.key == 'verifiedByEmployeeId';
    return base.copyWith(
      minSearchChars: productionPerformer ? 2 : 0,
      label: fiveSVerifier ? workspace5sVerifierFieldLabel : null,
      helperText: controlledEvidencePersonHelperText(
        base.key,
        profileKey: _effectiveProfile.profileKey,
      ),
    );
  }

  ProductionStationProfileField _lineClearanceProductFieldOverride(
    ProductionStationProfileField base,
  ) {
    return base.copyWith(
      helperText:
          'Kontrolisani izbor iz kataloga proizvoda — nije slobodan unos. '
          'Nije iz sastavnice (prethodni / sljedeći proizvod na liniji).',
    );
  }

  ProductionStationProfileField _firstPieceProductFieldOverride(
    ProductionStationProfileField base,
  ) {
    final order = _headerEntitySelections['productionOrderId'];
    final orderProductId =
        (order?.raw['productId'] ?? '').toString().trim();
    if (orderProductId.isNotEmpty) {
      return base.copyWith(
        minSearchChars: 0,
        helperText:
            'Proizvod iz odabranog naloga — kontrolisani izbor, nije slobodan unos.',
      );
    }
    return base.copyWith(
      helperText:
          'Nalog nema proizvod — kontrolisani izbor iz kataloga (privremeno).',
    );
  }

  ProductionStationProfileField _finalControlRowProductFieldOverride(
    ProductionStationProfileField base, {
    required int minSearchChars,
    required String helperText,
  }) {
    return base.copyWith(
      minSearchChars: minSearchChars,
      helperText: helperText,
    );
  }

  /// Zaglavlje: samo kanonski ID-jevi u fieldValues (M1-I2-F6).
  /// productCode / productNameSnapshot / productionOrderCode = backend snapshot.
  void _applyPackagingHeaderSnapshotsFromSelections() {
    if (!_isPackagingControl) return;

    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');
    _state.fieldValues.remove('productionOrderCode');
    _state.fieldValues.remove('controllerNameSnapshot');

    final order = _headerEntitySelections['productionOrderId'];
    if (order != null) {
      final raw = order.raw;
      final productId = (raw['productId'] ?? '').toString().trim();
      final productCode = (raw['productCode'] ?? '').toString().trim();
      final productName = (raw['productName'] ??
              raw['displayName'] ??
              '')
          .toString()
          .trim();
      if (productId.isNotEmpty) {
        _state.fieldValues['productId'] = productId;
        final productRaw = {
          'id': productId,
          'productCode': productCode,
          'productName': productName,
          'displayName': productName,
        };
        _headerEntitySelections['productId'] = StructuredEntitySelection(
          fieldKey: 'productId',
          entityId: productId,
          displayLabel:
              StructuredEntitySearchResult.productDisplayLabel(productRaw),
          raw: productRaw,
        );
      }
    }

    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _stripNonOperatorEditableFieldValues();
    unawaited(_reloadFinalControlBomPicker());
  }

  /// M1-I3-H1 — sken/odabir naloga puni poznata polja (proizvod, mašina, lot).
  /// [forceFromOrder]: true pri skeniranju; inače samo kad se promijeni nalog.
  void _applyFirstPieceHeaderFromOrderSelection({
    bool forceFromOrder = false,
  }) {
    if (!_isFirstPieceApproval && !_isToolChangeover) return;

    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');
    _state.fieldValues.remove('productionOrderCode');
    if (_isFirstPieceApproval) {
      _state.fieldValues.remove('machineNameSnapshot');
      _state.fieldValues.remove('machineCodeSnapshot');
    }

    final order = _headerEntitySelections['productionOrderId'];
    if (order == null) {
      _lastFirstPieceOrderIdApplied = null;
      _ensureFirstPieceInspectorFromSession();
      _stripNonOperatorEditableFieldValues();
      return;
    }
    final orderId = order.entityId.trim();
    final orderChanged = orderId != (_lastFirstPieceOrderIdApplied ?? '');
    final shouldApply = forceFromOrder || orderChanged;
    final raw = order.raw;

    final productId = (raw['productId'] ?? '').toString().trim();
    final productCode = (raw['productCode'] ?? '').toString().trim();
    final productName = (raw['productName'] ??
            raw['displayName'] ??
            '')
        .toString()
        .trim();
    final existingProduct =
        (_state.fieldValues['productId'] ?? '').toString().trim();
    if (productId.isNotEmpty && (shouldApply || existingProduct.isEmpty)) {
      final productRaw = {
        'id': productId,
        'productCode': productCode,
        'productName': productName,
        'displayName': productName,
      };
      _state.fieldValues['productId'] = productId;
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: productId,
        displayLabel:
            StructuredEntitySearchResult.productDisplayLabel(productRaw),
        raw: productRaw,
      );
    }

    if (_isFirstPieceApproval) {
      final machineId = (raw['machineId'] ?? '').toString().trim();
      final existingMachine =
          (_state.fieldValues['machineId'] ?? '').toString().trim();
      if (machineId.isNotEmpty && (shouldApply || existingMachine.isEmpty)) {
        final machineCode = (raw['machineCode'] ?? '').toString().trim();
        final machineName = (raw['machineName'] ?? '').toString().trim();
        final labelParts = <String>[
          if (machineCode.isNotEmpty) machineCode,
          if (machineName.isNotEmpty) machineName,
        ];
        final displayLabel = labelParts.isNotEmpty
            ? labelParts.join(' — ')
            : (machineName.isNotEmpty ? machineName : 'Mašina');
        _state.fieldValues['machineId'] = machineId;
        _headerEntitySelections['machineId'] = StructuredEntitySelection(
          fieldKey: 'machineId',
          entityId: machineId,
          displayLabel: displayLabel,
          raw: {
            'id': machineId,
            'machineCode': machineCode,
            'machineName': machineName,
            'displayName': machineName,
          },
        );
      } else if (shouldApply && machineId.isEmpty) {
        _state.fieldValues.remove('machineId');
        _headerEntitySelections['machineId'] = null;
      }

      final lot = (raw['inputMaterialLot'] ??
              raw['pieceSerialOrLot'] ??
              '')
          .toString()
          .trim();
      final existingLot =
          (_state.fieldValues['pieceSerialOrLot'] ?? '').toString().trim();
      if (lot.isNotEmpty && (shouldApply || existingLot.isEmpty)) {
        _state.fieldValues['pieceSerialOrLot'] = lot;
        final lotController = _headerTextControllers.putIfAbsent(
          'pieceSerialOrLot',
          TextEditingController.new,
        );
        if (lotController.text != lot) lotController.text = lot;
      }
    }

    _lastFirstPieceOrderIdApplied = orderId;
    if (_isFirstPieceApproval) {
      _ensureFirstPieceInspectorFromSession();
      _ensureFirstPieceDefaults();
    }
    _stripNonOperatorEditableFieldValues();
  }

  /// Payload smije sadržavati samo operator-editable polja profila (M1-I2-F6).
  /// HOTFIX-25 — predaja (Smjena i ostala zaglavlja) se ne sme brisati.
  void _stripNonOperatorEditableFieldValues() {
    final preserved = snapshotCleaningHandoffFieldValues(
      profileKey: _effectiveProfile.profileKey,
      fieldValues: _state.fieldValues,
    );
    final allowed = <String>{
      for (final f in _effectiveProfile.fields)
        if (f.isOperatorEditable && !f.signedByLoggedInUser) f.key,
      ...cleaningHandoffPersistKeys(_effectiveProfile.profileKey),
      if (_isLineClearance && _canSignVerification)
        ...lineClearanceVerifierInputKeys,
    };
    if (_hasSignedLoggedInVerifier) {
      allowed.remove(_effectiveProfile.signedVerifierFieldKey);
      allowed.remove('verifiedByNameSnapshot');
      allowed.remove('verifiedByRoleSnapshot');
    }
    _state.fieldValues.removeWhere((key, _) => !allowed.contains(key));
    restoreCleaningHandoffFieldValues(
      target: _state.fieldValues,
      preserved: preserved,
    );
    _restoreSavedHandoffIntoState();
  }

  Widget _buildSignedVerifierCard({required bool formEnabled}) {
    final cs = Theme.of(context).colorScheme;
    final canSign = _canSignVerification;
    final name = _processControllerDisplayName.trim();
    ProductionStationProfileField? field;
    for (final f in _effectiveProfile.fields) {
      if (f.key == _effectiveProfile.signedVerifierFieldKey) {
        field = f;
        break;
      }
    }
    final label = (field?.label ?? '').trim().isNotEmpty
        ? field!.label
        : workspace5sVerifierFieldLabel;
    final helper = canSign
        ? (field?.helperText ?? workspace5sVerifierHelperText)
        : signedEvidenceVerifierDeniedMessage;
    return Card(
      color: canSign
          ? cs.secondaryContainer.withValues(alpha: 0.55)
          : cs.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              canSign ? '$label:' : label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              canSign
                  ? (name.isEmpty ? 'Prijavljeni korisnik' : name)
                  : signedEvidenceVerifierDeniedMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canSign) ...[
              const SizedBox(height: 8),
              Text(
                helper,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
            if (!canSign && formEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Završetak evidencije je blokiran dok se ne prijavi ovlašteni verifikator.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineClearanceSiteVerificationCard({required bool formEnabled}) {
    final correction = _headerTextControllers.putIfAbsent(
      lineClearanceReadinessCorrectionKey,
      TextEditingController.new,
    );
    final stored = sanitizeEvidenceFormInput(
      (_state.fieldValues[lineClearanceReadinessCorrectionKey] ?? '').toString(),
    );
    if (correction.text != stored) {
      correction.text = stored;
    }
    return LineClearanceSiteVerificationCard(
      state: _state,
      enabled: formEnabled,
      placeLabel: lineClearanceVerifiedPlaceLabel(
        fieldValues: _state.fieldValues,
        workCenter: _headerEntitySelections['workCenterId'],
        machine: _headerEntitySelections['machineId'],
      ),
      clearanceTypeLabel: _lineClearanceEnumDisplayLabel('clearanceType'),
      shiftLabel: _lineClearanceEnumDisplayLabel('shiftKey'),
      performedByName: _performedByDisplayName,
      correctionController: correction,
      onChanged: () => setState(() {}),
    );
  }

  String _lineClearanceEnumDisplayLabel(String fieldKey) {
    final stored = sanitizeEvidenceFormInput(
      (_headerEnumSelections[fieldKey] ??
              _state.fieldValues[fieldKey] ??
              '')
          .toString(),
    );
    if (stored.isEmpty) return '';
    for (final field in _effectiveProfile.fields) {
      if (field.key == fieldKey) {
        return field.enumLabelFor(stored);
      }
    }
    return stored;
  }

  Widget _buildPerformedByHandoffCard() {
    final cs = Theme.of(context).colorScheme;
    ProductionStationProfileField? field;
    for (final f in _effectiveProfile.fields) {
      if (f.key == 'performedByEmployeeId') {
        field = f;
        break;
      }
    }
    final label = (field?.label ?? '').trim().isNotEmpty
        ? field!.label
        : workspace5sPerformedByFieldLabel;
    return Card(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$label: $_performedByDisplayName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _lockPerformedByForVerifier
                  ? workspace5sPerformedByHandoffHelper
                  : loggedInPerformerAutofillHelper,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInQualityOperatorCard() {
    final cs = Theme.of(context).colorScheme;
    final canFill = shouldAutofillFinalControlQualityOperator(
      profileKey: _effectiveProfile.profileKey,
      userRole: _userRole,
    );
    final name = loggedInPerformerDisplayName(widget.companyData).trim();
    final display = name.isNotEmpty ? name : 'Prijavljeni korisnik';
    return Card(
      color: canFill
          ? cs.secondaryContainer.withValues(alpha: 0.55)
          : cs.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Operater kvaliteta:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              canFill ? display : finalControlQualityOperatorFinishDeniedMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              canFill
                  ? loggedInFinalControlQualityOperatorHelper
                  : 'Završetak evidencije je blokiran dok se ne prijavi Operater kvaliteta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: canFill ? cs.onSurfaceVariant : cs.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncHeaderControllersFromState() {
    for (final field in _effectiveProfile.structuredHeaderFields) {
      final raw = _state.fieldValues[field.key];
      if (field.isEntitySelect || field.isEntitySearchSelect) {
        if (!isUsableEvidenceEntityId(raw?.toString())) {
          _headerEntitySelections[field.key] = null;
          if (raw != null) {
            _state.fieldValues.remove(field.key);
          }
          continue;
        }
        final existing = _headerEntitySelections[field.key];
        final selection = evidenceActiveEntitySelection(
          fieldKey: field.key,
          rawValue: raw.toString(),
          fieldValues: _state.fieldValues,
          existing: existing,
        );
        if (selection == null &&
            (field.key == 'inspectorEmployeeId' ||
                field.key == 'controllerEmployeeId') &&
            _processControllerDisplayName.trim().isNotEmpty) {
          _headerEntitySelections[field.key] = StructuredEntitySelection(
            fieldKey: field.key,
            entityId: raw.toString().trim(),
            displayLabel: _processControllerDisplayName.trim(),
            raw: existing != null && existing.entityId == raw.toString().trim()
                ? existing.raw
                : const <String, dynamic>{},
          );
          continue;
        }
        _headerEntitySelections[field.key] = selection;
      } else if (field.type == 'enum') {
        final value = raw?.toString();
        _headerEnumSelections[field.key] =
            isUsableCleaningHandoffEnumValue(
              value,
              enumValues: field.enumValues,
            )
                ? sanitizeEvidenceFormInput(value)
                : null;
      } else if (field.type == 'datetime') {
        _headerDateTimes[field.key] = StructuredDateTimeValue.parse(raw);
      } else if (field.type == 'number' || _isTextLike(field.type)) {
        final controller = _headerTextControllers.putIfAbsent(
          field.key,
          TextEditingController.new,
        );
        final text = raw == null
            ? ''
            : (raw is num && raw == raw.roundToDouble()
                ? raw.toInt().toString()
                : sanitizeEvidenceFormInput(raw.toString()));
        if (controller.text != text) {
          controller.text = text;
        }
      }
    }
    applyCleaningHandoffEnumsFromFieldValues(
      fields: _effectiveProfile.structuredHeaderFields,
      fieldValues: _state.fieldValues,
      enumSelections: _headerEnumSelections,
    );
    _applyLineClearanceLineNameFromWorkCenter();
    _ensureLoggedInPerformerFromSession();
  }

  bool _isTextLike(String type) => type == 'string' || type == 'text';

  void _flushHeaderFieldsToState() {
    const ompLotManagedKeys = {
      'materialLotSource',
      'inventoryLotDocId',
      'batchNumberSnapshot',
      'warehouseNameSnapshot',
      'inventoryLotStatusSnapshot',
      'lotAvailableQtySnapshot',
      'lotUnitSnapshot',
    };
    for (final field in _effectiveProfile.structuredHeaderFields) {
      // M1-I11-B — WMS snapshoti se drže u fieldValues iz lot sekcije.
      if (_isOperationMaterialPreparation &&
          ompLotManagedKeys.contains(field.key)) {
        continue;
      }
      if (field.type == 'number') {
        final text = _headerTextControllers[field.key]?.text.trim() ?? '';
        if (text.isEmpty) {
          _state.fieldValues.remove(field.key);
          continue;
        }
        final n = double.tryParse(text.replaceAll(',', '.'));
        if (n == null) {
          _state.fieldValues.remove(field.key);
        } else {
          _state.fieldValues[field.key] = n;
        }
        continue;
      }
      if (_isTextLike(field.type)) {
        final text = _headerTextControllers[field.key]?.text.trim() ?? '';
        if (text.isEmpty) {
          _state.fieldValues.remove(field.key);
        } else {
          _state.fieldValues[field.key] = text;
        }
      }
    }
    persistStructuredHeaderControlsToFieldValues(
      fields: _effectiveProfile.structuredHeaderFields,
      fieldValues: _state.fieldValues,
      enumSelections: _headerEnumSelections,
      dateTimes: _headerDateTimes,
      entitySelections: _headerEntitySelections,
    );
    _restoreSavedHandoffIntoState();
  }

  String get _runtimeTitle {
    if (_isInProcessQualityCheck ||
        _isFinalControl ||
        _isLineClearance ||
        _isWorkspace5sCleaning) {
      final profileTitle = _effectiveProfile.runtimeScreenTitle.trim();
      if (profileTitle.isNotEmpty) return profileTitle;
    }
    return widget.isCompanyEvidence
        ? widget.evidenceConfig!.displayName
        : widget.stationConfig!.title;
  }

  String get _formHeadingTitle {
    if (_isInProcessQualityCheck ||
        _isFinalControl ||
        _isLineClearance ||
        _isWorkspace5sCleaning) {
      final t = _effectiveProfile.runtimeScreenTitle.trim();
      if (t.isNotEmpty) return t;
    }
    return _effectiveProfile.displayName;
  }

  Future<void> _reloadStructuredStateForActiveSession() async {
    try {
      final loaded = await _catalogService.loadActiveState(
        companyId: _companyId,
        stationSlot: widget.isCompanyEvidence
            ? null
            : widget.stationConfig!.effectiveStationSlot,
        evidenceConfigId: widget.isCompanyEvidence
            ? widget.evidenceConfig!.evidenceConfigId
            : null,
        profile: _effectiveProfile,
      );
      if (!mounted || loaded == null) return;
      setState(() {
        _state = loaded;
        _syncHeaderControllersFromState();
        _ensurePackagingControllerFromSession();
        _ensureFirstPieceInspectorFromSession();
        _syncInProcessWorkPlaceFields();
      });
    } catch (_) {}
  }

  void _hydrateFromSession(ProductionStationWorkSession session) {
    final firstLoad = _hydratedSessionId != session.id;
    if (firstLoad) {
      _hydratedSessionId = session.id;
      _state.fieldValues = Map<String, dynamic>.from(
        session.fieldValues ?? const {},
      );
      _ensureFirstPieceDefaults();
      _ensureFirstPieceInspectorFromSession();
    }
    _rememberSavedHandoff(session.fieldValues);
    _restoreSavedHandoffIntoState();
    _syncHeaderControllersFromState();
    if (!firstLoad) return;
    _ensurePackagingControllerFromSession();
    _syncInProcessWorkPlaceFields();
    if (_isStructuredLite) {
      unawaited(_reloadStructuredStateForActiveSession());
    }
    if (_isFinalControl || _isPackagingControl || _isInProcessQualityCheck) {
      unawaited(_reloadFinalControlBomPicker());
    }
    if (_usesOmpBomMaterialPicker) {
      unawaited(_reloadOmpPrimaryBomPicker());
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  String? _validateBeforeSubmit({required bool forFinish}) {
    _flushHeaderFieldsToState();
    _restoreSavedHandoffIntoState();
    _applyLineClearanceLineNameFromWorkCenter();
    _ensureLoggedInPerformerFromSession();
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _syncInProcessWorkPlaceFields();
    _stripNonOperatorEditableFieldValues();
    _ensureOmpLotSourcePersisted();
    _ensureOmpTraceabilityPersisted();
    if (forFinish && !_canSignVerification) {
      return _effectiveProfile.signedVerifierDeniedMessage;
    }
    final headerError = validateStructuredHeader(
      fields: _effectiveProfile.structuredHeaderFields
          .where((f) => !_hiddenCleaningFieldKeys.contains(f.key))
          .toList(growable: false),
      state: _state,
      entitySelections: _headerEntitySelections,
      enumSelections: _headerEnumSelections,
      dateTimes: _headerDateTimes,
    );
    if (headerError != null) return headerError;

    if (_isPackagingControl && forFinish) {
      final packagingError = _validatePackagingFinish();
      if (packagingError != null) return packagingError;
    }

    if (_isFirstPieceApproval && forFinish) {
      final firstPieceError = _validateFirstPieceFinish();
      if (firstPieceError != null) return firstPieceError;
    }

    if (_isInProcessQualityCheck && forFinish) {
      final inProcessError = _validateInProcessQualityFinish();
      if (inProcessError != null) return inProcessError;
    }

    if (_isFinalControl && forFinish) {
      final finalControlError = _validateFinalControlFinish();
      if (finalControlError != null) return finalControlError;
    }

    if (_isWorkspace5sCleaning && forFinish) {
      final fiveSError = cleaningModeFinishValidationMessage(
        profileKey: _effectiveProfile.profileKey,
        mode: _cleaningChecklistMode,
        enumSelections: _headerEnumSelections,
        fieldValues: _state.fieldValues,
        workplaceZoneId: _headerEntitySelections['workplaceZoneId']?.entityId,
      );
      if (fiveSError != null) return fiveSError;
    }

    if (_isLineClearance && forFinish) {
      final lineError = cleaningModeFinishValidationMessage(
        profileKey: _effectiveProfile.profileKey,
        mode: _cleaningChecklistMode,
        enumSelections: _headerEnumSelections,
        fieldValues: _state.fieldValues,
        workCenterId: _headerEntitySelections['workCenterId']?.entityId,
        machineId: _headerEntitySelections['machineId']?.entityId,
      );
      if (lineError != null) return lineError;
      final siteError =
          lineClearanceSiteVerificationFinishMessage(_state.fieldValues);
      if (siteError != null) return siteError;
    }

    if (_isMaterialPreparation && forFinish) {
      final mpError = _validateMaterialPreparationFinish();
      if (mpError != null) return mpError;
    }

    if (_isOperationMaterialPreparation && forFinish) {
      final ompError = _validateOperationMaterialPreparationFinish();
      if (ompError != null) return ompError;
    }

    if (_isStructuredLite && forFinish) {
      final tableError = validateStructuredTables(tables: _tables, state: _state);
      if (tableError != null) return tableError;
    }
    return null;
  }

  /// M1-I7-B — nalog, proizvod (iz naloga), materijal, lot, količina.
  String? _validateMaterialPreparationFinish({bool requireLot = true}) {
    final orderId = (_headerEntitySelections['productionOrderId']?.entityId ??
            _state.fieldValues['productionOrderId'] ??
            '')
        .toString()
        .trim();
    if (orderId.isEmpty) {
      return 'Odaberite proizvodni nalog prije završavanja evidencije.';
    }
    final productId = (_headerEntitySelections['productId']?.entityId ??
            _state.fieldValues['productId'] ??
            '')
        .toString()
        .trim();
    if (productId.isEmpty) {
      return 'Nalog mora imati proizvod (ili odaberite proizvod u formi).';
    }
    final materialId = (_headerEntitySelections['materialId']?.entityId ??
            _state.fieldValues['materialId'] ??
            '')
        .toString()
        .trim();
    if (materialId.isEmpty) {
      return 'Odaberite materijal prije završavanja evidencije.';
    }
    if (requireLot) {
      final lot = (_state.fieldValues['materialLot'] ??
              _headerTextControllers['materialLot']?.text ??
              '')
          .toString()
          .trim();
      if (lot.isEmpty) {
        return 'Unesite lot / šaržu materijala (obavezno za sljedivost).';
      }
    }
    return null;
  }

  /// M1-I11-B — nakon stripa, lot izvor mora ostati u payloadu za PDF/audit.
  void _ensureOmpLotSourcePersisted() {
    if (!_isOperationMaterialPreparation) return;
    final lot = (_state.fieldValues['materialLot'] ??
            _headerTextControllers['materialLot']?.text ??
            '')
        .toString()
        .trim();
    if (lot.isEmpty) return;
    if ((_state.fieldValues['materialLot'] ?? '').toString().trim().isEmpty) {
      _state.fieldValues['materialLot'] = lot;
    }
    var source = (_state.fieldValues['materialLotSource'] ??
            _headerEnumSelections['materialLotSource'] ??
            '')
        .toString()
        .trim();
    final docId =
        (_state.fieldValues['inventoryLotDocId'] ?? '').toString().trim();
    if (docId.isNotEmpty) {
      source = 'wms';
    } else if (source != 'wms') {
      source = 'manual';
    }
    _state.fieldValues['materialLotSource'] = source;
    _headerEnumSelections['materialLotSource'] = source;
  }

  /// M1-I11-B — WMS ili jasno označen ručni fallback.
  String? _validateOmpLotSourceForFinish() {
    final lot = (_state.fieldValues['materialLot'] ??
            _headerTextControllers['materialLot']?.text ??
            '')
        .toString()
        .trim();
    if (lot.isEmpty) return null;
    _ensureOmpLotSourcePersisted();
    final source = (_state.fieldValues['materialLotSource'] ?? '').toString().trim();
    if (source == 'wms') {
      final docId =
          (_state.fieldValues['inventoryLotDocId'] ?? '').toString().trim();
      if (docId.isEmpty) {
        return 'WMS lot nije potpuno snimljen — ponovo odaberite ili skenirajte lot.';
      }
    }
    return null;
  }

  /// M1-I8-B — nalog + faza + mjesto rada + materijal + lot (ako obavezan) + svrha.
  String? _validateOperationMaterialPreparationFinish() {
    _ensureOmpTraceabilityPersisted();
    final requireLot = ompLotIsRequired(_state.fieldValues);
    final base = _validateMaterialPreparationFinish(requireLot: requireLot);
    if (base != null) return base;

    if (requireLot) {
      final ompLotErr = _validateOmpLotSourceForFinish();
      if (ompLotErr != null) return ompLotErr;
    } else {
      // Lot nije obavezan — očisti djelomičan unos da ne ostane lažni izvor.
      final lot = (_state.fieldValues['materialLot'] ??
              _headerTextControllers['materialLot']?.text ??
              '')
          .toString()
          .trim();
      if (lot.isEmpty) {
        _clearOmpWmsLotFields();
      }
    }

    final phase = (_headerEnumSelections['operationPhaseKey'] ??
            _state.fieldValues['operationPhaseKey'] ??
            '')
        .toString()
        .trim();
    if (phase.isEmpty) {
      return 'Odaberite fazu operacije prije završavanja evidencije.';
    }

    final type = (_headerEnumSelections['workContextType'] ??
            _state.fieldValues['workContextType'] ??
            '')
        .toString()
        .trim();
    if (type != 'machine' && type != 'workbench') {
      return 'Odaberite mjesto rada: Mašina ili Radni sto.';
    }
    if (type == 'machine') {
      final mid = (_headerEntitySelections['machineId']?.entityId ??
              _state.fieldValues['machineId'] ??
              '')
          .toString()
          .trim();
      if (mid.isEmpty) {
        return 'Odaberite mašinu prije završavanja evidencije.';
      }
    } else {
      final wid = (_headerEntitySelections['workbenchId']?.entityId ??
              _state.fieldValues['workbenchId'] ??
              '')
          .toString()
          .trim();
      if (wid.isEmpty) {
        return 'Odaberite radni sto prije završavanja evidencije.';
      }
    }

    final purpose = (_headerEnumSelections['preparationPurpose'] ??
            _state.fieldValues['preparationPurpose'] ??
            '')
        .toString()
        .trim();
    if (purpose.isEmpty) {
      return 'Odaberite svrhu pripreme prije završavanja evidencije.';
    }

    // M1-I9-B — kad je BOM-bound aktivan, materijal mora biti iz PRIMARY stavki.
    if (_ompBomPicker.isBomBound) {
      final mid = (_headerEntitySelections['materialId']?.entityId ??
              _state.fieldValues['materialId'] ??
              '')
          .toString()
          .trim();
      final allowed =
          _ompBomPicker.items.map((e) => e.id.trim()).where((e) => e.isNotEmpty);
      if (mid.isNotEmpty && !allowed.contains(mid)) {
        return 'Odaberite materijal iz primarne sastavnice (BOM), '
            'ne iz šireg kataloga.';
      }
    }
    return null;
  }

  /// M1-I2-F7 — kraj kontrole, vremenski redoslijed, operater proizvodnje.
  String? _validatePackagingFinish() {
    // M1-I15-C1 — Operater kvaliteta (controller) = prijavljeni korisnik.
    if (_userRole != ProductionAccessHelper.roleQualityOperator) {
      return 'Kontrolu pakovanja može završiti samo Operater kvaliteta.';
    }
    final started = _headerDateTimes['checkStartedAt'] ??
        StructuredDateTimeValue.parse(_state.fieldValues['checkStartedAt']);
    final finished = _headerDateTimes['checkFinishedAt'] ??
        StructuredDateTimeValue.parse(_state.fieldValues['checkFinishedAt']);
    if (started == null) {
      return 'Unesite početak kontrole prije završavanja evidencije.';
    }
    if (finished == null) {
      return 'Unesite kraj kontrole prije završavanja evidencije.';
    }
    if (finished.isBefore(started)) {
      return 'Kraj kontrole mora biti nakon početka kontrole.';
    }
    final packagingOp = _headerEntitySelections['packagingOperatorEmployeeId'];
    final packagingOpId = (packagingOp?.entityId ??
            _state.fieldValues['packagingOperatorEmployeeId'] ??
            '')
        .toString()
        .trim();
    if (packagingOpId.isEmpty) {
      return 'Odaberite operatera proizvodnje prije završavanja evidencije.';
    }
    return null;
  }

  /// M1-I3-F — početak/kraj kontrole obavezni (isto poslovno pravilo kao packaging).
  String? _validateFirstPieceFinish() {
    // M1-I15-C3 — Operater kvaliteta (inspector) = prijavljeni korisnik.
    if (_isFirstPieceApproval &&
        _userRole != ProductionAccessHelper.roleQualityOperator) {
      return 'Odobrenje prvog komada može završiti samo Operater kvaliteta.';
    }
    final started = _headerDateTimes['inspectionStartedAt'] ??
        StructuredDateTimeValue.parse(
          _state.fieldValues['inspectionStartedAt'],
        );
    final finished = _headerDateTimes['inspectionFinishedAt'] ??
        StructuredDateTimeValue.parse(
          _state.fieldValues['inspectionFinishedAt'],
        );
    if (started == null) {
      return 'Unesite početak kontrole prije završavanja evidencije.';
    }
    if (finished == null) {
      return 'Unesite kraj kontrole prije završavanja evidencije.';
    }
    if (finished.isBefore(started)) {
      return 'Kraj kontrole mora biti nakon početka kontrole.';
    }
    return null;
  }

  /// M1-I4-C — mjesto rada + proizvodni operater + vremena kontrole.
  String? _validateInProcessQualityFinish() {
    // M1-I15-C2 — Operater kvaliteta (inspector) = prijavljeni korisnik.
    if (_userRole != ProductionAccessHelper.roleQualityOperator) {
      return 'Procesnu kontrolu može završiti samo Operater kvaliteta.';
    }
    final type = (_headerEnumSelections['workContextType'] ??
            _state.fieldValues['workContextType'] ??
            '')
        .toString()
        .trim();
    if (type != 'machine' && type != 'workbench') {
      return 'Odaberite mjesto rada: Mašina ili Radni sto.';
    }
    if (type == 'machine') {
      final mid = (_headerEntitySelections['machineId']?.entityId ??
              _state.fieldValues['machineId'] ??
              '')
          .toString()
          .trim();
      if (mid.isEmpty) {
        return 'Odaberite mašinu prije završavanja evidencije.';
      }
    } else {
      final wid = (_headerEntitySelections['workbenchId']?.entityId ??
              _state.fieldValues['workbenchId'] ??
              '')
          .toString()
          .trim();
      if (wid.isEmpty) {
        return 'Odaberite radni sto prije završavanja evidencije.';
      }
    }
    final opId =
        (_headerEntitySelections['productionOperatorEmployeeId']?.entityId ??
                _state.fieldValues['productionOperatorEmployeeId'] ??
                '')
            .toString()
            .trim();
    if (opId.isEmpty) {
      return 'Odaberite proizvodnog operatera prije završavanja evidencije.';
    }
    return _validateFirstPieceFinish();
  }

  /// HOTFIX-30 — Finalna kontrola: Operater kvaliteta = prijavljeni korisnik.
  String? _validateFinalControlFinish() {
    if (_userRole != ProductionAccessHelper.roleQualityOperator) {
      return finalControlQualityOperatorFinishDeniedMessage;
    }
    return null;
  }

  /// Ako kraj kontrole nije unesen — ponudi „Postavi sada”.
  /// `false` = korisnik odustao; `true` = vrijeme postoji ili je postavljeno.
  Future<bool> _offerSetFinishTimeNowIfMissing({
    required String fieldKey,
  }) async {
    final finished = _headerDateTimes[fieldKey] ??
        StructuredDateTimeValue.parse(_state.fieldValues[fieldKey]);
    if (finished != null) return true;

    final setNow = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kraj kontrole'),
        content: const Text(
          'Kraj kontrole nije unesen. Postaviti sadašnje vrijeme i nastaviti sa završetkom?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Postavi sada'),
          ),
        ],
      ),
    );
    if (setNow != true || !mounted) return false;
    final now = DateTime.now();
    setState(() {
      _headerDateTimes[fieldKey] = now;
      _state.fieldValues[fieldKey] = structuredDateTimePayload(now);
    });
    return true;
  }

  Future<void> _startSession() async {
    if (!_canStartEvidence) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(catalogEvidenceStartDeniedMessage)),
      );
      return;
    }
    await _runBusy(() async {
      final started = await _catalogService.startSessionDetailed(
        companyId: _companyId,
        stationSlot: widget.isCompanyEvidence
            ? null
            : widget.stationConfig!.effectiveStationSlot,
        evidenceConfigId: widget.isCompanyEvidence
            ? widget.evidenceConfig!.evidenceConfigId
            : null,
      );
      if (!started.resumed) {
        _resetFormForNewEvidence();
      }
      setState(() {
        _closedSession = null;
        _hydratedSessionId = started.resumed ? null : started.session.id;
        if (_usesCallableEvidenceRuntime) {
          _callableActiveSession = started.session;
        }
      });
      if (started.resumed) {
        _hydrateFromSession(started.session);
        if (started.structuredTables.isNotEmpty) {
          setState(() {
            _state = hydrateCatalogEvidenceState(
              fieldValues: started.session.fieldValues,
              structuredTables: started.structuredTables,
              profile: _effectiveProfile,
            );
            _syncHeaderControllersFromState();
            _ensurePackagingControllerFromSession();
            _ensureFirstPieceInspectorFromSession();
            _syncInProcessWorkPlaceFields();
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            started.resumed
                ? 'Nastavljena aktivna evidencija.'
                : 'Evidencija pokrenuta.',
          ),
        ),
      );
    });
  }

  Future<void> _saveSession(ProductionStationWorkSession session) async {
    final validationError = _validateBeforeSubmit(forFinish: false);
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }
    _ensureOmpLotSourcePersisted();
    await _runBusy(() async {
      if (_isStructuredLite) {
        final saved = await _catalogService.saveState(
          companyId: _companyId,
          sessionId: session.id,
          profile: _effectiveProfile,
          state: _state,
        );
        if (_usesCallableEvidenceRuntime) {
          _callableActiveSession = saved;
        }
        _rememberSavedHandoff(saved.fieldValues ?? _state.fieldValues);
      } else {
        final saved = await _catalogService.saveFlatState(
          companyId: _companyId,
          sessionId: session.id,
          fieldValues: Map<String, dynamic>.from(_state.fieldValues),
        );
        if (_usesCallableEvidenceRuntime) {
          _callableActiveSession = saved;
        }
        _rememberSavedHandoff(saved.fieldValues ?? _state.fieldValues);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci sačuvani.')),
      );
    });
  }

  Future<void> _finishSession(ProductionStationWorkSession session) async {
    if (!_canSignVerification) {
      _showValidationError(_effectiveProfile.signedVerifierDeniedMessage);
      return;
    }
    _flushHeaderFieldsToState();
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();

    if (_isPackagingControl) {
      final offered = await _offerSetFinishTimeNowIfMissing(
        fieldKey: 'checkFinishedAt',
      );
      if (!offered) return;
    }
    if (_isFirstPieceApproval || _isInProcessQualityCheck) {
      final offered = await _offerSetFinishTimeNowIfMissing(
        fieldKey: 'inspectionFinishedAt',
      );
      if (!offered) return;
    }

    final validationError = _validateBeforeSubmit(forFinish: true);
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }

    final ok = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Završi evidenciju'),
        content: const Text(
          'Zatvoriti evidenciju i poslati podatke na validaciju?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Završi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    String? containmentAction;
    final needsAction = EvidenceOutcomeActionHelper.requiresAction(
      profileKey: _effectiveProfile.profileKey,
      fieldValues: Map<String, dynamic>.from(_state.fieldValues),
    );
    if (needsAction) {
      final outcomeLabel = EvidenceOutcomeActionHelper.outcomeLabel(
        profileKey: _effectiveProfile.profileKey,
        fieldValues: Map<String, dynamic>.from(_state.fieldValues),
      );
      containmentAction = await _promptContainmentAction(
        outcomeLabel: outcomeLabel,
      );
      if (containmentAction == null || !mounted) return;
    }

    ProductionStationWorkSession? finished;
    await _runBusy(() async {
      final closed = _isStructuredLite
          ? await _catalogService.finishState(
              companyId: _companyId,
              sessionId: session.id,
              profile: _effectiveProfile,
              state: _state,
              containmentAction: containmentAction,
            )
          : await _catalogService.finishFlatState(
              companyId: _companyId,
              sessionId: session.id,
              fieldValues: Map<String, dynamic>.from(_state.fieldValues),
              containmentAction: containmentAction,
            );
      if (!mounted) return;
      finished = closed;
      final keepClosedForm = _canStartEvidence;
      setState(() {
        _closedSession = keepClosedForm ? closed : null;
        _hydratedSessionId = keepClosedForm ? closed.id : null;
        if (_usesCallableEvidenceRuntime) {
          _callableActiveSession = null;
        }
      });
      if (_usesCallableEvidenceRuntime) {
        unawaited(_reloadClosedEvidenceRecords());
      }
      _syncHeaderControllersFromState();
      final ncrCode = (closed.outcomeNcrCode ?? '').trim();
      final outcomeLabel = (closed.outcomeLabel ?? '').trim();
      final holdNote = closed.outcomeHoldApplied
          ? ' Lot stavljen na HOLD.'
          : '';
      final snack = closed.outcomeActionRequired && ncrCode.isNotEmpty
          ? 'Evidencija završena. Otvoren NCR $ncrCode'
              '${outcomeLabel.isEmpty ? '' : ' ($outcomeLabel)'}.$holdNote'
          : 'Evidencija završena.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snack)),
      );
    });
    final closedForReview = finished;
    if (!mounted || closedForReview == null || _canStartEvidence) return;
    final sessionId = closedForReview.id.trim();
    if (sessionId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDrivenEvidenceDetailScreen(
          companyData: widget.companyData,
          sessionId: sessionId,
        ),
      ),
    );
  }

  Future<String?> _promptContainmentAction({String? outcomeLabel}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mjera zadržavanja'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  outcomeLabel == null || outcomeLabel.isEmpty
                      ? 'Negativan ili uslovan ishod zahtijeva kratku mjeru: '
                          'što je odmah uradjeno s komadima, lotom ili nalogom.'
                      : 'Ishod: $outcomeLabel. Unesi kratku mjeru zadržavanja '
                          '(što je odmah uradjeno s komadima, lotom ili nalogom).',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Mjera zadržavanja',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.length < 8) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unesi najmanje 8 znakova za mjeru zadržavanja.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text('Nastavi'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _applyScanResult(StructuredScanResolveResult result) {
    if (!result.isKnown) return;
    final searchResult = result.toSearchResult();
    if (searchResult == null) return;

    if (result.type == 'production_order') {
      ProductionStationProfileField? field;
      for (final f in _effectiveProfile.structuredHeaderFields) {
        if (f.key == 'productionOrderId') {
          field = f;
          break;
        }
      }
      if (field == null) return;
      final orderField = field;
      final selection = StructuredEntitySelection.fromSearchResult(
        fieldKey: orderField.key,
        result: searchResult,
        valueField: orderField.valueField,
      );
      setState(() {
        _headerEntitySelections[orderField.key] = selection;
        _state.fieldValues[orderField.key] = selection.entityId;
        _applyPackagingHeaderSnapshotsFromSelections();
        _applyFirstPieceHeaderFromOrderSelection(forceFromOrder: true);
        _applyInProcessHeaderFromOrderSelection(forceFromOrder: true);
        _applyFinalControlHeaderFromOrderSelection(forceFromOrder: true);
        _applyMaterialPreparationHeaderFromOrderSelection(forceFromOrder: true);
        _applyBatchMixingBomContextFromHeader();
        _syncHeaderControllersFromState();
      });
      final filled = <String>[
        'Nalog: ${selection.displayLabel}',
        if ((selection.raw['productId'] ?? '').toString().trim().isNotEmpty)
          'proizvod',
        if ((selection.raw['machineId'] ?? '').toString().trim().isNotEmpty)
          'mašina',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            filled.length > 1
                ? '${filled.first} — popunjeno: ${filled.skip(1).join(', ')}'
                : filled.first,
          ),
        ),
      );
      return;
    }

    if (result.type == 'product') {
      ProductionStationProfileField? headerProduct;
      for (final f in _effectiveProfile.structuredHeaderFields) {
        if (f.key == 'productId') {
          headerProduct = f;
          break;
        }
      }
      if (headerProduct != null &&
          (_headerEntitySelections['productId'] == null ||
              _isPackagingControl)) {
        final productField = headerProduct;
        final selection = StructuredEntitySelection.fromSearchResult(
          fieldKey: productField.key,
          result: searchResult,
          valueField: productField.valueField,
        );
        setState(() {
          _headerEntitySelections[productField.key] = selection;
          _state.fieldValues[productField.key] = selection.entityId;
          _applyPackagingHeaderSnapshotsFromSelections();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proizvod: ${selection.displayLabel}')),
        );
        return;
      }

      if (!_isStructuredLite || _tables.isEmpty) return;
      final table = _tables.first;
      ProductionStationProfileField? productCol;
      for (final c in table.operatorColumns) {
        if (c.key == 'productId') {
          productCol = c;
          break;
        }
      }
      if (productCol == null) return;
      final row = StructuredRepeatableRow.empty();
      final selection = StructuredEntitySelection.fromSearchResult(
        fieldKey: productCol.key,
        result: searchResult,
        valueField: productCol.valueField,
      );
      row.setEntitySelection(selection);
      final next = List<StructuredRepeatableRow>.from(_state.rowsFor(table.key))
        ..add(row);
      setState(() => _state.setRows(table.key, next));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stavka dodana: ${searchResult.displayLabel}')),
      );
    }
  }

  List<Widget> _buildAppBarActions(ProductionStationWorkSession? session) {
    final active = session?.isActive == true && _closedSession == null;
    return [
      if (session == null || !active)
        if (_canStartEvidence)
          IconButton(
            tooltip: 'Pokreni evidenciju',
            icon: const Icon(Icons.play_arrow),
            onPressed: _busy || !_plantAccessOk ? null : _startSession,
          ),
      if (active) ...[
        IconButton(
          tooltip: 'Sačuvaj',
          icon: const Icon(Icons.save_outlined),
          onPressed: _busy ? null : () => _saveSession(session!),
        ),
        IconButton(
          tooltip: _canSignVerification
              ? 'Završi evidenciju'
              : _effectiveProfile.signedVerifierDeniedMessage,
          icon: const Icon(Icons.check_circle_outline),
          onPressed: _busy || !_canSignVerification
              ? null
              : () => _finishSession(session!),
        ),
      ],
    ];
  }

  Widget _buildInputSection({
    required ProductionStationWorkSession? session,
    required bool formEnabled,
  }) {
    final plantLabel = _plantDisplayLabel.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formHeadingTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              CatalogEvidenceHelpTexts.infoIconForProfile(
                profileKey: _effectiveProfile.profileKey,
                displayName: _effectiveProfile.displayName,
                description: _effectiveProfile.description,
              ),
              if (plantLabel.isNotEmpty)
                Text(
                  'Pogon: $plantLabel',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? 'Nema aktivne evidencije.'
                : session.isActive
                ? 'Aktivna evidencija'
                : 'Evidencija završena.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (!_isLineClearanceVerifierHandoff)
          StructuredHeaderSection(
            profile: _effectiveProfile,
            companyId: _companyId,
            plantKey: _plantKey,
            plantDisplayLabel: _plantDisplayLabel.trim().isEmpty
                ? null
                : _plantDisplayLabel.trim(),
            state: _state,
            workBaths: const [],
            searchService: _searchService,
            entitySelections: _headerEntitySelections,
            enumSelections: _headerEnumSelections,
            dateTimes: _headerDateTimes,
            textControllers: _headerTextControllers,
            enabled: formEnabled && !_lockCleaningHandoffHeader,
            showOrderScan: !_isWorkspace5sCleaning && !_isLineClearance,
            headerNotice: _isWorkspace5sCleaning
                ? _buildWorkspace5sHeaderNotice(context)
                : _isLineClearance
                ? _buildLineClearanceHeaderNotice(context)
                : (_isFirstPieceApproval || _isToolChangeover)
                    ? _buildFirstPieceHeaderNotice(context)
                    : _buildOmpBomHeaderNotice(context),
            entitySearchOverrides: {
              if (_isMaterialPrepFamily)
                'materialId': _searchOmpMaterial,
              if (_isPackagingControl)
                'packagingOperatorEmployeeId': _searchPackagingOperator,
              if (_isInProcessQualityCheck)
                'productionOperatorEmployeeId': _searchProductionOperator,
              if (_isFirstPieceApproval || _isToolChangeover)
                'productId': _searchFirstPieceProduct,
              if (_isLineClearance ||
                  _isWorkspace5sCleaning ||
                  _isToolChangeover)
                'performedByEmployeeId': (q) =>
                    _searchPersonForField('performedByEmployeeId', q),
              if (_isLineClearance && !_hasSignedLoggedInVerifier)
                'verifiedByEmployeeId': (q) =>
                    _searchPersonForField('verifiedByEmployeeId', q),
              if (_isWorkspace5sCleaning)
                'workplaceZoneId': _searchWorkspace5sZones,
            },
            fieldOverrides: {
              if (_isMaterialPrepFamily && _ompBomPicker.isBomBound)
                'materialId': _ompMaterialFieldOverride(
                  minSearchChars: 0,
                  helperText: _isOperationMaterialPreparation
                      ? 'Odaberite stavku iz primarne sastavnice (šifra / naziv). '
                          'Normativ se predlaže automatski.'
                      : 'Odaberite materijal iz primarne sastavnice (šifra / naziv). '
                          'Kontrolisani izbor — nije slobodan unos.',
                ),
              if (_isMaterialPrepFamily &&
                  _ompBomPicker.isSoftFallback)
                'materialId': _ompMaterialFieldOverride(
                  helperText:
                      'BOM nije pronađen — kontrolisani izbor iz kataloga (privremeno).',
                ),
              if (_isPackagingControl)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'packagingOperatorEmployeeId')
                    f.key: _packagingOperatorFieldOverride(f),
              if (_isInProcessQualityCheck)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'productionOperatorEmployeeId')
                    f.key: _productionOperatorFieldOverride(f),
              if (_isFirstPieceApproval || _isToolChangeover)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'productId')
                    f.key: _firstPieceProductFieldOverride(f),
              if (_isLineClearance ||
                  _isWorkspace5sCleaning ||
                  _isToolChangeover)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'performedByEmployeeId' ||
                      (f.key == 'verifiedByEmployeeId' &&
                          !_hasSignedLoggedInVerifier))
                    f.key: _personFieldOverride(f),
              if (_isLineClearance)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'previousProductId' || f.key == 'nextProductId')
                    f.key: _lineClearanceProductFieldOverride(f),
              if (_isWorkspace5sCleaning)
                for (final f in _effectiveProfile.fields)
                  if (f.key == 'workplaceZoneId')
                    f.key: f.copyWith(
                      minSearchChars: 0,
                      helperText:
                          'Odaberite radno mjesto pogona ili 5S zonu. '
                          'Drugo samo ako zona nije u šifrarniku.',
                    ),
            },
            recentEntitySuggestions: {
              if (_isInProcessQualityCheck &&
                  _recentProductionOperators.isNotEmpty)
                'productionOperatorEmployeeId': _recentProductionOperators,
              if (_isMaterialPrepFamily &&
                  _ompBomPicker.isBomBound &&
                  _ompBomPicker.items.length <= 12)
                'materialId': _ompBomPicker.items,
              if (_isWorkspace5sCleaning)
                'workplaceZoneId': mergeWorkspace5sZoneChoices(
                  plantWorkbenches: _plantWorkplaceZones,
                  query: '',
                ),
            },
            recentEntitySuggestionLabels: {
              if (_isMaterialPrepFamily &&
                  _ompBomPicker.isBomBound &&
                  _ompBomPicker.items.length <= 12)
                'materialId': 'Stavke primarne sastavnice',
              if (_isWorkspace5sCleaning)
                'workplaceZoneId': 'Zone i radna mjesta pogona',
            },
            excludedFieldKeys: {
              if (_isPackagingControl || _isFinalControl) 'controllerEmployeeId',
              if (_isFirstPieceApproval || _isInProcessQualityCheck)
                'inspectorEmployeeId',
              if (_hasSignedLoggedInVerifier)
                _effectiveProfile.signedVerifierFieldKey,
              if (_lockPerformedByField) 'performedByEmployeeId',
              // M1-I4-C — searchWorkCenters nije u runtime pretrazi; mjesto rada = Mašina/Radni sto.
              if (_isInProcessQualityCheck) 'workCenterId',
              if (_isLineClearance) ...lineClearanceHiddenOrderFieldKeys,
              if (_isLineClearanceVerifierHandoff)
                ...lineClearanceVerifierInputKeys,
              // M1-I11-B — lot UI je zasebna sekcija (scan / picker / soft fallback).
              if (_isOperationMaterialPreparation) ...{
                'materialLot',
                'materialLotSource',
                'inventoryLotDocId',
                'batchNumberSnapshot',
                'warehouseNameSnapshot',
                'inventoryLotStatusSnapshot',
                'lotAvailableQtySnapshot',
                'lotUnitSnapshot',
                ompBomItemKindSnapshot,
                ompTraceabilityModeSnapshot,
                ompLotRequiredSnapshot,
              },
              ..._hiddenCleaningFieldKeys,
            },
            onFieldChanged: () {
              _applyLineClearanceLineNameFromWorkCenter();
              _applyPackagingHeaderSnapshotsFromSelections();
              if (_isFirstPieceApproval || _isToolChangeover) {
                _applyFirstPieceHeaderFromOrderSelection();
                if (_isFirstPieceApproval) {
                  _ensureFirstPieceInspectorFromSession();
                }
              }
              if (_isInProcessQualityCheck) {
                _applyInProcessHeaderFromOrderSelection();
                _ensureFirstPieceInspectorFromSession();
                _syncInProcessWorkPlaceFields();
                unawaited(
                  _rememberProductionOperatorSelection(
                    _headerEntitySelections['productionOperatorEmployeeId'],
                  ),
                );
              }
              if (_isFinalControl) {
                _applyFinalControlHeaderFromOrderSelection();
              }
              if (_isMaterialPrepFamily) {
                _applyMaterialPreparationHeaderFromOrderSelection();
              }
              if (_isBatchMixing) {
                _applyBatchMixingBomContextFromHeader();
              }
              if (_isOperationMaterialPreparation) {
                _syncInProcessWorkPlaceFields();
                _applyOmpMaterialSelectionSideEffects();
              }
              setState(() {});
            },
            onScanResolved: _applyScanResult,
          ),
          if (_isLineClearanceVerifierHandoff) ...[
            const SizedBox(height: 12),
            _buildLineClearanceSiteVerificationCard(formEnabled: formEnabled),
          ],
          if (_lockPerformedByField && !_isLineClearanceVerifierHandoff) ...[
            const SizedBox(height: 12),
            _buildPerformedByHandoffCard(),
          ],
          if (_hasSignedLoggedInVerifier) ...[
            const SizedBox(height: 12),
            _buildSignedVerifierCard(formEnabled: formEnabled),
          ],
          if (_isFinalControl) ...[
            const SizedBox(height: 12),
            _buildLoggedInQualityOperatorCard(),
          ],
          if (_isOperationMaterialPreparation) ...[
            const SizedBox(height: 12),
            if (!ompLotIsRequired(_state.fieldValues) &&
                (_headerEntitySelections['materialId']?.entityId ??
                        _state.fieldValues['materialId'] ??
                        '')
                    .toString()
                    .trim()
                    .isNotEmpty)
              Material(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ompLotNotRequiredBanner,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const OmpLotTraceabilityHelpIcon(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vrsta: ${bomItemKindLabelBs((_state.fieldValues[ompBomItemKindSnapshot] ?? '').toString())} · '
                        'Sljedivost: ${bomTraceabilityModeLabelBs((_state.fieldValues[ompTraceabilityModeSnapshot] ?? '').toString())}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              OmpWmsLotSection(
                key: ValueKey(
                  (_headerEntitySelections['materialId']?.entityId ??
                          _state.fieldValues['materialId'] ??
                          '')
                      .toString(),
                ),
                companyId: _companyId,
                materialId: (_headerEntitySelections['materialId']?.entityId ??
                        _state.fieldValues['materialId'] ??
                        '')
                    .toString()
                    .trim(),
                materialLotController: _headerTextControllers.putIfAbsent(
                  'materialLot',
                  TextEditingController.new,
                ),
                enabled: formEnabled,
                initialSource:
                    (_state.fieldValues['materialLotSource'] ?? '').toString(),
                onWmsLotApplied: (lot) {
                  setState(() => _applyOmpWmsLotSelection(lot));
                },
                onManualLotApplied: (text) {
                  setState(() => _applyOmpManualLot(text));
                },
                onCleared: () {
                  setState(_clearOmpWmsLotFields);
                },
              ),
          ],
          if (_isPackagingControl) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Operater kvaliteta',
                border: OutlineInputBorder(),
                helperText:
                    'Automatski iz prijave — samo uloga Operater kvaliteta. '
                    'Nije slobodan unos imena.',
              ),
              child: Text(
                _processControllerDisplayName.trim(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (_isFirstPieceApproval) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Operater kvaliteta',
                border: OutlineInputBorder(),
                helperText:
                    'Automatski iz prijave — samo uloga Operater kvaliteta. '
                    'Nije slobodan unos imena.',
              ),
              child: Text(
                _processControllerDisplayName.trim(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (_isInProcessQualityCheck) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Operater kvaliteta',
                border: OutlineInputBorder(),
                helperText:
                    'Automatski iz prijave — samo uloga Operater kvaliteta. '
                    'Nije slobodan unos imena.',
              ),
              child: Text(
                _processControllerDisplayName.trim(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (_isStructuredLite)
            ..._tables.map(
              (table) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: StructuredRepeatableTableSection(
                  tableDef: table,
                  profile: _effectiveProfile,
                  companyId: _companyId,
                  plantKey: _plantKey,
                  plantDisplayLabel: _plantDisplayLabel.trim().isEmpty
                      ? null
                      : _plantDisplayLabel.trim(),
                  rows: _state.rowsFor(table.key),
                  searchService: _searchService,
                  enabled: formEnabled,
                  headerProductSelection:
                      (_isPackagingControl ||
                              _isInProcessQualityCheck ||
                              _isFinalControl)
                          ? _headerEntitySelections['productId']
                          : null,
                  tableNotice: table.key == 'controlled_items'
                      ? _buildFinalControlBomTableNotice(context)
                      : (table.key == 'packaging_check_lines'
                          ? _buildPackagingBomTableNotice(context)
                          : (table.key == 'inspection_lines'
                              ? _buildInProcessBomTableNotice(context)
                              : (table.key == 'mix_components'
                                  ? _buildBatchMixingBomTableNotice(context)
                                  : null))),
                  entitySearchOverrides: {
                    if (_isFinalControl && table.key == 'controlled_items')
                      'productId': _searchFinalControlProduct,
                    if (_isInProcessQualityCheck &&
                        table.key == 'inspection_lines')
                      'productId': _searchFinalControlProduct,
                    if (_isPackagingControl &&
                        table.key == 'packaging_check_lines' &&
                        (_headerEntitySelections['productId']?.entityId ?? '')
                            .toString()
                            .trim()
                            .isEmpty)
                      'productId': _searchFinalControlProduct,
                    if (_isBatchMixing && table.key == 'mix_components')
                      'componentMaterialId': _searchOmpMaterial,
                  },
                  fieldOverrides: {
                    if ((_isFinalControl && table.key == 'controlled_items') ||
                        (_isInProcessQualityCheck &&
                            table.key == 'inspection_lines')) ...{
                      if (_fcBomPicker.isBomBound)
                        for (final col in table.columns)
                          if (col.key == 'productId')
                            col.key: _finalControlRowProductFieldOverride(
                              col,
                              minSearchChars: 0,
                              helperText:
                                  'Odaberite proizvod naloga ili stavku iz '
                                  'primarne sastavnice (šifra / naziv).',
                            ),
                      if (_fcBomPicker.isSoftFallback)
                        for (final col in table.columns)
                          if (col.key == 'productId')
                            col.key: _finalControlRowProductFieldOverride(
                              col,
                              minSearchChars: 2,
                              helperText:
                                  'Sastavnica nije dostupna — kontrolisani izbor '
                                  'iz šireg kataloga (privremeno).',
                            ),
                    },
                    if (_isPackagingControl &&
                        table.key == 'packaging_check_lines' &&
                        (_headerEntitySelections['productId']?.entityId ?? '')
                            .toString()
                            .trim()
                            .isEmpty &&
                        _fcBomPicker.isBomBound)
                      for (final col in table.columns)
                        if (col.key == 'productId')
                          col.key: _finalControlRowProductFieldOverride(
                            col,
                            minSearchChars: 0,
                            helperText:
                                'Odaberite proizvod naloga ili stavku iz '
                                'primarne sastavnice (šifra / naziv).',
                          ),
                    if (_isPackagingControl &&
                        table.key == 'packaging_check_lines' &&
                        (_headerEntitySelections['productId']?.entityId ?? '')
                            .toString()
                            .trim()
                            .isEmpty &&
                        _fcBomPicker.isSoftFallback)
                      for (final col in table.columns)
                        if (col.key == 'productId')
                          col.key: _finalControlRowProductFieldOverride(
                            col,
                            minSearchChars: 2,
                            helperText:
                                'Sastavnica nije dostupna — kontrolisani izbor '
                                'iz šireg kataloga (privremeno).',
                          ),
                    if (_isBatchMixing && table.key == 'mix_components') ...{
                      if (_ompBomPicker.isBomBound)
                        for (final col in table.columns)
                          if (col.key == 'componentMaterialId')
                            col.key: _finalControlRowProductFieldOverride(
                              col,
                              minSearchChars: 0,
                              helperText:
                                  'Odaberite komponentu iz primarne sastavnice '
                                  '(šifra / naziv).',
                            ),
                      if (_ompBomPicker.isSoftFallback)
                        for (final col in table.columns)
                          if (col.key == 'componentMaterialId')
                            col.key: _finalControlRowProductFieldOverride(
                              col,
                              minSearchChars: 2,
                              helperText:
                                  'Sastavnica nije dostupna — kontrolisani izbor '
                                  'iz šireg kataloga (privremeno).',
                            ),
                    },
                  },
                  recentEntitySuggestions: {
                    if (((_isFinalControl &&
                                table.key == 'controlled_items') ||
                            (_isInProcessQualityCheck &&
                                table.key == 'inspection_lines')) &&
                        _fcBomPicker.isBomBound)
                      'productId': buildFinalControlBomProductChoices(
                        bom: _fcBomPicker,
                        orderProduct: () {
                          final sel = _headerEntitySelections['productId'];
                          if (sel == null || sel.entityId.trim().isEmpty) {
                            return null;
                          }
                          return StructuredEntitySearchResult(
                            id: sel.entityId.trim(),
                            displayLabel: sel.displayLabel,
                            secondaryLabel: 'Proizvod naloga',
                            raw: Map<String, dynamic>.from(sel.raw),
                          );
                        }(),
                      ),
                    if (_isBatchMixing &&
                        table.key == 'mix_components' &&
                        _ompBomPicker.isBomBound)
                      'componentMaterialId': _ompBomPicker.items,
                  },
                  recentEntitySuggestionLabels: {
                    if (((_isFinalControl &&
                                table.key == 'controlled_items') ||
                            (_isInProcessQualityCheck &&
                                table.key == 'inspection_lines')) &&
                        _fcBomPicker.isBomBound)
                      'productId': 'Proizvodi iz sastavnice',
                    if (_isBatchMixing &&
                        table.key == 'mix_components' &&
                        _ompBomPicker.isBomBound)
                      'componentMaterialId': 'Stavke primarne sastavnice',
                  },
                  onRowsChanged: (rows) {
                    setState(() => _state.setRows(table.key, rows));
                  },
                ),
              ),
            ),
          if (!formEnabled &&
              session != null &&
              !session.isActive &&
              _canStartEvidence) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Nova evidencija'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoSessionPrompt() {
    if (!_plantAccessOk) {
      return const Center(
        child: Text('Nemate pristup ovoj stanici za dodijeljeni pogon.'),
      );
    }

    final compact = CatalogEvidenceViewportSplit.isCompactViewport(context);
    final plantLabel = _plantDisplayLabel.trim();
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _effectiveProfile.displayName,
              style: compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (plantLabel.isNotEmpty) ...[
              SizedBox(height: compact ? 4 : 8),
              Text(
                'Pogon: $plantLabel',
                style: compact
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: compact ? 12 : 24),
            if (_canStartEvidence)
              FilledButton.icon(
                onPressed: _busy ? null : _startSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Pokreni evidenciju'),
              )
            else ...[
              Text(
                _isLineClearance
                    ? lineClearanceVerifierIdleTitle
                    : catalogEvidenceStartDeniedMessage,
                style: compact
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_isLineClearance) ...[
                SizedBox(height: compact ? 8 : 12),
                Text(
                  lineClearanceVerifierIdleHint,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_plantAccessOk) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(child: Text(_runtimeTitle)),
              CatalogEvidenceHelpTexts.infoIconForProfile(
                profileKey: _effectiveProfile.profileKey,
                displayName: _effectiveProfile.displayName,
                description: _effectiveProfile.description,
              ),
            ],
          ),
        ),
        body: const Center(
          child: Text('Nemate pristup ovoj stanici za dodijeljeni pogon.'),
        ),
      );
    }

    if (_usesCallableEvidenceRuntime) {
      final activeSession = _closedSession ?? _callableActiveSession;
      if (activeSession != null && activeSession.isActive) {
        _hydrateFromSession(activeSession);
      }
      return _buildEvidenceRuntimeScaffold(
        activeSession: activeSession,
        closedSessions: _callableClosedSessions,
        recordsLoading: _recordsLoading,
      );
    }

    return StreamBuilder<ProductionStationWorkSession?>(
      stream: widget.isCompanyEvidence
          ? _sessionStream.watchActiveSessionForEvidence(
              companyId: _companyId,
              evidenceConfigId: widget.evidenceConfig!.evidenceConfigId,
            )
          : _sessionStream.watchActiveSession(
              companyId: _companyId,
              stationSlot: widget.stationConfig!.effectiveStationSlot,
            ),
      builder: (context, activeSnapshot) {
        final streamActive = activeSnapshot.hasError ? null : activeSnapshot.data;
        final activeSession = _closedSession ?? streamActive;
        if (activeSession != null && activeSession.isActive) {
          _hydrateFromSession(activeSession);
        }

        return StreamBuilder<List<ProductionStationWorkSession>>(
          stream: widget.isCompanyEvidence
              ? _sessionStream.watchClosedSessionsForEvidence(
                  companyId: _companyId,
                  evidenceConfigId: widget.evidenceConfig!.evidenceConfigId,
                  limit: _recordsLimit,
                )
              : _sessionStream.watchClosedSessionsForStation(
                  companyId: _companyId,
                  stationSlot: widget.stationConfig!.effectiveStationSlot,
                  limit: _recordsLimit,
                ),
          builder: (context, closedSnapshot) {
            final closedSessions = closedSnapshot.hasError
                ? const <ProductionStationWorkSession>[]
                : (closedSnapshot.data ?? const []);
            final recordsLoading =
                closedSnapshot.connectionState == ConnectionState.waiting &&
                !closedSnapshot.hasData &&
                !closedSnapshot.hasError;

            return _buildEvidenceRuntimeScaffold(
              activeSession: activeSession,
              closedSessions: closedSessions,
              recordsLoading: recordsLoading,
            );
          },
        );
      },
    );
  }

  Widget _buildEvidenceRuntimeScaffold({
    required ProductionStationWorkSession? activeSession,
    required List<ProductionStationWorkSession> closedSessions,
    required bool recordsLoading,
  }) {
    final formEnabled =
        activeSession?.isActive == true && _closedSession == null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _runtimeTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            CatalogEvidenceHelpTexts.infoIconForProfile(
              profileKey: _effectiveProfile.profileKey,
              displayName: _effectiveProfile.displayName,
              description: _effectiveProfile.description,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Zatvori stanicu',
          onPressed: _busy ? null : _closeStation,
        ),
        actions: _buildAppBarActions(activeSession),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            CatalogEvidenceViewportSplit(
              topIsIntrinsic: activeSession == null,
              overviewRecordLimit: _recordsLimit,
              overviewRecordCount: closedSessions.length +
                  (activeSession?.isActive == true ? 1 : 0),
              overviewLoading: recordsLoading,
              topSection: activeSession == null
                  ? _buildNoSessionPrompt()
                  : _buildInputSection(
                      session: activeSession,
                      formEnabled: formEnabled,
                    ),
              tableSection: CatalogEvidenceRecordsTable(
                companyData: widget.companyData,
                profile: _effectiveProfile,
                sessions: closedSessions,
                recordLimit: _recordsLimit,
                onRecordLimitChanged: (value) {
                  setState(() => _recordsLimit = value);
                  if (_usesCallableEvidenceRuntime) {
                    unawaited(_reloadClosedEvidenceRecords());
                  }
                },
                activeSession: activeSession?.isActive == true
                    ? activeSession
                    : null,
                loading: recordsLoading,
              ),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
