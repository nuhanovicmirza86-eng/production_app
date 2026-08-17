import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../../profile_driven_structured_runtime/models/structured_repeatable_row.dart';
import '../../profile_driven_structured_runtime/services/production_evidence_entity_search_service.dart';
import '../../profile_driven_structured_runtime/utils/structured_datetime_value.dart';
import '../../profile_driven_structured_runtime/widgets/structured_datetime_field.dart';
import '../../profile_driven_structured_runtime/widgets/structured_header_section.dart';
import '../../profile_driven_structured_runtime/widgets/structured_repeatable_table_section.dart';
import '../services/catalog_evidence_session_service.dart';
import '../widgets/catalog_evidence_records_table.dart';
import '../widgets/catalog_evidence_viewport_split.dart';

/// M1-F3 — generički operator runtime za Admin-konfigurisane catalog evidence stanice.
class CatalogEvidenceStationScreen extends StatefulWidget {
  const CatalogEvidenceStationScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.profileCatalogVersion = 0,
    this.onCloseStation,
  })  : evidenceConfig = null;

  const CatalogEvidenceStationScreen.companyEvidence({
    super.key,
    required this.companyData,
    required this.evidenceConfig,
    required this.profile,
    this.profileCatalogVersion = 0,
    this.onCloseStation,
  })  : stationConfig = null;

  final Map<String, dynamic> companyData;
  final ProductionStationConfig? stationConfig;
  final ProductionEvidenceConfig? evidenceConfig;
  final ProductionStationProfileCatalogEntry profile;
  /// Hub/live katalog verzija — za M1-I3-H1 refresh forme (npr. Mašina).
  final int profileCatalogVersion;
  final VoidCallback? onCloseStation;

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

  StructuredProfileSessionState _state = StructuredProfileSessionState();
  final Map<String, StructuredEntitySelection?> _headerEntitySelections = {};
  final Map<String, String?> _headerEnumSelections = {};
  final Map<String, DateTime?> _headerDateTimes = {};
  final Map<String, TextEditingController> _headerTextControllers = {};

  bool _busy = false;
  String? _hydratedSessionId;
  String _plantDisplayLabel = '';
  ProductionStationWorkSession? _closedSession;
  int _recordsLimit = catalogEvidenceDefaultRecordLimit;
  ProductionStationProfileCatalogEntry? _runtimeProfile;
  int _profileCatalogVersion = 0;
  String? _lastFirstPieceOrderIdApplied;

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

  ProductionStationProfileCatalogEntry get _effectiveProfile =>
      _runtimeProfile ?? widget.profile;

  bool get _isStructuredLite => _effectiveProfile.isStructuredLiteInputModel;

  List<StructuredRepeatableTableDefinition> get _tables =>
      _effectiveProfile.repeatableTableDefinitions;

  bool get _isPackagingControl =>
      _effectiveProfile.profileKey.trim() == 'packaging_control';

  bool get _isFirstPieceApproval =>
      _effectiveProfile.profileKey.trim() == 'first_piece_approval';

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
        if (changed) {
          _syncHeaderControllersFromState();
          _ensureFirstPieceDefaults();
          _ensureFirstPieceInspectorFromSession();
          _ensurePackagingControllerFromSession();
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
    unawaited(_refreshLiveProfileCatalog());
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

  Future<void> _loadPlantDisplayLabel() async {
    if (_plantKey.isEmpty) return;
    final label = await CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    if (!mounted) return;
    setState(() => _plantDisplayLabel = label.trim());
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
    _lastFirstPieceOrderIdApplied = null;
    for (final c in _headerTextControllers.values) {
      c.clear();
    }
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _ensureFirstPieceDefaults();
    _syncHeaderControllersFromState();
  }

  /// M1-I3-D — odobrenje prvog komada: default 1 komad.
  void _ensureFirstPieceDefaults() {
    if (!_isFirstPieceApproval) return;
    if (_state.fieldValues['qtySubmitted'] != null) return;
    _state.fieldValues['qtySubmitted'] = 1;
  }

  /// Procesni kontrolor = prijavljeni korisnik (M1-I2-F3 / F6).
  /// Samo [controllerEmployeeId] ide u payload — snapshot ime popunjava backend.
  void _ensurePackagingControllerFromSession() {
    if (!_isPackagingControl) return;
    final name = _processControllerDisplayName.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    _state.fieldValues.remove('controllerNameSnapshot');
    if (uid.isEmpty) return;
    _state.fieldValues['controllerEmployeeId'] = uid;
    _headerEntitySelections['controllerEmployeeId'] = StructuredEntitySelection(
      fieldKey: 'controllerEmployeeId',
      entityId: uid,
      displayLabel: name.isNotEmpty ? name : 'Procesni kontrolor',
    );
  }

  /// M1-I3-E — kontrolor kvaliteta = prijavljeni korisnik (ne ručni search).
  /// Samo [inspectorEmployeeId] u payloadu — snapshot ime popunjava backend.
  void _ensureFirstPieceInspectorFromSession() {
    if (!_isFirstPieceApproval) return;
    final name = _processControllerDisplayName.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    _state.fieldValues.remove('inspectorNameSnapshot');
    if (uid.isEmpty) return;
    _state.fieldValues['inspectorEmployeeId'] = uid;
    _headerEntitySelections['inspectorEmployeeId'] = StructuredEntitySelection(
      fieldKey: 'inspectorEmployeeId',
      entityId: uid,
      displayLabel: name.isNotEmpty ? name : 'Kontrolor kvaliteta',
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
        final labelParts = <String>[
          if (productCode.isNotEmpty) productCode,
          if (productName.isNotEmpty) productName,
        ];
        _headerEntitySelections['productId'] = StructuredEntitySelection(
          fieldKey: 'productId',
          entityId: productId,
          displayLabel:
              labelParts.isEmpty ? productId : labelParts.join(' — '),
          raw: {
            'id': productId,
            'productCode': productCode,
            'productName': productName,
            'displayName': productName,
          },
        );
      }
    }

    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _stripNonOperatorEditableFieldValues();
  }

  /// M1-I3-H1 — sken/odabir naloga puni poznata polja (proizvod, mašina, lot).
  /// [forceFromOrder]: true pri skeniranju; inače samo kad se promijeni nalog.
  void _applyFirstPieceHeaderFromOrderSelection({
    bool forceFromOrder = false,
  }) {
    if (!_isFirstPieceApproval) return;

    _state.fieldValues.remove('productCode');
    _state.fieldValues.remove('productNameSnapshot');
    _state.fieldValues.remove('productionOrderCode');
    _state.fieldValues.remove('machineNameSnapshot');
    _state.fieldValues.remove('machineCodeSnapshot');

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
      final labelParts = <String>[
        if (productCode.isNotEmpty) productCode,
        if (productName.isNotEmpty) productName,
      ];
      _state.fieldValues['productId'] = productId;
      _headerEntitySelections['productId'] = StructuredEntitySelection(
        fieldKey: 'productId',
        entityId: productId,
        displayLabel:
            labelParts.isEmpty ? productId : labelParts.join(' — '),
        raw: {
          'id': productId,
          'productCode': productCode,
          'productName': productName,
          'displayName': productName,
        },
      );
    }

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
      // Novi nalog bez mašine — traži ručni kontrolisani odabir.
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

    _lastFirstPieceOrderIdApplied = orderId;
    _ensureFirstPieceInspectorFromSession();
    _ensureFirstPieceDefaults();
    _stripNonOperatorEditableFieldValues();
  }

  /// Payload smije sadržavati samo operator-editable polja profila (M1-I2-F6).
  void _stripNonOperatorEditableFieldValues() {
    final allowed = <String>{
      for (final f in _effectiveProfile.fields)
        if (f.isOperatorEditable) f.key,
    };
    _state.fieldValues.removeWhere((key, _) => !allowed.contains(key));
  }

  void _syncHeaderControllersFromState() {
    for (final field in _effectiveProfile.structuredHeaderFields) {
      final raw = _state.fieldValues[field.key];
      if (field.isEntitySelect || field.isEntitySearchSelect) {
        if (raw == null) {
          _headerEntitySelections[field.key] = null;
          continue;
        }
        final id = raw.toString().trim();
        var label = id;
        if (field.key == 'productId') {
          final code = (_state.fieldValues['productCode'] ?? '').toString().trim();
          final name =
              (_state.fieldValues['productNameSnapshot'] ?? '').toString().trim();
          if (code.isNotEmpty && name.isNotEmpty) {
            label = '$code — $name';
          } else if (code.isNotEmpty) {
            label = code;
          } else if (name.isNotEmpty) {
            label = name;
          }
        } else if (field.key == 'productionOrderId') {
          final code =
              (_state.fieldValues['productionOrderCode'] ?? '').toString().trim();
          if (code.isNotEmpty) label = code;
        } else if (field.key == 'controllerEmployeeId') {
          final name = (_state.fieldValues['controllerNameSnapshot'] ?? '')
              .toString()
              .trim();
          if (name.isNotEmpty) label = name;
        } else if (field.key == 'inspectorEmployeeId') {
          final name = (_state.fieldValues['inspectorNameSnapshot'] ?? '')
              .toString()
              .trim();
          if (name.isNotEmpty) {
            label = name;
          } else {
            final sessionName = _processControllerDisplayName.trim();
            if (sessionName.isNotEmpty) label = sessionName;
          }
        } else if (field.key == 'machineId') {
          final code =
              (_state.fieldValues['machineCodeSnapshot'] ?? '').toString().trim();
          final name =
              (_state.fieldValues['machineNameSnapshot'] ?? '').toString().trim();
          if (code.isNotEmpty && name.isNotEmpty) {
            label = '$code — $name';
          } else if (name.isNotEmpty) {
            label = name;
          } else if (code.isNotEmpty) {
            label = code;
          }
        }
        _headerEntitySelections[field.key] = StructuredEntitySelection(
          fieldKey: field.key,
          entityId: id,
          displayLabel: label,
        );
      } else if (field.type == 'enum') {
        _headerEnumSelections[field.key] = raw?.toString();
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
                : raw.toString());
        if (controller.text != text) {
          controller.text = text;
        }
      }
    }
  }

  bool _isTextLike(String type) => type == 'string' || type == 'text';

  void _flushHeaderFieldsToState() {
    for (final field in _effectiveProfile.structuredHeaderFields) {
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
  }

  String get _runtimeTitle => widget.isCompanyEvidence
      ? widget.evidenceConfig!.displayName
      : widget.stationConfig!.title;

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
      });
    } catch (_) {}
  }

  void _hydrateFromSession(ProductionStationWorkSession session) {
    if (_hydratedSessionId == session.id) return;
    _hydratedSessionId = session.id;
    _state.fieldValues = Map<String, dynamic>.from(
      session.fieldValues ?? const {},
    );
    _ensureFirstPieceDefaults();
    _ensureFirstPieceInspectorFromSession();
    _syncHeaderControllersFromState();
    _ensurePackagingControllerFromSession();
    if (_isStructuredLite) {
      unawaited(_reloadStructuredStateForActiveSession());
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
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();
    _stripNonOperatorEditableFieldValues();
    final headerError = validateStructuredHeader(
      fields: _effectiveProfile.structuredHeaderFields,
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

    if (_isStructuredLite && forFinish) {
      final tableError = validateStructuredTables(tables: _tables, state: _state);
      if (tableError != null) return tableError;
    }
    return null;
  }

  /// M1-I2-F7 — kraj kontrole, vremenski redoslijed, operater pakovanja.
  String? _validatePackagingFinish() {
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
      return 'Odaberite operatera pakovanja prije završavanja evidencije.';
    }
    return null;
  }

  /// M1-I3-F — početak/kraj kontrole obavezni (isto poslovno pravilo kao packaging).
  String? _validateFirstPieceFinish() {
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

  /// Ako kraj kontrole nije unesen — ponudi „Postavi sada”.
  /// `false` = korisnik odustao; `true` = vrijeme postoji ili je postavljeno.
  Future<bool> _offerSetFinishTimeNowIfMissing({
    required String fieldKey,
  }) async {
    final finished = _headerDateTimes[fieldKey] ??
        StructuredDateTimeValue.parse(_state.fieldValues[fieldKey]);
    if (finished != null) return true;

    final setNow = await showDialog<bool>(
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
    await _runBusy(() async {
      _resetFormForNewEvidence();
      setState(() {
        _closedSession = null;
        _hydratedSessionId = null;
      });
      await _catalogService.startSession(
        companyId: _companyId,
        stationSlot: widget.isCompanyEvidence
            ? null
            : widget.stationConfig!.effectiveStationSlot,
        evidenceConfigId: widget.isCompanyEvidence
            ? widget.evidenceConfig!.evidenceConfigId
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencija pokrenuta.')),
      );
    });
  }

  Future<void> _saveSession(ProductionStationWorkSession session) async {
    final validationError = _validateBeforeSubmit(forFinish: false);
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }
    await _runBusy(() async {
      if (_isStructuredLite) {
        await _catalogService.saveState(
          companyId: _companyId,
          sessionId: session.id,
          profile: _effectiveProfile,
          state: _state,
        );
      } else {
        await _catalogService.saveFlatState(
          companyId: _companyId,
          sessionId: session.id,
          fieldValues: Map<String, dynamic>.from(_state.fieldValues),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci sačuvani.')),
      );
    });
  }

  Future<void> _finishSession(ProductionStationWorkSession session) async {
    _flushHeaderFieldsToState();
    _ensurePackagingControllerFromSession();
    _ensureFirstPieceInspectorFromSession();

    if (_isPackagingControl) {
      final offered = await _offerSetFinishTimeNowIfMissing(
        fieldKey: 'checkFinishedAt',
      );
      if (!offered) return;
    }
    if (_isFirstPieceApproval) {
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

    await _runBusy(() async {
      final closed = _isStructuredLite
          ? await _catalogService.finishState(
              companyId: _companyId,
              sessionId: session.id,
              profile: _effectiveProfile,
              state: _state,
            )
          : await _catalogService.finishFlatState(
              companyId: _companyId,
              sessionId: session.id,
              fieldValues: Map<String, dynamic>.from(_state.fieldValues),
            );
      if (!mounted) return;
      setState(() {
        _closedSession = closed;
        _hydratedSessionId = closed.id;
      });
      _syncHeaderControllersFromState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencija završena.')),
      );
    });
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
          tooltip: 'Završi evidenciju',
          icon: const Icon(Icons.check_circle_outline),
          onPressed: _busy ? null : () => _finishSession(session!),
        ),
      ],
    ];
  }

  Widget _buildInputSection({
    required ProductionStationWorkSession? session,
    required bool formEnabled,
  }) {
    final plantLabel = _plantDisplayLabel.trim().isNotEmpty
        ? _plantDisplayLabel.trim()
        : (_plantKey.isNotEmpty ? _plantKey : '—');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _effectiveProfile.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
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
          StructuredHeaderSection(
            profile: _effectiveProfile,
            companyId: _companyId,
            plantKey: _plantKey,
            state: _state,
            workBaths: const [],
            searchService: _searchService,
            entitySelections: _headerEntitySelections,
            enumSelections: _headerEnumSelections,
            dateTimes: _headerDateTimes,
            textControllers: _headerTextControllers,
            enabled: formEnabled,
            excludedFieldKeys: {
              if (_isPackagingControl) 'controllerEmployeeId',
              if (_isFirstPieceApproval) 'inspectorEmployeeId',
            },
            onFieldChanged: () {
              _applyPackagingHeaderSnapshotsFromSelections();
              if (_isFirstPieceApproval) {
                // Puni iz naloga samo kad se nalog promijeni (ne briše ručni odabir mašine).
                _applyFirstPieceHeaderFromOrderSelection();
                _ensureFirstPieceInspectorFromSession();
              }
              setState(() {});
            },
            onScanResolved: _applyScanResult,
          ),
          if (_isPackagingControl) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Procesni kontrolor',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _processControllerDisplayName.trim().isEmpty
                    ? '—'
                    : _processControllerDisplayName.trim(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (_isFirstPieceApproval) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Kontrolor kvaliteta',
                border: OutlineInputBorder(),
                helperText: 'Automatski iz prijave — ne bira se ručno.',
              ),
              child: Text(
                _processControllerDisplayName.trim().isEmpty
                    ? '—'
                    : _processControllerDisplayName.trim(),
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
                  rows: _state.rowsFor(table.key),
                  searchService: _searchService,
                  enabled: formEnabled,
                  headerProductSelection: _isPackagingControl
                      ? _headerEntitySelections['productId']
                      : null,
                  onRowsChanged: (rows) {
                    setState(() => _state.setRows(table.key, rows));
                  },
                ),
              ),
            ),
          if (!formEnabled && session != null && !session.isActive) ...[
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
    final plantLabel = _plantDisplayLabel.trim().isNotEmpty
        ? _plantDisplayLabel.trim()
        : (_plantKey.isNotEmpty ? _plantKey : '');
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
            FilledButton.icon(
              onPressed: _busy ? null : _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Pokreni evidenciju'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_plantAccessOk) {
      return Scaffold(
        appBar: AppBar(title: Text(_runtimeTitle)),
        body: const Center(
          child: Text('Nemate pristup ovoj stanici za dodijeljeni pogon.'),
        ),
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
        final activeSession = _closedSession ?? activeSnapshot.data;
        if (activeSession != null && activeSession.isActive) {
          _hydrateFromSession(activeSession);
        }

        final formEnabled =
            activeSession?.isActive == true && _closedSession == null;

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
            final closedSessions = closedSnapshot.data ?? const [];
            final recordsLoading =
                closedSnapshot.connectionState == ConnectionState.waiting &&
                !closedSnapshot.hasData;

            return Scaffold(
              appBar: AppBar(
                title: Text(_runtimeTitle),
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
          },
        );
      },
    );
  }
}
