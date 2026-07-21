import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_evidence_config.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_work/services/production_station_work_session_service.dart';
import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../../profile_driven_structured_runtime/models/structured_repeatable_row.dart';
import '../../profile_driven_structured_runtime/services/production_evidence_entity_search_service.dart';
import '../../profile_driven_structured_runtime/utils/structured_datetime_value.dart';
import '../../profile_driven_structured_runtime/widgets/structured_header_section.dart';
import '../../profile_driven_structured_runtime/widgets/structured_repeatable_table_section.dart';
import '../services/catalog_evidence_session_service.dart';
import '../widgets/catalog_evidence_records_table.dart';

/// M1-F3 — generički operator runtime za Admin-konfigurisane catalog evidence stanice.
class CatalogEvidenceStationScreen extends StatefulWidget {
  const CatalogEvidenceStationScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.onCloseStation,
  })  : evidenceConfig = null;

  const CatalogEvidenceStationScreen.companyEvidence({
    super.key,
    required this.companyData,
    required this.evidenceConfig,
    required this.profile,
    this.onCloseStation,
  })  : stationConfig = null;

  final Map<String, dynamic> companyData;
  final ProductionStationConfig? stationConfig;
  final ProductionEvidenceConfig? evidenceConfig;
  final ProductionStationProfileCatalogEntry profile;
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

  StructuredProfileSessionState _state = StructuredProfileSessionState();
  final Map<String, StructuredEntitySelection?> _headerEntitySelections = {};
  final Map<String, String?> _headerEnumSelections = {};
  final Map<String, DateTime?> _headerDateTimes = {};
  final Map<String, TextEditingController> _headerTextControllers = {};

  bool _busy = false;
  String? _hydratedSessionId;
  String _plantDisplayLabel = '';
  ProductionStationWorkSession? _closedSession;

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

  bool get _isStructuredLite => widget.profile.isStructuredLiteInputModel;

  List<StructuredRepeatableTableDefinition> get _tables =>
      widget.profile.repeatableTableDefinitions;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlantDisplayLabel());
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
    for (final c in _headerTextControllers.values) {
      c.clear();
    }
  }

  void _syncHeaderControllersFromState() {
    for (final field in widget.profile.structuredHeaderFields) {
      final raw = _state.fieldValues[field.key];
      if (field.isEntitySelect || field.isEntitySearchSelect) {
        if (raw == null) {
          _headerEntitySelections[field.key] = null;
          continue;
        }
        final id = raw.toString().trim();
        _headerEntitySelections[field.key] = StructuredEntitySelection(
          fieldKey: field.key,
          entityId: id,
          displayLabel: id,
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
        controller.text = raw?.toString() ?? '';
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
        profile: widget.profile,
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
    final headerError = validateStructuredHeader(
      fields: widget.profile.structuredHeaderFields,
      state: _state,
      entitySelections: _headerEntitySelections,
      enumSelections: _headerEnumSelections,
      dateTimes: _headerDateTimes,
    );
    if (headerError != null) return headerError;

    if (_isStructuredLite && forFinish) {
      final tableError = validateStructuredTables(tables: _tables, state: _state);
      if (tableError != null) return tableError;
    }
    return null;
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
          profile: widget.profile,
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
              profile: widget.profile,
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
      for (final f in widget.profile.structuredHeaderFields) {
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nalog: ${selection.displayLabel}')),
      );
      return;
    }

    if (result.type == 'product') {
      ProductionStationProfileField? headerProduct;
      for (final f in widget.profile.structuredHeaderFields) {
        if (f.key == 'productId') {
          headerProduct = f;
          break;
        }
      }
      if (headerProduct != null &&
          _headerEntitySelections['productId'] == null) {
        final productField = headerProduct;
        final selection = StructuredEntitySelection.fromSearchResult(
          fieldKey: productField.key,
          result: searchResult,
          valueField: productField.valueField,
        );
        setState(() {
          _headerEntitySelections[productField.key] = selection;
          _state.fieldValues[productField.key] = selection.entityId;
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
      row.setEntitySelection(
        StructuredEntitySelection.fromSearchResult(
          fieldKey: productCol.key,
          result: searchResult,
          valueField: productCol.valueField,
        ),
      );
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
                  widget.profile.displayName,
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
            profile: widget.profile,
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
            onFieldChanged: () => setState(() {}),
            onScanResolved: _applyScanResult,
          ),
          if (_isStructuredLite)
            ..._tables.map(
              (table) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: StructuredRepeatableTableSection(
                  tableDef: table,
                  profile: widget.profile,
                  companyId: _companyId,
                  plantKey: _plantKey,
                  rows: _state.rowsFor(table.key),
                  searchService: _searchService,
                  enabled: formEnabled,
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

    final plantLabel = _plantDisplayLabel.trim().isNotEmpty
        ? _plantDisplayLabel.trim()
        : (_plantKey.isNotEmpty ? _plantKey : '');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (plantLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Pogon: $plantLabel',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
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
                )
              : _sessionStream.watchClosedSessionsForStation(
                  companyId: _companyId,
                  stationSlot: widget.stationConfig!.effectiveStationSlot,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          flex: 5,
                          child: activeSession == null
                              ? _buildNoSessionPrompt()
                              : _buildInputSection(
                                  session: activeSession,
                                  formEnabled: formEnabled,
                                ),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          flex: 4,
                          child: CatalogEvidenceRecordsTable(
                            profile: widget.profile,
                            sessions: closedSessions,
                            activeSession: activeSession?.isActive == true
                                ? activeSession
                                : null,
                            loading: recordsLoading,
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
      },
    );
  }
}
