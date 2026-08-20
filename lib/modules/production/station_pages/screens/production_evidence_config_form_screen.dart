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
  final Future<void> Function() onSaved;

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
  final _controlledFormCodeCtrl = TextEditingController();

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

  ProductionEvidenceConfig? _freshExisting;

  /// M1-I5-C2 — greške vezane za konkretna polja.
  String? _errName;
  String? _errProcessKey;
  String? _errPlantKey;
  String? _errProfile;
  String? _errRoles;
  String? _errActive;
  String? _errFormCode;

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
    _applyExistingConfig(e);
    if (e != null) {
      _loadExistingConfigFresh();
    }
    _loadPlants();
  }

  void _applyExistingConfig(ProductionEvidenceConfig? e) {
    _nameCtrl.text = e?.displayName ?? '';
    _processKeyCtrl.text = e?.processKey ?? '';
    _orderCtrl.text = '${e?.displayOrder ?? e?.evidenceSlot ?? 1}';
    _controlledFormCodeCtrl.text = e?.controlledFormDocumentCode ?? '';
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
  }

  Future<void> _loadExistingConfigFresh() async {
    final id = widget.existing?.evidenceConfigId.trim() ?? '';
    if (id.isEmpty || _companyId.isEmpty) return;
    try {
      final fresh = await _callable.getProductionEvidenceConfig(
        companyId: _companyId,
        evidenceConfigId: id,
      );
      if (!mounted) return;
      setState(() {
        _freshExisting = fresh;
        _applyExistingConfig(fresh);
      });
    } catch (_) {
      // Zadrži snapshot s liste ako get ne uspije.
    }
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
    _controlledFormCodeCtrl.dispose();
    super.dispose();
  }

  ProductionEvidenceConfig _buildConfig() {
    final existing = _freshExisting ?? widget.existing;
    final order = int.tryParse(_orderCtrl.text.trim());

    if (existing == null) {
      return ProductionEvidenceConfig(
        evidenceConfigId: '',
        companyId: _companyId,
        evidenceSlot: 0,
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
        controlledFormDocumentCode:
            (_profileKey.trim() == 'in_process_quality_check' ||
                    _profileKey.trim() == 'final_control')
                ? _controlledFormCodeCtrl.text.trim()
                : null,
      );
    }

    final existingId = existing.evidenceConfigId.trim();
    final slot = existing.evidenceSlot > 0
        ? existing.evidenceSlot
        : ProductionEvidenceConfig.parseEvidenceSlotFromMap({
            'evidenceConfigId': existingId,
            'evidenceSlot': existing.evidenceSlot,
          });

    return ProductionEvidenceConfig(
      evidenceConfigId: existingId,
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
      controlledFormDocumentCode:
          (_profileKey.trim() == 'in_process_quality_check' ||
                  _profileKey.trim() == 'final_control')
              ? _controlledFormCodeCtrl.text.trim()
              : null,
    );
  }

  Future<void> _verifySavedControlledInput(
    ProductionEvidenceConfig config, {
    required String evidenceConfigId,
  }) async {
    if (!ProductionStationConfig.supportsControlledInputProfile(config.profileKey)) {
      return;
    }
    final verified = await _callable.getProductionEvidenceConfig(
      companyId: _companyId,
      evidenceConfigId: evidenceConfigId,
    );
    if (verified.controlledInputEnabled != config.controlledInputEnabled) {
      throw Exception(
        'Kontrolisan unos nije potvrđen na serveru — osvježite i pokušajte ponovo.',
      );
    }
    if (!config.controlledInputEnabled) return;
    final expectedMode = config.controlledInputMode == 'off'
        ? 'strict'
        : config.controlledInputMode;
    if (verified.controlledInputMode != expectedMode) {
      throw Exception(
        'Režim kontrolisanog unosa nije potvrđen na serveru.',
      );
    }
  }

  void _clearFieldErrors() {
    _errName = null;
    _errProcessKey = null;
    _errPlantKey = null;
    _errProfile = null;
    _errRoles = null;
    _errActive = null;
    _errFormCode = null;
  }

  void _applyMappedFieldError(ProductionEvidenceConfigUiError mapped) {
    switch (mapped.fieldKey) {
      case 'name':
        _errName = mapped.fieldMessage;
        break;
      case 'processKey':
        _errProcessKey = mapped.fieldMessage;
        break;
      case 'plantKey':
        _errPlantKey = mapped.fieldMessage;
        break;
      case 'profile':
        _errProfile = mapped.fieldMessage;
        break;
      case 'roles':
        _errRoles = mapped.fieldMessage;
        break;
      case 'active':
        _errActive = mapped.fieldMessage;
        break;
      case 'formCode':
        _errFormCode = mapped.fieldMessage;
        break;
    }
  }

  /// Lokalna validacija prije Callable-a — greške idu na polja.
  bool _validateBeforeSave() {
    _clearFieldErrors();
    var ok = true;
    final name = _nameCtrl.text.trim();
    final processKey = _processKeyCtrl.text.trim();

    if (_profileKey.trim().isEmpty) {
      _errProfile = 'Odaberite profil evidencije.';
      ok = false;
    }
    if (name.isEmpty) {
      _errName = 'Naziv prikaza je obavezan.';
      ok = false;
    }
    if (processKey.isEmpty) {
      _errProcessKey = 'Proces je obavezan.';
      ok = false;
    }
    if (_plantKey.isEmpty) {
      _errPlantKey = 'Odaberite pogon.';
      ok = false;
    }
    if (_runtimeVisible && _runtimeRoles.isEmpty) {
      _errRoles =
          'Odaberite najmanje jednu dozvoljenu ulogu za runtime prikaz.';
      ok = false;
    }
    if (_active) {
      if (name.isEmpty || processKey.isEmpty || _plantKey.isEmpty) {
        _errActive =
            'Evidencija ne može biti aktivna dok nisu popunjena obavezna polja.';
        ok = false;
      }
      if (_runtimeVisible && _runtimeRoles.isEmpty) {
        _errActive =
            'Evidencija ne može biti aktivna dok nisu popunjena obavezna polja.';
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _save() async {
    if (_readOnly) return;
    if (!_validateBeforeSave()) {
      setState(() {});
      _showSnack(
        'Nije moguće spremiti evidenciju. Provjerite označena polja.',
      );
      return;
    }
    if (_isEdit && (widget.existing?.evidenceConfigId.trim().isEmpty ?? true)) {
      _showSnack(
        'Nedostaje identifikator evidencije — osvježite listu i pokušajte ponovo.',
      );
      return;
    }

    setState(() {
      _clearFieldErrors();
      _saving = true;
    });
    try {
      final config = _buildConfig();
      final savedId = await _callable.upsertProductionEvidenceConfig(
        config,
        isCreate: !_isEdit,
      );
      if (_isEdit && savedId != config.evidenceConfigId) {
        throw Exception('Server nije potvrdio ažuriranje iste evidencije.');
      }
      if (!_isEdit && savedId.isEmpty) {
        throw Exception('Server nije dodijelio novi identifikator evidencije.');
      }
      await _verifySavedControlledInput(
        config,
        evidenceConfigId: _isEdit ? config.evidenceConfigId : savedId,
      );
      if (!mounted) return;
      await widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapProductionEvidenceConfigError(e);
      setState(() {
        _clearFieldErrors();
        _applyMappedFieldError(mapped);
      });
      _showSnack(mapped.snackMessage);
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
      await widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(productionEvidenceConfigArchiveErrorMessage(e));
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

    return PopScope(
      canPop: !_saving && !_archiving,
      child: Scaffold(
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
                  decoration: InputDecoration(
                    labelText: 'Obrazac iz kataloga',
                    errorText: _errProfile,
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
                            _errProfile = null;
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
                  onChanged: (_) {
                    if (_errName != null) setState(() => _errName = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Naziv prikaza',
                    helperText: 'npr. Doziranje hemikalija — Pogon BR',
                    errorText: _errName,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_plantKey),
                  isExpanded: true,
                  initialValue: _plantKey.isEmpty ? null : _plantKey,
                  decoration: InputDecoration(
                    labelText: 'Pogon',
                    errorText: _errPlantKey,
                  ),
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
                          if (v != null) {
                            setState(() {
                              _errPlantKey = null;
                              _plantKey = v;
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _processKeyCtrl,
                  readOnly: _readOnly,
                  onChanged: (_) {
                    if (_errProcessKey != null) {
                      setState(() => _errProcessKey = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Proces (processKey)',
                    helperText:
                        'Poslovni ključ procesa u kompaniji (npr. hemikalije_br).',
                    errorText: _errProcessKey,
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
                if (_profileKey.trim() == 'in_process_quality_check' ||
                    _profileKey.trim() == 'final_control') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 24),
                  Text(
                    'Kontrolisani obrazac (QMS)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unesite samo oznaku obrasca prema dokumentacionoj politici '
                    'kompanije. Naziv, revizija, status, vlasnik i retention '
                    'povlače se iz odobrenog QMS obrasca (Dokumentacija → Obrasci).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controlledFormCodeCtrl,
                    readOnly: _readOnly,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_errFormCode != null) {
                        setState(() => _errFormCode = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Oznaka obrasca / dokumenta',
                      hintText: 'npr. QF-PC-001, OBR-KV-04, F-08.2-PR',
                      helperText:
                          'Format nije propisan sistemom — određuje ga kompanija.',
                      errorText: _errFormCode,
                    ),
                  ),
                ],
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
                  subtitle: _errActive == null
                      ? null
                      : Text(
                          _errActive!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                  value: _active,
                  onChanged: _readOnly
                      ? null
                      : (v) => setState(() {
                            _errActive = null;
                            _active = v;
                          }),
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
                              _errRoles = null;
                              if (!v) _runtimeRoles = {};
                            }),
                  ),
                  if (_runtimeVisible && !_readOnly) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Dozvoljene uloge',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _errRoles != null
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                    if (_errRoles != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _errRoles!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                                  _errRoles = null;
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
      ),
    );
  }
}
