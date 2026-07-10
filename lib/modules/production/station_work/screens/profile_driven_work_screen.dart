import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_profile_catalog_entry.dart';
import '../../station_pages/models/production_station_profile_field.dart';
import '../../station_pages/services/production_controlled_input_master_callable_service.dart';
import '../models/production_station_work_session.dart';
import '../services/production_station_work_session_callable_service.dart';
import '../services/production_station_work_session_service.dart';

/// M1-B — dinamički operator obrazac iz profila (pilot: `chemical_dosing`).
class ProfileDrivenWorkScreen extends StatefulWidget {
  const ProfileDrivenWorkScreen({
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
  State<ProfileDrivenWorkScreen> createState() =>
      _ProfileDrivenWorkScreenState();
}

class _ProfileDrivenWorkScreenState extends State<ProfileDrivenWorkScreen> {
  final _sessionService = ProductionStationWorkSessionService();
  final _sessionCallables = ProductionStationWorkSessionCallableService();
  final _masterCallables = ProductionControlledInputMasterCallableService();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _entitySelections = {};
  final Map<String, String?> _enumSelections = {};
  final Map<String, DateTime?> _measuredAtByKey = {};

  List<ProductionStationProfileField> _fields = const [];
  List<ControlledInputEntityOption> _workBaths = const [];
  List<ControlledInputChemicalOption> _chemicals = const [];
  Map<String, List<String>> _mappingAllowedUnitsByChemicalId = const {};

  bool _masterLoading = true;
  Object? _masterError;
  bool _busy = false;
  String? _hydratedSessionId;
  String _plantDisplayLabel = '';
  Map<String, dynamic>? _lastControlledInputWarning;
  ProductionStationWorkSession? _closedSession;

  bool get _supportsOsWindowChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey => widget.stationConfig.assignedPlantKey.trim();

  bool get _controlledInputEnabled =>
      widget.stationConfig.controlledInputEnabled;

  String get _stationTitle => widget.stationConfig.title;

  @override
  void initState() {
    super.initState();
    _fields = widget.profile.fields
        .where((f) => f.isOperatorEditable)
        .toList(growable: false);
    _initControllers();
    unawaited(_loadPlantDisplayLabel());
    unawaited(_loadMasterData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_supportsOsWindowChrome) {
        unawaited(windowManager.setFullScreen(true));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    if (_supportsOsWindowChrome) {
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  void _initControllers() {
    for (final field in _fields) {
      if (_isTextLike(field.type)) {
        _textControllers[field.key] = TextEditingController();
      }
    }
    final defaultUnit = widget.profile.defaultUnit;
    if (defaultUnit.isNotEmpty) {
      _enumSelections['unit'] = defaultUnit;
    }
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
      final workBathId = _entitySelections['workBathId'];
      if (workBathId != null && workBathId.isNotEmpty) {
        await _reloadChemicalsForWorkBath(workBathId);
      } else if (!_controlledInputEnabled) {
        await _reloadAllChemicals();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _masterError = e;
        _masterLoading = false;
      });
    }
  }

  Future<void> _reloadAllChemicals() async {
    try {
      final chemicals = await _masterCallables.listChemicals(
        companyId: _companyId,
        plantKey: _plantKey,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _chemicals = chemicals;
        _mappingAllowedUnitsByChemicalId = const {};
      });
      _applyUnitDefaultsForSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _masterError = e);
    }
  }

  Future<void> _reloadChemicalsForWorkBath(String workBathId) async {
    try {
      final List<ControlledInputChemicalOption> chemicals;
      Map<String, List<String>> mappingUnits = const {};
      if (_controlledInputEnabled) {
        final filtered = await _masterCallables.listChemicalsAllowedForWorkBath(
          companyId: _companyId,
          workBathId: workBathId,
          plantKey: _plantKey,
          activeOnly: true,
        );
        chemicals = filtered.chemicals;
        mappingUnits = filtered.mappingAllowedUnitsByChemicalId;
      } else {
        chemicals = await _masterCallables.listChemicals(
          companyId: _companyId,
          plantKey: _plantKey,
          activeOnly: true,
        );
      }
      if (!mounted) return;
      final selectedChemical = _entitySelections['chemicalId'];
      if (selectedChemical != null &&
          chemicals.every((c) => c.id != selectedChemical)) {
        _entitySelections['chemicalId'] = null;
      }
      setState(() {
        _chemicals = chemicals;
        _mappingAllowedUnitsByChemicalId = mappingUnits;
      });
      _applyUnitDefaultsForSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _masterError = e);
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

  bool _isTextLike(String type) {
    return type == 'string' || type == 'text';
  }

  List<String> _enumOptionsFor(ProductionStationProfileField field) {
    final from = field.enumFrom ?? '';
    if (from == 'units.allowedUnits') {
      return _resolveUnitOptions();
    }
    return const [];
  }

  ControlledInputChemicalOption? _selectedChemical() {
    final chemicalId = (_entitySelections['chemicalId'] ?? '').trim();
    if (chemicalId.isEmpty) return null;
    for (final c in _chemicals) {
      if (c.id == chemicalId) return c;
    }
    return null;
  }

  List<String> _resolveUnitOptions() {
    final chemicalId = (_entitySelections['chemicalId'] ?? '').trim();
    if (chemicalId.isNotEmpty) {
      final mappingUnits = _mappingAllowedUnitsByChemicalId[chemicalId];
      if (mappingUnits != null && mappingUnits.isNotEmpty) {
        return mappingUnits;
      }
      final chemical = _selectedChemical();
      if (chemical != null && chemical.allowedUnits.isNotEmpty) {
        return chemical.allowedUnits;
      }
    }
    return widget.profile.allowedUnits;
  }

  void _applyUnitDefaultsForSelection() {
    final options = _resolveUnitOptions();
    final current = _enumSelections['unit'];
    if (current != null && !options.contains(current)) {
      _enumSelections['unit'] = null;
    }
    final selected = _enumSelections['unit'];
    if (selected != null && selected.isNotEmpty) return;

    final chemical = _selectedChemical();
    final defaultUnit = chemical?.defaultUnit ?? widget.profile.defaultUnit;
    if (defaultUnit.isNotEmpty && options.contains(defaultUnit)) {
      _enumSelections['unit'] = defaultUnit;
    } else if (options.length == 1) {
      _enumSelections['unit'] = options.first;
    }
  }

  void _syncFormFromSession(ProductionStationWorkSession session) {
    final fv = session.fieldValues ?? const <String, dynamic>{};
    for (final field in _fields) {
      final raw = fv[field.key];
      if (field.isEntitySelect) {
        _entitySelections[field.key] =
            raw == null ? null : raw.toString().trim();
      } else if (field.type == 'enum') {
        _enumSelections[field.key] =
            raw == null ? null : raw.toString().trim();
      } else if (field.type == 'number') {
        final ctrl = _textControllers[field.key];
        if (ctrl != null) {
          ctrl.text = raw == null ? '' : raw.toString();
        }
      } else if (field.type == 'datetime') {
        _measuredAtByKey[field.key] = _parseDateTime(raw);
      } else if (_isTextLike(field.type)) {
        final ctrl = _textControllers[field.key];
        if (ctrl != null) {
          ctrl.text = raw == null ? '' : raw.toString();
        }
      }
    }
    _lastControlledInputWarning = session.controlledInputWarning;
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  String? _readOnlyFieldValue(
    ProductionStationProfileField field,
    ProductionStationWorkSession session,
  ) {
    if (field.isSessionScope) {
      switch (field.key) {
        case 'operatorId':
          return session.operatorId.isEmpty ? null : session.operatorId;
        case 'operatorEmail':
          return session.operatorEmail;
        case 'operatorDisplayName':
          return session.operatorDisplayName;
        case 'createdAt':
          return session.createdAt == null
              ? null
              : BaFormattedDate.formatDateTime(session.createdAt!);
        case 'updatedAt':
          return session.updatedAt == null
              ? null
              : BaFormattedDate.formatDateTime(session.updatedAt!);
        default:
          return null;
      }
    }
    final fv = session.fieldValues ?? const <String, dynamic>{};
    final raw = fv[field.key];
    if (raw == null) return null;
    if (field.type == 'datetime') {
      final dt = _parseDateTime(raw);
      return dt == null ? raw.toString() : BaFormattedDate.formatDateTime(dt);
    }
    return raw.toString();
  }

  Map<String, dynamic> _collectFieldValues() {
    final out = <String, dynamic>{};
    for (final field in _fields) {
      if (field.isEntitySelect) {
        final v = _entitySelections[field.key];
        if (v != null && v.isNotEmpty) out[field.key] = v;
      } else if (field.type == 'enum') {
        final v = _enumSelections[field.key];
        if (v != null && v.isNotEmpty) out[field.key] = v;
      } else if (field.type == 'number') {
        final text = _textControllers[field.key]?.text.trim() ?? '';
        if (text.isEmpty) continue;
        final n = double.tryParse(text.replaceAll(',', '.'));
        if (n != null) out[field.key] = n;
      } else if (field.type == 'datetime') {
        final dt = _measuredAtByKey[field.key];
        if (dt != null) out[field.key] = dt.toUtc().toIso8601String();
      } else if (_isTextLike(field.type)) {
        final text = _textControllers[field.key]?.text.trim() ?? '';
        if (text.isNotEmpty) out[field.key] = text;
      }
    }
    return out;
  }

  Future<void> _startSession() async {
    await _runBusy(() async {
      setState(() => _closedSession = null);
      await _sessionCallables.startProductionStationWorkSession(
        companyId: _companyId,
        stationSlot: widget.stationConfig.stationSlot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencija pokrenuta.')),
      );
    });
  }

  Future<void> _saveFieldValues(ProductionStationWorkSession session) async {
    final values = _collectFieldValues();
    await _runBusy(() async {
      await _sessionCallables.setProfileFieldValues(
        companyId: _companyId,
        sessionId: session.id,
        fieldValues: values,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci sačuvani.')),
      );
    });
  }

  Future<void> _finishSession(ProductionStationWorkSession session) async {
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

    final values = _collectFieldValues();
    await _runBusy(() async {
      await _sessionCallables.setProfileFieldValues(
        companyId: _companyId,
        sessionId: session.id,
        fieldValues: values,
      );
      final closed = await _sessionCallables.finishProductionStationWorkSession(
        companyId: _companyId,
        sessionId: session.id,
        fieldValues: values,
      );
      if (!mounted) return;
      setState(() {
        _closedSession = closed;
        _hydratedSessionId = closed.id;
      });
      _syncFormFromSession(closed);
      _lastControlledInputWarning = closed.controlledInputWarning;
      if (closed.controlledInputWarning != null) {
        final msg =
            (closed.controlledInputWarning!['message'] ?? '').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isEmpty
                  ? 'Evidencija završena s upozorenjem kontrolisanog unosa.'
                  : msg,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidencija završena.')),
        );
      }
    });
  }

  Widget _buildEntitySelectField(
    ProductionStationProfileField field, {
    required bool enabled,
  }) {
    final selected = _entitySelections[field.key];
    final options = field.key == 'workBathId'
        ? _workBaths
        : field.key == 'chemicalId'
        ? _chemicals
        : const <ControlledInputEntityOption>[];

    final dependsOnBath = field.filterDependsOn == 'workBathId';
    final bathSelected =
        (_entitySelections['workBathId'] ?? '').trim().isNotEmpty;
    final fieldEnabled = enabled &&
        (!dependsOnBath || bathSelected || field.key == 'workBathId');

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        border: const OutlineInputBorder(),
        helperText: field.helperText ??
            (dependsOnBath && !bathSelected && field.key == 'chemicalId'
                ? 'Prvo odaberite radnu kadu.'
                : null),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: options.any((o) => o.id == selected) ? selected : null,
          hint: Text(field.key == 'chemicalId' && _controlledInputEnabled
              ? 'Odaberite hemikaliju (filtrirano)'
              : 'Odaberite…'),
          items: options
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.id,
                  child: Text(o.dropdownLabel),
                ),
              )
              .toList(growable: false),
          onChanged: fieldEnabled && !_busy
              ? (value) async {
                  setState(() => _entitySelections[field.key] = value);
                  if (field.key == 'workBathId') {
                    _entitySelections['chemicalId'] = null;
                    if (value != null && value.isNotEmpty) {
                      await _reloadChemicalsForWorkBath(value);
                    } else if (!_controlledInputEnabled) {
                      await _reloadAllChemicals();
                    } else {
                      setState(() {
                        _chemicals = const [];
                        _mappingAllowedUnitsByChemicalId = const {};
                      });
                      _applyUnitDefaultsForSelection();
                    }
                  } else if (field.key == 'chemicalId') {
                    _applyUnitDefaultsForSelection();
                    setState(() {});
                  }
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildOperatorField(
    ProductionStationProfileField field, {
    required bool enabled,
  }) {
    if (field.isEntitySelect) {
      return _buildEntitySelectField(field, enabled: enabled);
    }
    if (field.type == 'enum') {
      final options = _enumOptionsFor(field);
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _enumSelections[field.key],
            hint: const Text('Odaberite…'),
            items: options
                .map(
                  (u) => DropdownMenuItem<String>(
                    value: u,
                    child: Text(u),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled && !_busy
                ? (v) => setState(() => _enumSelections[field.key] = v)
                : null,
          ),
        ),
      );
    }
    if (field.type == 'datetime') {
      final dt = _measuredAtByKey[field.key];
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(field.required ? '${field.label} *' : field.label),
        subtitle: Text(
          dt == null
              ? 'Nije uneseno (backend popunjava pri završetku)'
              : BaFormattedDate.formatDateTime(dt),
        ),
        trailing: enabled && !_busy
            ? IconButton(
                icon: const Icon(Icons.event),
                onPressed: () async {
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: dt ?? now,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (pickedDate == null || !mounted) return;
                  if (!context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(dt ?? now),
                  );
                  if (pickedTime == null || !mounted) return;
                  setState(() {
                    _measuredAtByKey[field.key] = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  });
                },
              )
            : null,
      );
    }
    if (field.type == 'number' || _isTextLike(field.type)) {
      final ctrl = _textControllers[field.key];
      return TextField(
        controller: ctrl,
        enabled: enabled && !_busy,
        keyboardType: field.type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: field.type == 'text' ? 3 : 1,
        maxLength: field.maxLength,
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          border: const OutlineInputBorder(),
          helperText: field.helperText,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReadOnlyAuditSection(ProductionStationWorkSession session) {
    final readOnlyFields = widget.profile.fields
        .where((f) => !f.isOperatorEditable && f.key != 'operatorId')
        .toList(growable: false);
    if (readOnlyFields.isEmpty &&
        session.controlledInputWarning == null &&
        _lastControlledInputWarning == null) {
      return const SizedBox.shrink();
    }

    final warning = session.controlledInputWarning ?? _lastControlledInputWarning;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit i snapshot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (warning != null) ...[
              const SizedBox(height: 12),
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (warning['message'] ?? 'Upozorenje kontrolisanog unosa.')
                              .toString(),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...readOnlyFields.map((field) {
              final value = _readOnlyFieldValue(field, session);
              if (value == null || value.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        field.label,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(value),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSessionBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _plantDisplayLabel.isEmpty ? _plantKey : _plantDisplayLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || _masterLoading ? null : _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Pokreni evidenciju'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionBody(ProductionStationWorkSession session) {
    final formEnabled = session.isActive;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_masterError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Master podaci: $_masterError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_masterLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (_controlledInputEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Kontrolisan unos: '
                '${ProductionStationConfig.controlledInputModeLabel(widget.stationConfig.controlledInputMode)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ..._fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOperatorField(field, enabled: formEnabled),
            ),
          ),
          _buildReadOnlyAuditSection(session),
          const SizedBox(height: 24),
          if (session.isActive) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _saveFieldValues(session),
                    child: const Text('Sačuvaj'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _finishSession(session),
                    child: const Text('Završi evidenciju'),
                  ),
                ),
              ],
            ),
          ] else ...[
            FilledButton(
              onPressed: _busy ? null : _startSession,
              child: const Text('Nova evidencija'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stationTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Zatvori stanicu',
          onPressed: _busy ? null : _closeStation,
        ),
      ),
      body: StreamBuilder<ProductionStationWorkSession?>(
        stream: _sessionService.watchActiveSession(
          companyId: _companyId,
          stationSlot: widget.stationConfig.stationSlot,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = snap.data ?? _closedSession;
          if (session != null && session.id != _hydratedSessionId) {
            _hydratedSessionId = session.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _syncFormFromSession(session);
              final workBathId = _entitySelections['workBathId'];
              if (workBathId != null && workBathId.isNotEmpty) {
                unawaited(_reloadChemicalsForWorkBath(workBathId));
              }
              setState(() {});
            });
          }

          if (session == null) {
            return _buildNoSessionBody();
          }
          return _buildActiveSessionBody(session);
        },
      ),
    );
  }
}
