import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/services/production_controlled_input_master_callable_service.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_work/services/production_station_work_session_service.dart';
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
  });

  final Map<String, dynamic> companyData;
  final ProductionStationConfig stationConfig;
  final ProductionStationProfileCatalogEntry profile;
  final VoidCallback? onCloseStation;

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

  bool get _supportsOsWindowChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey => widget.stationConfig.assignedPlantKey.trim();

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

  String get _stationContextLabel => widget.stationConfig.title;

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
    try {
      final loaded = await _structuredService.loadActiveState(
        companyId: _companyId,
        stationSlot: widget.stationConfig.effectiveStationSlot,
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
    unawaited(_reloadStructuredStateForActiveSession());
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
        _headerTextControllers.putIfAbsent(field.key, TextEditingController.new)
          ..text = raw?.toString() ?? '';
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
        stationSlot: widget.stationConfig.effectiveStationSlot,
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
        appBar: AppBar(title: Text(widget.stationConfig.title)),
        body: const Center(
          child: Text('Nemate pristup ovoj stanici za dodijeljeni pogon.'),
        ),
      );
    }

    return StreamBuilder<ProductionStationWorkSession?>(
      stream: _sessionStream.watchActiveSession(
        companyId: _companyId,
        stationSlot: widget.stationConfig.effectiveStationSlot,
      ),
      builder: (context, snapshot) {
        final session = _closedSession ?? snapshot.data;
        if (session != null && session.isActive) {
          _hydrateFromSession(session);
        }

        final formEnabled = session?.isActive == true && _closedSession == null;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.stationConfig.title),
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
                      onFieldChanged: () => setState(() {}),
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
                          rows: _state.rowsFor(table.key),
                          searchService: _searchService,
                          enabled: formEnabled,
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
