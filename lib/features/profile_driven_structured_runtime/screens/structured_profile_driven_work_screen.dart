import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/bom/services/bom_service.dart';
import '../../../modules/production/station_pages/models/production_evidence_config.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_pages/services/production_controlled_input_master_callable_service.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_work/services/production_station_work_session_service.dart';
import '../../catalog_evidence_runtime/utils/controlled_evidence_person_role_keys.dart';
import '../../catalog_evidence_runtime/utils/evidence_input_empty.dart';
import '../../catalog_evidence_runtime/utils/final_control_bom_product_picker.dart';
import '../../catalog_evidence_runtime/utils/operation_material_preparation_bom_picker.dart';
import '../models/structured_entity_search_result.dart';
import '../models/structured_profile_session.dart';
import '../models/structured_repeatable_row.dart';
import '../services/production_evidence_entity_search_service.dart';
import '../services/structured_profile_session_service.dart';
import '../utils/structured_datetime_value.dart';
import '../widgets/structured_header_section.dart';
import '../widgets/structured_repeatable_table_section.dart';

/// M1-D3 — structured profile-driven runtime (`rework_and_painting`, …).
class StructuredProfileDrivenWorkScreen extends StatefulWidget {
  const StructuredProfileDrivenWorkScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.onCloseStation,
  }) : evidenceConfig = null;

  const StructuredProfileDrivenWorkScreen.companyEvidence({
    super.key,
    required this.companyData,
    required this.evidenceConfig,
    required this.profile,
    this.onCloseStation,
  }) : stationConfig = null;

  final Map<String, dynamic> companyData;
  final ProductionStationConfig? stationConfig;
  final ProductionEvidenceConfig? evidenceConfig;
  final ProductionStationProfileCatalogEntry profile;
  final VoidCallback? onCloseStation;

  bool get isCompanyEvidence => evidenceConfig != null;

  @override
  State<StructuredProfileDrivenWorkScreen> createState() =>
      _StructuredProfileDrivenWorkScreenState();
}

