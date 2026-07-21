import 'package:flutter/material.dart';
import 'package:production_app/core/company_plant_display_name.dart';

import '../models/production_evidence_config.dart';
import '../models/production_station_config.dart';
import '../models/production_station_profile_catalog_entry.dart';
import '../services/production_evidence_config_callable_service.dart';

/// M1-H2 — forma za dodavanje / uređivanje kompanijske evidencije.
class ProductionEvidenceConfigFormScreen extends StatefulWidget {
  const ProductionEvidenceConfigFormScreen({
    super.key,
    required this.companyData,
    required this.profileCatalog,
    required this.canManage,
    this.existing,
    required this.onSaved,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationProfileCatalogResult profileCatalog;
  final bool canManage;
  final ProductionEvidenceConfig? existing;
  final VoidCallback onSaved;

  @override
  State<ProductionEvidenceConfigFormScreen> createState() =>
      _ProductionEvidenceConfigFormScreenState();
}

class _ProductionEvidenceConfigFormScreenState
    extends State<ProductionEvidenceConfigFormScreen> {
  static const String _standardProductionProfileKey = 'standard_production';

  final _callable = ProductionEvidenceConfigCallableService();
  final _nameCtrl = TextEditingController();
  final _processKeyCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();

  bool _saving = false;
  bool _archiving = false;
  bool _plantsLoading = true;
  List<({String plantKey, String label})> _plants = const [];

  late bool _active;
  late bool _runtimeVisible;
  late Set<String> _runtimeRoles;
  late String _plantKey;
  late String _phaseKey;
  late String _profileKey;
  late bool _controlledInputEnabled;
  late String _controlledInputMode;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isEdit => widget.existing != null;

  bool get _readOnly => !widget.canManage || widget.existing?.isArchived == true;

  ProductionStationProfileCatalogEntry? get _selectedProfile =>
      widget.profileCatalog.byKey(_profileKey);

  bool get _profileIsComplete => _selectedProfile?.isComplete ?? false;

  List<ProductionStationProfileCatalogEntry> get _evidenceProfileOptions {
    return widget.profileCatalog.profiles
        .where(
          (p) =>
              p.stationType == ProductionStationConfig.stationTypeProduction &&
              p.profileKey != _standardProductionProfileKey,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl.text = e?.displayName ?? '';
    _processKeyCtrl.text = e?.processKey ?? '';
    _orderCtrl.text = '${e?.displayOrder ?? e?.evidenceSlot ?? 1}';
    _active = e?.active ?? true;
    _runtimeVisible = e?.runtimeVisible ?? false;
    _runtimeRoles = Set<String>.from(e?.runtimeAllowedRoles ?? const []);
    _plantKey = e?.plantKey ??
        (widget.companyData['plantKey'] ?? '').toString().trim();
    _phaseKey = ProductionStationConfig.normalizeProductionPhaseKey(
      e?.phaseKey,
      fallback: 'obrada',
    );
    _profileKey = e?.profileKey ?? 'chemical_dosing';
    _controlledInputEnabled = e?.controlledInputEnabled ?? false;
    _controlledInputMode = e?.controlledInputMode ?? 'off';
    if (_controlledInputEnabled && _controlledInputMode == 'off') {
      _controlledInputMode = 'strict';
    }
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    try {
      final plants = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _plantsLoading = false;
        if (_plantKey.isEmpty && plants.isNotEmpty) {
          _plantKey = plants.first.plantKey;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _plantsLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _processKeyCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  ProductionEvidenceConfig _buildConfig() {
    final existing = widget.existing;
    final slot = existing?.evidenceSlot ?? 0;
    final order = int.tryParse(_orderCtrl.text.trim());

    return ProductionEvidenceConfig(
      evidenceConfigId: existing?.evidenceConfigId ??
          ProductionEvidenceConfig.buildConfigId(
            companyId: _companyId,
            evidenceSlot: slot,
          ),
      companyId: _companyId,
      evidenceSlot: slot,
      plantKey: _plantKey,
      processKey: _processKeyCtrl.text.trim(),
      phaseKey: _phaseKey,
      displayName: _nameCtrl.text.trim(),
      profileKey: _profileKey,
      profileNameSnapshot:
          _selectedProfile?.displayName ??
          ProductionStationConfig.processProfileLabel(_profileKey),
      active: _active,
      runtimeVisible: _runtimeVisible,
      runtimeAllowedRoles: _runtimeRoles.toList(growable: false),
      displayOrder: order,
      controlledInputEnabled: _controlledInputEnabled,
      controlledInputMode: _controlledInputMode,
      controlledInputScope: _controlledInputEnabled &&
              _controlledInputMode != 'off'
          ? ProductionStationConfig.controlledInputScopeWorkBath
          : null,
    );
  }

  Future<void> _save() async {
    if (_readOnly) return;
    final name = _nameCtrl.text.trim();
    final processKey = _processKeyCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Naziv prikaza je obavezan.');
      return;
    }
    if (processKey.isEmpty) {
      _showSnack('Proces (processKey) je obavezan.');
      return;
    }
    if (_plantKey.isEmpty) {
      _showSnack('Odaberite pogon.');
      return;
    }
    if (_runtimeVisible && _runtimeRoles.isEmpty) {
      _showSnack('Odaberite barem jednu ulogu za runtime pristup.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _callable.upsertProductionEvidenceConfig(_buildConfig());
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      _showSnack('Evidencija je spremljena.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(productionEvidenceConfigErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmArchive() async {
    if (!_isEdit || _readOnly) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arhiviraj evidenciju'),
        content: const Text(
          'Evidencija će biti deaktivirana i uklonjena iz aktivnog rada. '
          'Historijski zapisi ostaju u bazi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arhiviraj'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _archiving = true);
    try {
      await _callable.archiveProductionEvidenceConfig(
        companyId: _companyId,
        evidenceConfigId: widget.existing!.evidenceConfigId,
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      _showSnack('Evidencija je arhivirana.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(productionEvidenceConfigErrorMessage(e));
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profileOptions = _evidenceProfileOptions;
    final profileValue = profileOptions.any((p) => p.profileKey == _profileKey)
        ? _profileKey
        : (profileOptions.isNotEmpty ? profileOptions.first.profileKey : _profileKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Uredi evidenciju' : 'Nova evidencija'),
        actions: [
          if (widget.canManage && !_readOnly)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            ),
        ],
      ),
      body: _plantsLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_readOnly && widget.existing?.isArchived == true)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ova evidencija je arhivirana i ne može se uređivati.',
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Evidencije ne ulaze u limit proizvodnih ni mašinskih stanica. '
                      'Ista evidencija može postojati više puta — nezavisno po pogonu i procesu.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_profileKey),
                  isExpanded: true,
                  initialValue: profileValue,
                  decoration: const InputDecoration(
                    labelText: 'Obrazac iz kataloga',
                  ),
                  items: profileOptions
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.profileKey,
                          child: Text(
                            '${p.displayName} — ${p.definitionStatusLabelText}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _readOnly
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _profileKey = v;
                            if (!ProductionStationConfig
                                .supportsControlledInputProfile(v)) {
                              _controlledInputEnabled = false;
                              _controlledInputMode = 'off';
                            }
                            if (!(widget.profileCatalog.byKey(v)?.isComplete ??
                                false)) {
                              _runtimeVisible = false;
                              _runtimeRoles = {};
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  readOnly: _readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Naziv prikaza',
                    helperText: 'npr. Doziranje hemikalija — Pogon BR',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_plantKey),
                  isExpanded: true,
                  initialValue: _plantKey.isEmpty ? null : _plantKey,
                  decoration: const InputDecoration(labelText: 'Pogon'),
                  items: _plants
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.plantKey,
                          child: Text(p.label),
                        ),
                      )
                      .toList(),
                  onChanged: _readOnly
                      ? null
                      : (v) {
                          if (v != null) setState(() => _plantKey = v);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _processKeyCtrl,
                  readOnly: _readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Proces (processKey)',
                    helperText: 'Poslovni ključ procesa u kompaniji (npr. hemikalije_br).',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_phaseKey),
                  isExpanded: true,
                  initialValue: _phaseKey,
                  decoration: const InputDecoration(labelText: 'Faza (phaseKey)'),
                  items: ProductionStationConfig.productionPhaseKeys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(ProductionStationConfig.productionPhaseLabel(k)),
                        ),
                      )
                      .toList(),
                  onChanged: _readOnly
                      ? null
                      : (v) {
                          if (v != null) setState(() => _phaseKey = v);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _orderCtrl,
                  readOnly: _readOnly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Redoslijed prikaza',
                  ),
                ),
                const SizedBox(height: 12),
                if (ProductionStationConfig.supportsControlledInputProfile(
                  _profileKey,
                )) ...[
                  const Divider(height: 24),
                  Text(
                    'Kontrolisan unos evidencije',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operator bira vrijednosti iz kataloga (procesne kupke, hemikalije, '
                    'dozvoljene kombinacije); backend validira pri zatvaranju sesije. '
                    'Master podatke uređujete u postojećem katalogu kontrolisanog unosa.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Uključi kontrolisan unos'),
                    value: _controlledInputEnabled,
                    onChanged: _readOnly
                        ? null
                        : (v) => setState(() {
                              _controlledInputEnabled = v;
                              if (v && _controlledInputMode == 'off') {
                                _controlledInputMode = 'strict';
                              }
                              if (!v) {
                                _controlledInputMode = 'off';
                              }
                            }),
                  ),
                  if (_controlledInputEnabled) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_controlledInputMode),
                      isExpanded: true,
                      initialValue: _controlledInputMode == 'off'
                          ? 'strict'
                          : _controlledInputMode,
                      decoration: const InputDecoration(
                        labelText: 'Režim validacije',
                        helperText:
                            'Strogo odbija nevažeće; Upozorenje zapisuje flag na sesiji.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'strict',
                          child: Text('Strogo (odbij nevažeći unos)'),
                        ),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Upozorenje (dozvoli, zabilježi)'),
                        ),
                      ],
                      onChanged: _readOnly
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _controlledInputMode = v);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Opseg'),
                      subtitle: Text(
                        ProductionStationConfig.controlledInputScopeLabel(
                          ProductionStationConfig.controlledInputScopeWorkBath,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivna evidencija'),
                  value: _active,
                  onChanged: _readOnly ? null : (v) => setState(() => _active = v),
                ),
                if (_profileIsComplete) ...[
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vidljivo operaterima (runtime)'),
                    subtitle: const Text(
                      'Prikaz u operator hubu evidencija za odabrane uloge.',
                    ),
                    value: _runtimeVisible,
                    onChanged: _readOnly
                        ? null
                        : (v) => setState(() {
                              _runtimeVisible = v;
                              if (!v) _runtimeRoles = {};
                            }),
                  ),
                  if (_runtimeVisible && !_readOnly) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Dozvoljene uloge',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ProductionStationConfig.runtimeAssignableRoles
                          .map(
                            (role) => FilterChip(
                              label: Text(
                                ProductionStationConfig.runtimeRoleLabel(role),
                              ),
                              selected: _runtimeRoles.contains(role),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _runtimeRoles.add(role);
                                  } else {
                                    _runtimeRoles.remove(role);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
                if (_isEdit && widget.canManage && !widget.existing!.isArchived) ...[
                  const Divider(height: 32),
                  OutlinedButton.icon(
                    onPressed: _archiving ? null : _confirmArchive,
                    icon: _archiving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.archive_outlined),
                    label: const Text('Arhiviraj evidenciju'),
                  ),
                ],
              ],
            ),
    );
  }
}
