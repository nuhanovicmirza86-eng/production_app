import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../features/process_evidence_analytics/widgets/process_evidence_analytics_filters.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/services/production_station_config_callable_service.dart';
import '../models/workforce_performance_norm_models.dart';
import '../services/workforce_performance_norms_callable_service.dart';

/// M2-G2 — detalj / uređivanje / aktivacija / arhiva / test match-a normativa.
class WorkforcePerformanceNormDetailScreen extends StatefulWidget {
  const WorkforcePerformanceNormDetailScreen({
    super.key,
    required this.companyData,
    this.normId,
  });

  final Map<String, dynamic> companyData;
  final String? normId;

  bool get isCreate => (normId ?? '').trim().isEmpty;

  @override
  State<WorkforcePerformanceNormDetailScreen> createState() =>
      _WorkforcePerformanceNormDetailScreenState();
}

class _WorkforcePerformanceNormDetailScreenState
    extends State<WorkforcePerformanceNormDetailScreen> {
  final _service = WorkforcePerformanceNormsCallableService();
  final _stationConfigService = ProductionStationConfigCallableService();

  final _displayNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _operationTypeController = TextEditingController();
  final _productIdController = TextEditingController();
  final _productCodeController = TextEditingController();
  final _pieceTypeController = TextEditingController();
  final _targetPphController = TextEditingController();
  final _stdMinController = TextEditingController();
  final _scrapRateController = TextEditingController();
  final _okRateController = TextEditingController();
  final _difficultyWeightController = TextEditingController(text: '1');
  final _validFromController = TextEditingController();
  final _validToController = TextEditingController();
  final _changeReasonController = TextEditingController();

  // Match test fields
  final _matchOperationTypeController = TextEditingController();
  final _matchProductIdController = TextEditingController();
  final _matchProductCodeController = TextEditingController();
  final _matchAsOfDateController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  Object? _error;
  WorkforcePerformanceNorm? _norm;
  List<WorkforcePerformanceNorm> _versions = const [];
  String? _lastAuditLogId;

  String? _plantKey;
  String? _processProfileType;
  String? _stationConfigId;
  String? _operationDifficulty;

  String? _matchPlantKey;
  String? _matchProfileType;
  String? _matchStationConfigId;
  WorkforcePerformanceNormMatchResult? _matchResult;
  bool _matchLoading = false;

  List<({String plantKey, String label})> _plantOptions = const [];
  List<ProductionStationConfig> _allStationConfigs = const [];
  String? _fixedPlantLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canManage =>
      ProductionAccessHelper.canManageWorkforcePerformanceNorms(_userRole);

  bool get _canPickPlant =>
      ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(
        _userRole,
      );

  bool get _isEditable =>
      widget.isCreate || (_norm?.canEdit ?? false);

  List<ProductionStationConfig> get _stationOptions =>
      filterAnalyticsStationOptions(
        configs: _allStationConfigs,
        plantKey: _plantKey,
        processProfileType: _processProfileType,
      );

  List<ProductionStationConfig> get _matchStationOptions =>
      filterAnalyticsStationOptions(
        configs: _allStationConfigs,
        plantKey: _matchPlantKey,
        processProfileType: _matchProfileType,
      );

  @override
  void initState() {
    super.initState();
    if (!_canPickPlant && _userPlantKey.isNotEmpty) {
      _plantKey = _userPlantKey;
      _matchPlantKey = _userPlantKey;
    }
    if (_canManage) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _notesController.dispose();
    _operationTypeController.dispose();
    _productIdController.dispose();
    _productCodeController.dispose();
    _pieceTypeController.dispose();
    _targetPphController.dispose();
    _stdMinController.dispose();
    _scrapRateController.dispose();
    _okRateController.dispose();
    _difficultyWeightController.dispose();
    _validFromController.dispose();
    _validToController.dispose();
    _changeReasonController.dispose();
    _matchOperationTypeController.dispose();
    _matchProductIdController.dispose();
    _matchProductCodeController.dispose();
    _matchAsOfDateController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plantsFuture = loadAnalyticsPlantOptions(
        companyId: _companyId,
        userRole: _userRole,
        userPlantKey: _userPlantKey,
      );
      final configsFuture = _stationConfigService.listProductionStationConfigs(
        companyId: _companyId,
      );
      final plants = await plantsFuture;
      final configs = await configsFuture;
      String? fixedLabel;
      if (!_canPickPlant && _userPlantKey.isNotEmpty) {
        fixedLabel = await CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: _userPlantKey,
        );
      }
      if (!mounted) return;
      setState(() {
        _plantOptions = plants;
        _allStationConfigs = configs.configs;
        _fixedPlantLabel = fixedLabel;
      });
      if (!widget.isCreate) {
        await _loadNorm();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workforcePerformanceNormsErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadNorm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getNorm(
        companyId: _companyId,
        normId: widget.normId!,
        includeVersionHistory: true,
      );
      if (!mounted) return;
      _applyNormToForm(result.norm);
      setState(() {
        _norm = result.norm;
        _versions = result.versions;
        _loading = false;
        _matchPlantKey = result.norm.plantKey ?? _matchPlantKey;
        _matchProfileType = result.norm.processProfileType;
        _matchStationConfigId = result.norm.stationConfigId;
        _matchOperationTypeController.text = result.norm.operationType ?? '';
        _matchProductIdController.text = result.norm.productId ?? '';
        _matchProductCodeController.text = result.norm.productCode ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = workforcePerformanceNormsErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _applyNormToForm(WorkforcePerformanceNorm norm) {
    _displayNameController.text = norm.displayName ?? '';
    _notesController.text = norm.notes ?? '';
    _plantKey = norm.plantKey;
    _processProfileType = norm.processProfileType;
    _stationConfigId = norm.stationConfigId;
    _operationTypeController.text = norm.operationType ?? '';
    _productIdController.text = norm.productId ?? '';
    _productCodeController.text = norm.productCode ?? '';
    _pieceTypeController.text = norm.pieceType ?? '';
    _targetPphController.text = norm.targetPiecesPerHour?.toString() ?? '';
    _stdMinController.text = norm.standardMinutesPerPiece?.toString() ?? '';
    _scrapRateController.text = norm.allowedScrapRatePercent?.toString() ?? '';
    _okRateController.text = norm.targetOkRatePercent?.toString() ?? '';
    _operationDifficulty = norm.operationDifficulty;
    _difficultyWeightController.text =
        (norm.difficultyWeight ?? 1).toString();
    _validFromController.text = norm.validFrom ?? '';
    _validToController.text = norm.validTo ?? '';
    _changeReasonController.text = norm.changeReason ?? '';
  }

  Map<String, dynamic> _buildPayload() {
    num? parseNum(String raw) {
      final t = raw.trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      return num.tryParse(t);
    }

    return {
      'displayName': _displayNameController.text.trim(),
      'notes': _notesController.text.trim(),
      'plantKey': _plantKey,
      'processProfileType': _processProfileType,
      'stationConfigId': _stationConfigId,
      'operationType': _operationTypeController.text.trim(),
      'productId': _productIdController.text.trim(),
      'productCode': _productCodeController.text.trim(),
      'pieceType': _pieceTypeController.text.trim(),
      'targetPiecesPerHour': parseNum(_targetPphController.text),
      'standardMinutesPerPiece': parseNum(_stdMinController.text),
      'allowedScrapRatePercent': parseNum(_scrapRateController.text),
      'targetOkRatePercent': parseNum(_okRateController.text),
      'operationDifficulty': _operationDifficulty,
      'difficultyWeight': parseNum(_difficultyWeightController.text) ?? 1,
      'validFrom': _validFromController.text.trim(),
      'validTo': _validToController.text.trim(),
      'changeReason': _changeReasonController.text.trim(),
    };
  }

  void _showAuditSnack(String action, String? auditLogId) {
    final id = (auditLogId ?? '').trim();
    final msg = id.isEmpty
        ? '$action — audit zapis kreiran.'
        : '$action — auditLogId: $id';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      WorkforcePerformanceNormMutationResult result;
      if (widget.isCreate) {
        result = await _service.createDraft(
          companyId: _companyId,
          payload: payload,
        );
        if (!mounted) return;
        _showAuditSnack('Nacrt kreiran', result.auditLogId);
        Navigator.of(context).pop(true);
        return;
      }
      result = await _service.updateNorm(
        companyId: _companyId,
        normId: widget.normId!,
        payload: payload,
      );
      if (!mounted) return;
      setState(() {
        _norm = result.norm;
        _lastAuditLogId = result.auditLogId;
        _saving = false;
      });
      _showAuditSnack('Nacrt spremljen', result.auditLogId);
      await _loadNorm();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(workforcePerformanceNormsErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _activate() async {
    final validFrom = _validFromController.text.trim();
    final changeReason = _changeReasonController.text.trim();
    if (validFrom.isEmpty || changeReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Za aktivaciju unesi validFrom (YYYY-MM-DD) i razlog promjene.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktiviraj normativ'),
        content: const Text(
          'Aktivacija objavljuje normativ i zamjenjuje prethodnu aktivnu verziju u istoj grupi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktiviraj'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await _service.updateNorm(
        companyId: _companyId,
        normId: widget.normId!,
        payload: {
          ..._buildPayload(),
          'status': 'active',
        },
      );
      if (!mounted) return;
      _showAuditSnack('Normativ aktiviran', result.auditLogId);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(workforcePerformanceNormsErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _archive() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arhiviraj normativ'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Razlog arhiviranja',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () {
              final r = reasonController.text.trim();
              if (r.isEmpty) return;
              Navigator.pop(ctx, r);
            },
            child: const Text('Arhiviraj'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if ((reason ?? '').isEmpty) return;

    setState(() => _saving = true);
    try {
      final result = await _service.archiveNorm(
        companyId: _companyId,
        normId: widget.normId!,
        reason: reason!,
      );
      if (!mounted) return;
      _showAuditSnack('Normativ arhiviran', result.auditLogId);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(workforcePerformanceNormsErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _runMatchTest() async {
    final plantKey = (_matchPlantKey ?? '').trim();
    if (plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Za match test odaberi pogon.')),
      );
      return;
    }
    setState(() => _matchLoading = true);
    try {
      final result = await _service.matchNorm(
        companyId: _companyId,
        plantKey: plantKey,
        processProfileType: _matchProfileType,
        stationConfigId: _matchStationConfigId,
        operationType: _matchOperationTypeController.text.trim(),
        productId: _matchProductIdController.text.trim(),
        productCode: _matchProductCodeController.text.trim(),
        asOfDate: _matchAsOfDateController.text.trim().isEmpty
            ? null
            : _matchAsOfDateController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _matchResult = result;
        _matchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _matchLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(workforcePerformanceNormsErrorMessage(e))),
      );
    }
  }

  Future<void> _pickIsoDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openVersion(WorkforcePerformanceNorm version) async {
    if (version.normId == widget.normId) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkforcePerformanceNormDetailScreen(
          companyData: widget.companyData,
          normId: version.normId,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadNorm();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Normativ rada')),
        body: const Center(child: Text('Nemaš pristup.')),
      );
    }

    final t = Theme.of(context);
    final title = widget.isCreate
        ? 'Novi nacrt normativa'
        : (_norm?.displayName?.trim().isNotEmpty == true
              ? _norm!.displayName!.trim()
              : 'Normativ rada');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error.toString(),
                      style: TextStyle(color: t.colorScheme.error),
                    ),
                  ),
                if (_norm != null) ...[
                  _HeaderCard(norm: _norm!),
                  if ((_lastAuditLogId ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Zadnji auditLogId: $_lastAuditLogId',
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                ],
                _FormSection(
                  title: 'Osnovno',
                  children: [
                    TextField(
                      controller: _displayNameController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Naziv normativa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Napomena',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
                _FormSection(
                  title: 'Opseg (match dimenzije)',
                  children: [
                    if (_canPickPlant)
                      DropdownButtonFormField<String?>(
                        value: _plantKey,
                        decoration: const InputDecoration(
                          labelText: 'Pogon',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('—'),
                          ),
                          ..._plantOptions.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.plantKey,
                              child: Text(p.label),
                            ),
                          ),
                        ],
                        onChanged: _isEditable && !_saving
                            ? (v) => setState(() {
                                _plantKey = v;
                                _stationConfigId = null;
                              })
                            : null,
                      )
                    else if (_fixedPlantLabel != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pogon'),
                        subtitle: Text(_fixedPlantLabel!),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _processProfileType,
                      decoration: const InputDecoration(
                        labelText: 'Profil procesa',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        ...workforceNormProfileLabels.entries.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: _isEditable && !_saving
                          ? (v) => setState(() {
                              _processProfileType = v;
                              _stationConfigId = null;
                            })
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _stationConfigId,
                      decoration: const InputDecoration(
                        labelText: 'Stanica (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        ..._stationOptions.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(
                              (s.displayName ?? '').trim().isNotEmpty
                                  ? s.displayName!.trim()
                                  : 'Slot ${s.effectiveStationSlot}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _isEditable && !_saving
                          ? (v) => setState(() => _stationConfigId = v)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _operationTypeController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Tip operacije (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _productIdController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'productId (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _productCodeController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'productCode (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pieceTypeController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'pieceType (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                _FormSection(
                  title: 'Metrike',
                  children: [
                    TextField(
                      controller: _targetPphController,
                      enabled: _isEditable && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cilj komada/sat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _stdMinController,
                      enabled: _isEditable && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Standard min/kom',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _scrapRateController,
                      enabled: _isEditable && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Dopušteni škart %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _okRateController,
                      enabled: _isEditable && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cilj OK % (opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _operationDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Težina operacije',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        ...workforceNormDifficulties.entries.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: _isEditable && !_saving
                          ? (v) => setState(() => _operationDifficulty = v)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _difficultyWeightController,
                      enabled: _isEditable && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Težinski faktor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                _FormSection(
                  title: 'Valjanost i razlog',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _validFromController,
                            enabled: _isEditable && !_saving,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'validFrom (YYYY-MM-DD)',
                              border: OutlineInputBorder(),
                            ),
                            onTap: _isEditable && !_saving
                                ? () => _pickIsoDate(_validFromController)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _validToController,
                            enabled: _isEditable && !_saving,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'validTo (opcionalno)',
                              border: OutlineInputBorder(),
                            ),
                            onTap: _isEditable && !_saving
                                ? () => _pickIsoDate(_validToController)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _changeReasonController,
                      enabled: _isEditable && !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Razlog promjene',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
                if (_isEditable) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveDraft,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.isCreate ? 'Kreiraj nacrt' : 'Spremi nacrt'),
                  ),
                  if (!widget.isCreate && _norm?.isDraft == true) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _activate,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Aktiviraj normativ'),
                    ),
                  ],
                ],
                if (_norm != null &&
                    (_norm!.isActive || _norm!.isDraft)) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _archive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arhiviraj'),
                  ),
                ],
                if (_versions.length > 1) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Verzije u grupi',
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._versions.map(
                    (v) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'v${v.version} · ${workforceNormStatusLabel(v.status)}',
                      ),
                      subtitle: Text(v.normId),
                      trailing: v.normId == widget.normId
                          ? const Icon(Icons.check, size: 18)
                          : const Icon(Icons.chevron_right),
                      onTap: () => _openVersion(v),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ExpansionTile(
                  initiallyExpanded: !widget.isCreate,
                  title: const Text('Test match normativa'),
                  subtitle: const Text(
                    'Provjera hijerarhije match-a (normativeReady ostaje false u M2-F dok G3 nije aktivan).',
                  ),
                  children: [
                    if (_canPickPlant)
                      DropdownButtonFormField<String?>(
                        value: _matchPlantKey,
                        decoration: const InputDecoration(
                          labelText: 'Pogon (match)',
                          border: OutlineInputBorder(),
                        ),
                        items: _plantOptions
                            .map(
                              (p) => DropdownMenuItem<String?>(
                                value: p.plantKey,
                                child: Text(p.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _matchPlantKey = v;
                          _matchStationConfigId = null;
                        }),
                      )
                    else if (_fixedPlantLabel != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pogon (match)'),
                        subtitle: Text(_fixedPlantLabel!),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _matchProfileType,
                      decoration: const InputDecoration(
                        labelText: 'Profil procesa (match)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        ...workforceNormProfileLabels.entries.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _matchProfileType = v;
                        _matchStationConfigId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _matchStationConfigId,
                      decoration: const InputDecoration(
                        labelText: 'Stanica (match)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        ..._matchStationOptions.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(
                              (s.displayName ?? '').trim().isNotEmpty
                                  ? s.displayName!.trim()
                                  : 'Slot ${s.effectiveStationSlot}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _matchStationConfigId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _matchOperationTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Tip operacije (match)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _matchProductIdController,
                      decoration: const InputDecoration(
                        labelText: 'productId (match)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _matchProductCodeController,
                      decoration: const InputDecoration(
                        labelText: 'productCode (match)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _matchAsOfDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'asOfDate (YYYY-MM-DD, opcionalno)',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () => _pickIsoDate(_matchAsOfDateController),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _matchLoading ? null : _runMatchTest,
                      icon: _matchLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Pokreni match'),
                    ),
                    if (_matchResult != null) ...[
                      const SizedBox(height: 16),
                      _MatchResultCard(result: _matchResult!),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.norm});

  final WorkforcePerformanceNorm norm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verzija ${norm.version} · ${workforceNormStatusLabel(norm.status)}',
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText('normGroupId: ${norm.normGroupId}'),
            SelectableText('normId: ${norm.normId}'),
            if ((norm.validFrom ?? '').isNotEmpty)
              Text(
                'Vrijedi: ${norm.validFrom}'
                '${(norm.validTo ?? '').isNotEmpty ? ' — ${norm.validTo}' : ''}',
              ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({required this.result});

  final WorkforcePerformanceNormMatchResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final matched = result.matchedNorm;
    return Card(
      color: result.normativeReady
          ? t.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : t.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'normativeReady: ${result.normativeReady}',
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('matchLevel: ${result.matchLevel ?? '—'}'),
            if (matched != null) ...[
              const Divider(),
              Text(
                matched.displayName ?? matched.normId ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('normId: ${matched.normId ?? '—'}'),
              Text('v${matched.version ?? '—'} · grupa ${matched.normGroupId ?? '—'}'),
              if (matched.targetPiecesPerHour != null)
                Text('Cilj kom/sat: ${matched.targetPiecesPerHour}'),
              if (matched.allowedScrapRatePercent != null)
                Text('Škart %: ${matched.allowedScrapRatePercent}'),
            ] else
              const Text('matchedNorm: null'),
          ],
        ),
      ),
    );
  }
}