class _StructuredProfileDrivenWorkScreenState
    extends State<StructuredProfileDrivenWorkScreen> {
  final _sessionStream = ProductionStationWorkSessionService();
  final _structuredService = StructuredProfileSessionService();
  final _searchService = ProductionEvidenceEntitySearchCallableService();
  final _masterCallables = ProductionControlledInputMasterCallableService();
  final _bomService = BomService();

  StructuredProfileSessionState _state = StructuredProfileSessionState();
  final Map<String, StructuredEntitySelection?> _headerEntitySelections = {};
  final Map<String, String?> _headerEnumSelections = {};
  final Map<String, DateTime?> _headerDateTimes = {};
  final Map<String, TextEditingController> _headerTextControllers = {};

  List<ControlledInputWorkBathOption> _workBaths = const [];
  bool _masterLoading = true;
  Object? _masterError;
  bool _busy = false;
  String? _hydratedSessionId;
  String _plantDisplayLabel = '';
  ProductionStationWorkSession? _closedSession;

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

  bool get _needsProcessWorkBaths => widget.profile.structuredHeaderFields.any(
    (f) =>
        f.isEntitySelect &&
        (f.entityCollection ?? '').trim() == 'process_work_baths',
  );

  String get _stationContextLabel => widget.isCompanyEvidence
      ? widget.evidenceConfig!.displayName.trim()
      : widget.stationConfig!.title;

  String get _plantContextLabel {
    final label = _plantDisplayLabel.trim();
    if (label.isNotEmpty) return label;
    final key = _plantKey.trim();
    return key.isNotEmpty ? key : '—';
  }

  Widget _buildCompactContextLabel(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
            TextSpan(text: value),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSessionActionsRow(
    BuildContext context,
    ProductionStationWorkSession? session,
  ) {
    final active = session?.isActive == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (session == null || !active)
                FilledButton.icon(
                  onPressed: _busy || !_plantAccessOk ? null : _startSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Pokreni evidenciju'),
                ),
              if (active) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _saveSession(session!),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Sačuvaj'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _finishSession(session!),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Završi evidenciju'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _busy ? null : _closeStation,
                icon: const Icon(Icons.close),
                label: const Text('Zatvori stanicu'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildCompactContextLabel(
                context,
                label: 'Pogon',
                value: _plantContextLabel,
              ),
              _buildCompactContextLabel(
                context,
                label: 'Stanica',
                value: _stationContextLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _runtimeTitle => widget.isCompanyEvidence
      ? widget.evidenceConfig!.displayName
      : widget.stationConfig!.title;

  int? get _stationSlot => widget.isCompanyEvidence
      ? null
      : widget.stationConfig!.effectiveStationSlot;

  List<StructuredRepeatableTableDefinition> get _tables =>
      widget.profile.repeatableTableDefinitions;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlantDisplayLabel());
    unawaited(_loadMasterData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_supportsOsWindowChrome) {
        unawaited(windowManager.setFullScreen(true));
      }
    });
  }

  Future<void> _reloadStructuredStateForActiveSession() async {
    if (widget.isCompanyEvidence) return;
    try {
      final loaded = await _structuredService.loadActiveState(
        companyId: _companyId,
        stationSlot: _stationSlot ?? 0,
      );
      if (!mounted || loaded == null) return;
      setState(() {
        _state = loaded;
        _syncHeaderControllersFromState();
      });
    } catch (_) {}
  }

  void _hydrateFromSession(ProductionStationWorkSession session) {
    if (_hydratedSessionId == session.id) return;
    _hydratedSessionId = session.id;
    _state.fieldValues = Map<String, dynamic>.from(
      session.fieldValues ?? const {},
    );
    _syncHeaderControllersFromState();
    _applyReworkHeaderFromOrderSelection();
    unawaited(_reloadStructuredStateForActiveSession());
    unawaited(_reloadReworkBomPicker());
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

  Future<void> _loadMasterData() async {
    if (!_needsProcessWorkBaths) {
      setState(() {
        _workBaths = const [];
        _masterLoading = false;
        _masterError = null;
      });
      return;
    }
    if (_plantKey.isEmpty) {
      setState(() {
        _masterLoading = false;
        _masterError = 'Stanica nema dodijeljen pogon (plantKey).';
      });
      return;
    }
    setState(() {
      _masterLoading = true;
      _masterError = null;
    });
    try {
      final baths = await _masterCallables.listProcessWorkBaths(
        companyId: _companyId,
        plantKey: _plantKey,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _workBaths = baths;
        _masterLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _masterError = e;
        _masterLoading = false;
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
        SnackBar(
          content: Text(productionStationWorkSessionErrorMessage(e)),
        ),
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
    _fcBomPicker = const OmpBomPickerState();
    _fcBomLoadedForProductId = null;
    for (final c in _headerTextControllers.values) {
      c.clear();
    }
  }

  void _syncHeaderControllersFromState() {
    for (final field in widget.profile.structuredHeaderFields) {
      final raw = _state.fieldValues[field.key];
      if (field.isEntitySelect || field.isEntitySearchSelect) {
        if (!isUsableEvidenceEntityId(raw?.toString())) {
          _headerEntitySelections[field.key] = null;
          if (raw != null) _state.fieldValues.remove(field.key);
          continue;
        }
        _headerEntitySelections[field.key] = evidenceActiveEntitySelection(
          fieldKey: field.key,
          rawValue: raw.toString(),
          fieldValues: _state.fieldValues,
          existing: _headerEntitySelections[field.key],
        );
      } else if (field.type == 'enum') {
        final value = raw?.toString();
        _headerEnumSelections[field.key] =
            isEvidenceFormPlaceholder(value) ? null : value;
      } else if (field.type == 'datetime') {
        _headerDateTimes[field.key] = StructuredDateTimeValue.parse(raw);
      } else if (field.type == 'number' || _isTextLike(field.type)) {
        final text = raw is num
            ? raw.toString()
            : sanitizeEvidenceFormInput(raw?.toString());
        _headerTextControllers.putIfAbsent(field.key, TextEditingController.new)
          ..text = text;
      }
    }
  }

  bool _isTextLike(String type) => type == 'string' || type == 'text';

  void _flushHeaderFieldsToState() {
    for (final field in widget.profile.structuredHeaderFields) {
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

  void _applyReworkHeaderFromOrderSelection() {
    final order = _headerEntitySelections['productionOrderId'];
    if (order == null) {
      _headerEntitySelections.remove('productId');
      _fcBomPicker = const OmpBomPickerState();
      _fcBomLoadedForProductId = null;
      unawaited(_reloadReworkBomPicker());
      return;
    }
    final productId = (order.raw['productId'] ?? '').toString().trim();
    final productCode = (order.raw['productCode'] ?? '').toString().trim();
    final productName = (order.raw['productName'] ??
            order.raw['displayName'] ??
            '')
        .toString()
        .trim();
    if (productId.isNotEmpty) {
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
    } else {
      _headerEntitySelections.remove('productId');
    }
    unawaited(_reloadReworkBomPicker());
  }

  Future<void> _reloadReworkBomPicker() async {
    final productId =
        (_headerEntitySelections['productId']?.entityId ?? '').trim();
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

  Future<List<StructuredEntitySearchResult>> _searchReworkProduct(
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

  Future<List<StructuredEntitySearchResult>> _searchReworkOperator(
    String query,
  ) {
    return _searchService.searchPlantOperators(
      companyId: _companyId,
      query: query,
      assignedPlantKey: _plantKey,
      roleKeys: controlledEvidenceRoleKeysForPersonField('operatorId') ??
          const [],
    );
  }

  ProductionStationProfileField _reworkRowProductFieldOverride(
    ProductionStationProfileField base, {
    required int minSearchChars,
    required String helperText,
  }) {
    return base.copyWith(
      minSearchChars: minSearchChars,
      helperText: helperText,
    );
  }

  ProductionStationProfileField _reworkOperatorFieldOverride(
    ProductionStationProfileField base,
  ) {
    return base.copyWith(
      minSearchChars: 0,
      helperText: controlledEvidencePersonHelperText('operatorId'),
    );
  }

  Widget? _buildReworkBomTableNotice(BuildContext context, String tableKey) {
    if (tableKey != 'processed_items' && tableKey != 'scrap_items') {
      return null;
    }
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
        'Proizvod se nudi iz primarne sastavnice$ver — '
        '${_fcBomPicker.items.length} stavki (+ proizvod naloga). '
        'Katalog se koristi samo ako sastavnica nije dostupna.',
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

  String? _validateBeforeSubmit() {
    _flushHeaderFieldsToState();
    final headerError = validateStructuredHeader(
      fields: widget.profile.structuredHeaderFields,
      state: _state,
      entitySelections: _headerEntitySelections,
      enumSelections: _headerEnumSelections,
      dateTimes: _headerDateTimes,
    );
    if (headerError != null) return headerError;
    return validateStructuredTables(tables: _tables, state: _state);
  }

  Future<void> _startSession() async {
    await _runBusy(() async {
      _resetFormForNewEvidence();
      setState(() {
        _closedSession = null;
        _hydratedSessionId = null;
      });
      await _structuredService.startSession(
        companyId: _companyId,
        stationSlot: _stationSlot,
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
    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }
    await _runBusy(() async {
      await _structuredService.saveStructuredState(
        companyId: _companyId,
        sessionId: session.id,
        state: _state,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci sačuvani.')),
      );
    });
  }

  Future<void> _finishSession(ProductionStationWorkSession session) async {
    final validationError = _validateBeforeSubmit();
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

    await _runBusy(() async {
      final closed = await _structuredService.finishStructuredSession(
        companyId: _companyId,
        sessionId: session.id,
        state: _state,
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
      final field = widget.profile.structuredHeaderFields
          .where((f) => f.key == 'productionOrderId')
          .firstOrNull;
      if (field != null) {
        final selection = StructuredEntitySelection.fromSearchResult(
          fieldKey: field.key,
          result: searchResult,
          valueField: field.valueField,
        );
        setState(() {
          _headerEntitySelections[field.key] = selection;
          _state.fieldValues[field.key] = selection.entityId;
          _applyReworkHeaderFromOrderSelection();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nalog: ${selection.displayLabel}')),
        );
      }
      return;
    }

    if (result.type == 'product') {
      final table = _tables
          .where((t) => t.key == 'processed_items')
          .firstOrNull;
      if (table == null) return;
      final productCol = table.operatorColumns
          .where((c) => c.key == 'productId')
          .firstOrNull;
      if (productCol == null) return;
      final row = StructuredRepeatableRow.empty();
      row.setEntitySelection(
        StructuredEntitySelection.fromSearchResult(
          fieldKey: productCol.key,
          result: searchResult,
          valueField: productCol.valueField,
        ),
      );
      final next = List<StructuredRepeatableRow>.from(
        _state.rowsFor('processed_items'),
      )..add(row);
      setState(() => _state.setRows('processed_items', next));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proizvod dodan: ${searchResult.displayLabel}')),
      );
    }
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
              stationSlot: _stationSlot ?? 0,
            ),
      builder: (context, snapshot) {
        final session = _closedSession ?? snapshot.data;
        if (session != null && session.isActive) {
          _hydrateFromSession(session);
        }

        final formEnabled = session?.isActive == true && _closedSession == null;

        return Scaffold(
          appBar: AppBar(
            title: Text(_runtimeTitle),
          ),
          body: AbsorbPointer(
            absorbing: _busy,
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      widget.profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session == null
                          ? 'Nema aktivne evidencije.'
                          : session.isActive
                          ? 'Aktivna evidencija — status: ${session.status}'
                          : 'Evidencija zatvorena.',
                    ),
                    const SizedBox(height: 16),
                    _buildSessionActionsRow(context, session),
                    const SizedBox(height: 16),
                    StructuredHeaderSection(
                      profile: widget.profile,
                      companyId: _companyId,
                      plantKey: _plantKey,
                      plantDisplayLabel: _plantDisplayLabel.trim().isEmpty
                          ? null
                          : _plantDisplayLabel.trim(),
                      state: _state,
                      workBaths: _workBaths,
                      searchService: _searchService,
                      entitySelections: _headerEntitySelections,
                      enumSelections: _headerEnumSelections,
                      dateTimes: _headerDateTimes,
                      textControllers: _headerTextControllers,
                      enabled: formEnabled,
                      masterLoading: _masterLoading,
                      masterError: _masterError,
                      onFieldChanged: () {
                        _applyReworkHeaderFromOrderSelection();
                        setState(() {});
                      },
                      onScanResolved: _applyScanResult,
                    ),
                    ..._tables.map(
                      (table) => Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: StructuredRepeatableTableSection(
                          tableDef: table,
                          profile: widget.profile,
                          companyId: _companyId,
                          plantKey: _plantKey,
                          plantDisplayLabel: _plantDisplayLabel.trim().isEmpty
                              ? null
                              : _plantDisplayLabel.trim(),
                          rows: _state.rowsFor(table.key),
                          searchService: _searchService,
                          enabled: formEnabled,
                          tableNotice:
                              _buildReworkBomTableNotice(context, table.key),
                          entitySearchOverrides: {
                            if (table.key == 'processed_items' ||
                                table.key == 'scrap_items')
                              'productId': _searchReworkProduct,
                            if (table.key == 'operator_work_logs' ||
                                table.key == 'scrap_items')
                              'operatorId': _searchReworkOperator,
                          },
                          fieldOverrides: {
                            if (table.key == 'processed_items' ||
                                table.key == 'scrap_items') ...{
                              if (_fcBomPicker.isBomBound)
                                for (final col in table.columns)
                                  if (col.key == 'productId')
                                    col.key: _reworkRowProductFieldOverride(
                                      col,
                                      minSearchChars: 0,
                                      helperText:
                                          'Odaberite proizvod naloga ili stavku '
                                          'iz primarne sastavnice (šifra / naziv).',
                                    ),
                              if (_fcBomPicker.isSoftFallback)
                                for (final col in table.columns)
                                  if (col.key == 'productId')
                                    col.key: _reworkRowProductFieldOverride(
                                      col,
                                      minSearchChars: 2,
                                      helperText:
                                          'Sastavnica nije dostupna — kontrolisani '
                                          'izbor iz šireg kataloga (privremeno).',
                                    ),
                            },
                            if (table.key == 'operator_work_logs' ||
                                table.key == 'scrap_items')
                              for (final col in table.columns)
                                if (col.key == 'operatorId')
                                  col.key: _reworkOperatorFieldOverride(col),
                          },
                          recentEntitySuggestions: {
                            if ((table.key == 'processed_items' ||
                                    table.key == 'scrap_items') &&
                                _fcBomPicker.isBomBound)
                              'productId': buildFinalControlBomProductChoices(
                                bom: _fcBomPicker,
                                orderProduct: () {
                                  final sel =
                                      _headerEntitySelections['productId'];
                                  if (sel == null ||
                                      sel.entityId.trim().isEmpty) {
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
                          },
                          recentEntitySuggestionLabels: {
                            if ((table.key == 'processed_items' ||
                                    table.key == 'scrap_items') &&
                                _fcBomPicker.isBomBound)
                              'productId': 'Proizvodi iz sastavnice',
                          },
                          onRowsChanged: (rows) {
                            setState(() => _state.setRows(table.key, rows));
                          },
                        ),
                      ),
                    ),
                  ],
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
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
