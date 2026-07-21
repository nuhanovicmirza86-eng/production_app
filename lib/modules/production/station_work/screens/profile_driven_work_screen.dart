import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../../station_pages/models/production_evidence_config.dart';
import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_profile_catalog_entry.dart';
import '../../station_pages/models/production_station_profile_field.dart';
import '../../station_pages/services/production_controlled_input_master_callable_service.dart';
import '../models/production_station_work_session.dart';
import '../services/production_station_work_session_callable_service.dart';
import '../services/production_station_work_session_service.dart';

/// M1-B / M1-C — dinamički operator obrazac iz profila (`chemical_dosing`, `wastewater_treatment`, …).
class ProfileDrivenWorkScreen extends StatefulWidget {
  const ProfileDrivenWorkScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.onCloseStation,
  })  : evidenceConfig = null;

  const ProfileDrivenWorkScreen.companyEvidence({
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
  State<ProfileDrivenWorkScreen> createState() =>
      _ProfileDrivenWorkScreenState();
}

class _ProfileDrivenWorkScreenState extends State<ProfileDrivenWorkScreen> {
  final _sessionService = ProductionStationWorkSessionService();
  final _sessionCallables = ProductionStationWorkSessionCallableService();
  final _masterCallables = ProductionControlledInputMasterCallableService();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, num?> _numberFieldValues = {};
  final Map<String, String?> _entitySelections = {};
  final Map<String, String?> _enumSelections = {};
  final Map<String, DateTime?> _measuredAtByKey = {};

  List<ProductionStationProfileField> _fields = const [];
  List<ControlledInputWorkBathOption> _workBaths = const [];
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

  bool get _isChemicalDosingProfile =>
      widget.profile.profileKey.trim() == 'chemical_dosing';

  bool get _controlledInputEnabled => widget.isCompanyEvidence
      ? widget.evidenceConfig!.controlledInputEnabled
      : widget.stationConfig!.controlledInputEnabled;

  String get _controlledInputModeLabel =>
      ProductionStationConfig.controlledInputModeLabel(
        widget.isCompanyEvidence
            ? widget.evidenceConfig!.controlledInputMode
            : widget.stationConfig!.controlledInputMode,
      );

  bool get _loadsChemicalMasterData => _isChemicalDosingProfile;

  String get _stationTitle => widget.isCompanyEvidence
      ? widget.evidenceConfig!.displayName
      : widget.stationConfig!.title;

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
    _ensureFieldControllers();
  }

  /// Nova evidencija — sva operator-editable polja prazna (ne nastavak sesije).
  void _resetOperatorFormForNewEvidence() {
    for (final field in _fields) {
      if (field.isEntitySelect) {
        _entitySelections[field.key] = null;
      } else if (field.type == 'enum') {
        _enumSelections[field.key] = null;
      } else if (field.type == 'number' || _isTextLike(field.type)) {
        _textControllerFor(field.key).clear();
      } else if (field.type == 'datetime') {
        _measuredAtByKey[field.key] = null;
      }
    }
    _numberFieldValues.clear();
    _lastControlledInputWarning = null;
    if (_controlledInputEnabled) {
      _chemicals = const [];
      _mappingAllowedUnitsByChemicalId = const {};
    }
  }

  TextEditingController _textControllerFor(String key) {
    return _textControllers.putIfAbsent(key, TextEditingController.new);
  }

  void _ensureFieldControllers() {
    for (final field in _fields) {
      if (field.type == 'number' || _isTextLike(field.type)) {
        _textControllerFor(field.key);
      }
    }
  }

  num? _parseNumberFieldText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  void _rememberNumberFieldValue(String key, String text) {
    _numberFieldValues[key] = _parseNumberFieldText(text);
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
      if (!_loadsChemicalMasterData) {
        _applyUnitDefaultsForSelection();
        if (mounted) setState(() {});
        return;
      }
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
      if (mounted) setState(() {});
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
      if (mounted) setState(() {});
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
    if (field.enumValues.isNotEmpty) {
      return field.enumValues;
    }
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

  ControlledInputWorkBathOption? _selectedProcessWorkBath() {
    final workBathId = (_entitySelections['workBathId'] ?? '').trim();
    if (workBathId.isNotEmpty) {
      for (final b in _workBaths) {
        if (b.id == workBathId) return b;
      }
    }
    final treatmentPointId = (_entitySelections['treatmentPointId'] ?? '').trim();
    if (treatmentPointId.isEmpty) return null;
    for (final b in _workBaths) {
      if (b.id == treatmentPointId) return b;
    }
    return null;
  }

  ControlledInputWorkBathOption? _selectedWorkBath() => _selectedProcessWorkBath();

  String _formatConcentrationPreview(num? value) {
    if (value == null) return 'Nije definisano';
    return '$value% prema katalogu';
  }

  String _previewProcessAreaLabel() {
    final area = (_selectedWorkBath()?.processArea ?? '').trim();
    return area.isEmpty ? 'Nije definisano' : area;
  }

  String _previewConcentrationLabel() {
    return _formatConcentrationPreview(_selectedChemical()?.concentrationDefault);
  }

  Widget? _infoIcon(String? tooltip) {
    final text = (tooltip ?? '').trim();
    if (text.isEmpty) return null;
    return Tooltip(
      message: text,
      child: Icon(
        Icons.info_outline,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ProductionStationProfileField field, {
    String? helperText,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: field.required ? '${field.label} *' : field.label,
      border: const OutlineInputBorder(),
      helperText: helperText ?? field.helperText,
      suffixIcon: suffix ?? _infoIcon(field.helperText),
    );
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
        final ctrl = _textControllerFor(field.key);
        if (raw == null) {
          ctrl.clear();
          _numberFieldValues.remove(field.key);
        } else {
          final text = raw.toString();
          ctrl.text = text;
          _rememberNumberFieldValue(field.key, text);
        }
      } else if (field.type == 'datetime') {
        _measuredAtByKey[field.key] = _parseDateTime(raw);
      } else if (_isTextLike(field.type)) {
        final ctrl = _textControllerFor(field.key);
        ctrl.text = raw == null ? '' : raw.toString();
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
    FocusManager.instance.primaryFocus?.unfocus();
    _ensureFieldControllers();

    final out = <String, dynamic>{};
    for (final field in _fields) {
      if (field.isEntitySelect) {
        final v = _entitySelections[field.key];
        if (v != null && v.isNotEmpty) out[field.key] = v;
      } else if (field.type == 'enum') {
        final v = _enumSelections[field.key];
        if (v != null && v.isNotEmpty) out[field.key] = v;
      } else if (field.type == 'number') {
        final text = _textControllerFor(field.key).text;
        _rememberNumberFieldValue(field.key, text);
        final n = _numberFieldValues[field.key] ?? _parseNumberFieldText(text);
        if (n != null) out[field.key] = n;
      } else if (field.type == 'datetime') {
        final dt = _measuredAtByKey[field.key];
        if (dt != null) out[field.key] = dt.toUtc().toIso8601String();
      } else if (_isTextLike(field.type)) {
        final text = _textControllerFor(field.key).text.trim();
        if (text.isNotEmpty) out[field.key] = text;
      }
    }
    return out;
  }

  Future<void> _startSession() async {
    await _runBusy(() async {
      _resetOperatorFormForNewEvidence();
      setState(() {
        _closedSession = null;
        _hydratedSessionId = null;
      });
      if (widget.isCompanyEvidence) {
        await _sessionCallables.startProductionEvidenceWorkSession(
          companyId: _companyId,
          evidenceConfigId: widget.evidenceConfig!.evidenceConfigId,
        );
      } else {
        await _sessionCallables.startProductionStationWorkSession(
          companyId: _companyId,
          stationSlot: widget.stationConfig!.effectiveStationSlot,
        );
      }
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
    for (final field in _fields) {
      if (!field.required) continue;
      final value = values[field.key];
      if (value == null || (value is String && value.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Polje ${field.label} je obavezno.')),
        );
        return;
      }
    }

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

  List<ControlledInputEntityOption> _entitySelectOptionsFor(
    ProductionStationProfileField field,
  ) {
    switch (field.key) {
      case 'workBathId':
      case 'treatmentPointId':
        return _workBaths;
      case 'chemicalId':
        return _chemicals;
      default:
        return const [];
    }
  }

  Widget _buildEntitySelectField(
    ProductionStationProfileField field, {
    required bool enabled,
  }) {
    final selected = _entitySelections[field.key];
    final options = _entitySelectOptionsFor(field);

    final dependsOnBath = field.filterDependsOn == 'workBathId';
    final bathSelected =
        (_entitySelections['workBathId'] ?? '').trim().isNotEmpty;
    final fieldEnabled = enabled &&
        (!dependsOnBath || bathSelected || field.key == 'workBathId');

    return InputDecorator(
      decoration: _fieldDecoration(
        field,
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
        decoration: _fieldDecoration(field),
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
        title: Row(
          children: [
            Expanded(
              child: Text(field.required ? '${field.label} *' : field.label),
            ),
            if (_infoIcon(field.helperText) != null) _infoIcon(field.helperText)!,
          ],
        ),
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
      final ctrl = _textControllerFor(field.key);
      return TextField(
        controller: ctrl,
        enabled: enabled && !_busy,
        keyboardType: field.type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: field.type == 'text' ? 3 : 1,
        maxLength: field.maxLength,
        decoration: _fieldDecoration(field),
        onChanged: field.type == 'number'
            ? (value) => _rememberNumberFieldValue(field.key, value)
            : null,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMasterSnapshotPreview() {
    final bath = _selectedProcessWorkBath();
    if (bath == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Podaci iz master kataloga',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _previewInfoRow('Procesno područje', _previewProcessAreaLabel()),
            if (_isChemicalDosingProfile) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Koncentracija',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Tooltip(
                    message:
                        'Koncentracija se ne unosi ručno. Ako je definisana u katalogu hemikalije, sistem je prikazuje automatski.',
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_previewConcentrationLabel()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(value),
        ),
      ],
    );
  }

  bool _showUndefinedSnapshot(String key) =>
      key == 'concentrationSnapshot' ||
      key == 'processAreaNameSnapshot' ||
      key == 'treatmentPointNameSnapshot';

  String _snapshotDisplayValue(String key, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (_showUndefinedSnapshot(key)) return 'Nije definisano';
    return '';
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
              final display = _snapshotDisplayValue(field.key, value);
              if (display.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              field.label,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (field.helperText != null &&
                              field.helperText!.trim().isNotEmpty)
                            _infoIcon(field.helperText)!,
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(display),
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

  Widget _buildPlantReadOnlyBanner() {
    final label = _plantDisplayLabel.isEmpty ? _plantKey : _plantDisplayLabel;
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pogon:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildPlantAccessBlocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Ova evidencija pripada drugom pogonu.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildProfileLaunchHero() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withValues(alpha: 0.14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        _profileLaunchIcon(widget.profile.profileKey),
        size: 44,
        color: colorScheme.primary,
      ),
    );
  }

  IconData _profileLaunchIcon(String profileKey) {
    switch (profileKey.trim()) {
      case 'chemical_dosing':
        return Icons.science_outlined;
      case 'wastewater_treatment':
        return Icons.water_outlined;
      case 'process_log':
        return Icons.assignment_outlined;
      case 'rework_and_painting':
        return Icons.format_paint_outlined;
      default:
        return Icons.precision_manufacturing_outlined;
    }
  }

  Widget _buildNoSessionBody() {
    if (!_plantAccessOk) return _buildPlantAccessBlocked();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plantLabel =
        _plantDisplayLabel.isEmpty ? _plantKey : _plantDisplayLabel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileLaunchHero(),
              const SizedBox(height: 24),
              Text(
                widget.profile.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (plantLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Pogon: $plantLabel',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || _masterLoading ? null : _startSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Pokreni evidenciju'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionBody(ProductionStationWorkSession session) {
    if (!_plantAccessOk) return _buildPlantAccessBlocked();

    final formEnabled = session.isActive;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlantReadOnlyBanner(),
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
                'Kontrolisan unos: $_controlledInputModeLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ..._fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOperatorField(field, enabled: formEnabled),
            ),
          ),
          _buildMasterSnapshotPreview(),
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
        stream: widget.isCompanyEvidence
            ? _sessionService.watchActiveSessionForEvidence(
                companyId: _companyId,
                evidenceConfigId: widget.evidenceConfig!.evidenceConfigId,
              )
            : _sessionService.watchActiveSession(
                companyId: _companyId,
                stationSlot: widget.stationConfig!.effectiveStationSlot,
              ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = snap.data ?? _closedSession;
          if (session != null &&
              session.id != _hydratedSessionId &&
              session.isActive) {
            _hydratedSessionId = session.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _syncFormFromSession(session);
              if (_loadsChemicalMasterData) {
                final workBathId = _entitySelections['workBathId'];
                if (workBathId != null && workBathId.isNotEmpty) {
                  unawaited(_reloadChemicalsForWorkBath(workBathId));
                }
              } else {
                _applyUnitDefaultsForSelection();
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
