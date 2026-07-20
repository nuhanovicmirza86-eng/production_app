import 'package:flutter/material.dart';
import 'package:production_app/core/company_plant_display_name.dart';

import '../../tracking/models/production_operator_tracking_entry.dart';
import '../models/production_station_config.dart';
import '../models/production_station_display_options.dart';
import '../models/production_station_profile_catalog_entry.dart';
import '../services/production_station_config_callable_service.dart';
import '../utils/production_station_legacy_lock.dart';

/// M1-G2 — jedna Admin forma za [ProductionStationConfig.stationTypeProduction].
class ProductionStationAdminFormScreen extends StatefulWidget {
  const ProductionStationAdminFormScreen({
    super.key,
    required this.companyData,
    required this.profileCatalog,
    required this.limits,
    this.existing,
    required this.stationSlot,
    required this.onSaved,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationProfileCatalogResult profileCatalog;
  final ProductionStationLimitsSummary limits;
  final ProductionStationConfig? existing;
  final int stationSlot;
  final VoidCallback onSaved;

  @override
  State<ProductionStationAdminFormScreen> createState() =>
      _ProductionStationAdminFormScreenState();
}

class _ProductionStationAdminFormScreenState
    extends State<ProductionStationAdminFormScreen> {
  final _callable = ProductionStationConfigCallableService();
  final _nameCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();

  bool _saving = false;
  bool _plantsLoading = true;
  List<({String plantKey, String label})> _plants = const [];

  late bool _active;
  late bool _runtimeVisible;
  late Set<String> _runtimeRoles;
  late String _plantKey;
  late String _productionPhaseKey;
  late String _phase;
  late String _profileKey;
  late bool _quickEntryDefault;
  late int _accentIndex;
  late bool _showPackingActions;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isEdit => widget.existing != null;

  bool get _isLegacyLocked =>
      widget.existing != null &&
      ProductionStationLegacyLock.isLocked(widget.existing!);

  ProductionStationProfileCatalogEntry? get _selectedProfileEntry =>
      widget.profileCatalog.byKey(_profileKey);

  bool get _profileIsComplete => _selectedProfileEntry?.isComplete ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl.text = e?.displayName ?? '';
    _orderCtrl.text = '${e?.order ?? widget.stationSlot}';
    _active = e?.active ?? true;
    _runtimeVisible = e?.runtimeVisible ?? false;
    _runtimeRoles = Set<String>.from(e?.runtimeAllowedRoles ?? const []);
    _plantKey = e?.assignedPlantKey ??
        (widget.companyData['plantKey'] ?? '').toString().trim();
    _productionPhaseKey = ProductionStationConfig.normalizeProductionPhaseKey(
      e?.productionPhaseKey,
      fallback: 'pripremna',
    );
    _phase = e?.phase ?? ProductionOperatorTrackingEntry.phasePreparation;
    _profileKey = e?.processProfileType ?? 'standard_production';
    final opts = e?.displayOptions ?? const ProductionStationDisplayOptions();
    _quickEntryDefault = opts.quickEntryModeDefault ?? true;
    _accentIndex = (opts.accentThemeIndex ?? 0).clamp(0, 3);
    _showPackingActions = opts.showPackingActions ?? false;
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
    _orderCtrl.dispose();
    super.dispose();
  }

  List<ProductionStationProfileCatalogEntry> get _profileOptions {
    final options = widget.profileCatalog.profilesForStationType(
      ProductionStationConfig.stationTypeProduction,
    );
    if (options.any((p) => p.profileKey == _profileKey)) return options;
    return [
      ProductionStationProfileCatalogEntry(
        profileKey: _profileKey,
        displayName: ProductionStationConfig.processProfileLabel(_profileKey),
        description: '',
        stationType: ProductionStationConfig.stationTypeProduction,
        definitionStatus: 'skeleton',
      ),
      ...options,
    ];
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _labelWithInfo({
    required String label,
    required String infoTitle,
    required String infoBody,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        IconButton(
          tooltip: 'Objašnjenje',
          icon: const Icon(Icons.info_outline, size: 20),
          onPressed: () => _showInfo(infoTitle, infoBody),
        ),
      ],
    );
  }

  ProductionStationConfig _buildConfig() {
    final existing = widget.existing;
    final locked = existing != null && ProductionStationLegacyLock.isLocked(existing);
    final order = int.tryParse(_orderCtrl.text.trim()) ?? widget.stationSlot;

    final profileEntry = widget.profileCatalog.byKey(_profileKey);
    final flags = profileEntry?.defaultFlags ?? const {};

    bool flag(String key, bool fallback) {
      final v = flags[key];
      if (v is bool) return v;
      return fallback;
    }

    final displayOptions = ProductionStationDisplayOptions(
      quickEntryModeDefault: _quickEntryDefault,
      accentThemeIndex: _accentIndex,
      showPackingActions: _showPackingActions,
    );

    return ProductionStationConfig(
      id: ProductionStationConfig.buildConfigId(
        companyId: _companyId,
        stationSlot: widget.stationSlot,
      ),
      companyId: _companyId,
      stationSlot: widget.stationSlot,
      displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      order: order,
      active: _active,
      stationType: ProductionStationConfig.stationTypeProduction,
      processProfileType: locked
          ? existing.processProfileType
          : _profileKey,
      assignedPlantKey: _plantKey,
      productionPhaseKey: _productionPhaseKey,
      phase: _phase,
      requiresOperatorLogin: existing?.requiresOperatorLogin ??
          flag('requiresOperatorLogin', true),
      requiresWorkOrder:
          existing?.requiresWorkOrder ?? flag('requiresWorkOrder', true),
      requiresProduct: existing?.requiresProduct ?? flag('requiresProduct', true),
      requiresQuantityOutput: existing?.requiresQuantityOutput ??
          flag('requiresQuantityOutput', true),
      requiresMaterialConsumption: existing?.requiresMaterialConsumption ??
          flag('requiresMaterialConsumption', false),
      requiresQualityCheck: existing?.requiresQualityCheck ??
          flag('requiresQualityCheck', false),
      supportsManualProductionInput:
          existing?.supportsManualProductionInput ?? true,
      supportsMachineCounters: false,
      machineIntegration: existing?.machineIntegration ??
          const ProductionStationMachineIntegration(),
      packingFlowEnabled: existing?.packingFlowEnabled ?? _showPackingActions,
      legacyOperatorNavSlot: locked ? existing.legacyOperatorNavSlot : null,
      controlledInputEnabled: existing?.controlledInputEnabled ?? false,
      controlledInputMode: existing?.controlledInputMode ?? 'off',
      controlledInputScope: existing?.controlledInputScope,
      runtimeVisible: locked ? existing.runtimeVisible : _runtimeVisible,
      runtimeAllowedRoles: locked
          ? existing.runtimeAllowedRoles
          : (_runtimeVisible ? _runtimeRoles.toList() : const []),
      displayOptions: displayOptions,
      stationCode: existing?.stationCode,
      description: existing?.description,
      notes: existing?.notes,
      inboundWarehouseId: existing?.inboundWarehouseId,
      outboundWarehouseId: existing?.outboundWarehouseId,
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesite naziv stanice.')),
      );
      return;
    }
    if (_plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite pogon.')),
      );
      return;
    }
    if (_profileIsComplete && _runtimeVisible && _runtimeRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberite barem jednu dozvoljenu ulogu.'),
        ),
      );
      return;
    }
    if (!_isEdit && _active && !widget.limits.canAddProductionStation()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dostigli ste maksimalan broj proizvodnih stanica za vaš paket.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _callable.upsertProductionStationConfig(_buildConfig());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stanica je spremljena.')),
      );
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productionStationLimitMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Uredi proizvodnu stanicu' : 'Nova proizvodna stanica';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
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
                if (_isLegacyLocked) ...[
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Zaključana postojeća stanica',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naziv stanice',
                  ),
                ),
                const SizedBox(height: 16),
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
                  onChanged: _plants.isEmpty
                      ? null
                      : (v) {
                          if (v != null) setState(() => _plantKey = v);
                        },
                ),
                const SizedBox(height: 16),
                _labelWithInfo(
                  label: 'Operacija u proizvodnji',
                  infoTitle: 'Operacija u proizvodnji',
                  infoBody:
                      'Poslovni naziv faze u kojoj stanica radi (npr. priprema, kontrola, završna kontrola). '
                      'Koristi se za izvještaje i administraciju po pogonskim procesima.',
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('ppk_$_productionPhaseKey'),
                  isExpanded: true,
                  initialValue: ProductionStationConfig.productionPhaseKeys
                          .contains(_productionPhaseKey)
                      ? _productionPhaseKey
                      : ProductionStationConfig.productionPhaseKeys.first,
                  decoration: const InputDecoration(
                    labelText: 'Operacija u proizvodnji',
                  ),
                  items: ProductionStationConfig.productionPhaseKeys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(
                            ProductionStationConfig.productionPhaseLabel(k),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _productionPhaseKey = v);
                  },
                ),
                const SizedBox(height: 8),
                _labelWithInfo(
                  label: 'Faza unosa na stanici',
                  infoTitle: 'Faza unosa na stanici',
                  infoBody:
                      'Određuje koji operativni ekran unosa koristi stanica: pripremna, prva ili završna kontrola. '
                      'Za postojeće stanice 1–3 ova veza je fiksna.',
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('phase_$_phase'),
                  isExpanded: true,
                  initialValue: _phase,
                  decoration: const InputDecoration(
                    labelText: 'Faza unosa na stanici',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ProductionOperatorTrackingEntry.phasePreparation,
                      child: Text('Pripremna'),
                    ),
                    DropdownMenuItem(
                      value: ProductionOperatorTrackingEntry.phaseFirstControl,
                      child: Text('Prva kontrola'),
                    ),
                    DropdownMenuItem(
                      value: ProductionOperatorTrackingEntry.phaseFinalControl,
                      child: Text('Završna kontrola'),
                    ),
                  ],
                  onChanged: _isLegacyLocked
                      ? null
                      : (v) {
                          if (v != null) setState(() => _phase = v);
                        },
                ),
                const SizedBox(height: 16),
                _labelWithInfo(
                  label: 'Obrazac evidencije',
                  infoTitle: 'Obrazac evidencije',
                  infoBody:
                      'Definira koja polja i pravila vrijede na operativnom ekranu stanice. '
                      'Standardna proizvodnja koristi puni unos količina i škarta. '
                      'Ostali obrasci su namijenjeni posebnim procesima (npr. doziranje hemikalija).',
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(_profileKey),
                  isExpanded: true,
                  initialValue: _profileOptions.any((p) => p.profileKey == _profileKey)
                      ? _profileKey
                      : _profileOptions.first.profileKey,
                  decoration: const InputDecoration(
                    labelText: 'Obrazac evidencije',
                  ),
                  selectedItemBuilder: (context) => _profileOptions
                      .map(
                        (p) => Text(
                          p.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                  items: _profileOptions
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
                  onChanged: _isLegacyLocked
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _profileKey = v;
                            final complete =
                                widget.profileCatalog.byKey(v)?.isComplete ?? false;
                            if (!complete) {
                              _runtimeVisible = false;
                              _runtimeRoles = {};
                            }
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Redoslijed prikaza',
                    suffixIcon: IconButton(
                      tooltip: 'Objašnjenje',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showInfo(
                        'Redoslijed prikaza',
                        'Manji broj = više na listi. Koristi se u administraciji i hubu stanica.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivna stanica'),
                  subtitle: const Text('Neaktivna stanica nije dostupna operaterima.'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                if (_profileIsComplete) ...[
                  const Divider(height: 32),
                  _labelWithInfo(
                    label: 'Vidljivo operaterima',
                    infoTitle: 'Vidljivo operaterima',
                    infoBody:
                        'Kad je uključeno, stanica se pojavljuje operaterima s odabranom ulogom '
                        'u hubu operativnih stanica. Za klasične stanice 1–3 koristi se donja navigacija.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vidljivo operaterima'),
                    value: _runtimeVisible,
                    onChanged: _isLegacyLocked
                        ? null
                        : (v) => setState(() {
                              _runtimeVisible = v;
                              if (!v) _runtimeRoles = {};
                            }),
                  ),
                  if (_runtimeVisible && !_isLegacyLocked) ...[
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
                  if (_runtimeVisible && _isLegacyLocked) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Uloge: ${widget.existing!.runtimeAllowedRoles.map(ProductionStationConfig.runtimeRoleLabel).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
                const Divider(height: 32),
                Text(
                  'Opcije prikaza',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Brzi unos kao zadano'),
                  subtitle: const Text(
                    'Operater na stanici prvo vidi brzi unos umjesto ručnog.',
                  ),
                  value: _quickEntryDefault,
                  onChanged: (v) => setState(() => _quickEntryDefault = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tema gumba',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: List.generate(
                    ProductionStationDisplayOptions.accentThemeLabels.length,
                    (i) => ButtonSegment(
                      value: i,
                      label: Text(
                        ProductionStationDisplayOptions.accentThemeLabels[i],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  selected: {_accentIndex},
                  onSelectionChanged: (s) =>
                      setState(() => _accentIndex = s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Akcije pakovanja (Stanica 1)'),
                  subtitle: const Text(
                    'Prikaz zatvaranja kutije i povezanih akcija gdje je primjenjivo.',
                  ),
                  value: _showPackingActions,
                  onChanged: (v) => setState(() => _showPackingActions = v),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Spremi stanicu'),
                ),
              ],
            ),
    );
  }
}
