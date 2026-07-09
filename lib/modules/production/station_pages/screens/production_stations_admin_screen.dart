import 'package:flutter/material.dart';
import 'package:production_app/core/company_plant_display_name.dart';

import '../../../logistics/inventory/services/product_warehouse_stock_service.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../models/production_station_config.dart';
import '../services/production_station_config_callable_service.dart';

/// Admin / menadžer: konfiguracija stanica proizvodnje po kompaniji (M1).
class ProductionStationsAdminScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionStationsAdminScreen({super.key, required this.companyData});

  @override
  State<ProductionStationsAdminScreen> createState() =>
      _ProductionStationsAdminScreenState();
}

class _ProductionStationsAdminScreenState
    extends State<ProductionStationsAdminScreen> {
  final _callable = ProductionStationConfigCallableService();

  bool _loading = true;
  String? _error;
  List<ProductionStationConfig> _configs = const [];
  ProductionStationLimitsSummary _limits = const ProductionStationLimitsSummary(
    maxProductionStations: 3,
    maxMachineStations: 0,
    activeProductionStations: 0,
    activeMachineStations: 0,
  );

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji u profilu.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _callable.listProductionStationConfigs(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() {
        _configs = result.configs;
        _limits = result.limits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int _nextStationSlot() {
    if (_configs.isEmpty) return 1;
    return _configs
            .map((c) => c.stationSlot)
            .fold<int>(0, (a, b) => a > b ? a : b) +
        1;
  }

  Future<void> _openAddChooser() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Dodaj stanicu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.precision_manufacturing_outlined),
                title: const Text('Proizvodna stanica'),
                subtitle: Text(
                  '${_limits.activeProductionStations} / ${_limits.maxProductionStations}',
                ),
                enabled: _limits.canAddProductionStation(),
                onTap: _limits.canAddProductionStation()
                    ? () => Navigator.pop(ctx, ProductionStationConfig.stationTypeProduction)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: const Text('Mašinska stanica'),
                subtitle: Text(
                  '${_limits.activeMachineStations} / ${_limits.maxMachineStations}',
                ),
                enabled: _limits.canAddMachineStation(),
                onTap: _limits.canAddMachineStation()
                    ? () => Navigator.pop(ctx, ProductionStationConfig.stationTypeMachine)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
          ],
        );
      },
    );
    if (type == null || !mounted) return;
    if (type == ProductionStationConfig.stationTypeProduction &&
        !_limits.canAddProductionStation()) {
      _showLimitSnack(true);
      return;
    }
    if (type == ProductionStationConfig.stationTypeMachine &&
        !_limits.canAddMachineStation()) {
      _showLimitSnack(false);
      return;
    }
    await _openEditor(
      stationType: type,
      stationSlot: _nextStationSlot(),
    );
  }

  void _showLimitSnack(bool production) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          production
              ? 'Dostigli ste maksimalan broj proizvodnih stanica za vaš paket. '
                  'Za povećanje limita kontaktirajte administratora platforme.'
              : 'Dostigli ste maksimalan broj mašinskih stanica za vaš paket. '
                  'Za dodatne mašinske stanice potrebno je proširenje paketa.',
        ),
      ),
    );
  }

  Future<void> _openEditor({
    ProductionStationConfig? existing,
    String? stationType,
    int? stationSlot,
  }) async {
    final slot = existing?.stationSlot ?? stationSlot ?? _nextStationSlot();
    final st = existing?.stationType ??
        stationType ??
        ProductionStationConfig.stationTypeProduction;

    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final codeCtrl = TextEditingController(text: existing?.stationCode ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    var active = existing?.active ?? true;
    var selectedType = st;
    var selectedProfile =
        existing?.processProfileType ?? 'standard_production';
    var selectedPhaseKey =
        existing?.productionPhaseKey ?? 'pakovanje';
    var selectedPhase =
        existing?.phase ?? ProductionOperatorTrackingEntry.phasePreparation;
    String? assignedPlantKey = existing?.assignedPlantKey;
    if (assignedPlantKey == null || assignedPlantKey.isEmpty) {
      assignedPlantKey =
          (widget.companyData['plantKey'] ?? '').toString().trim();
    }

    var requiresWorkOrder = existing?.requiresWorkOrder ?? true;
    var requiresProduct = existing?.requiresProduct ?? true;
    var requiresQuantityOutput = existing?.requiresQuantityOutput ?? true;
    var requiresMaterialConsumption =
        existing?.requiresMaterialConsumption ?? false;
    var requiresQualityCheck = existing?.requiresQualityCheck ?? false;
    var requiresOperatorLogin = existing?.requiresOperatorLogin ?? true;
    var packingFlowEnabled = existing?.packingFlowEnabled ?? false;
    int? legacyNavSlot = existing?.legacyOperatorNavSlot;

    String? inboundWhId = existing?.inboundWarehouseId;
    String? outboundWhId = existing?.outboundWarehouseId;

    final plants = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (assignedPlantKey.isEmpty && plants.isNotEmpty) {
      assignedPlantKey = plants.first.plantKey;
    }

    List<WarehouseRef> warehouses = const [];
    if (assignedPlantKey != null && assignedPlantKey.isNotEmpty) {
      try {
        warehouses = await ProductWarehouseStockService().listActiveWarehouses(
          companyId: _companyId,
          plantKey: assignedPlantKey,
        );
      } catch (_) {}
    }

    if (!mounted) {
      _scheduleControllerDispose([nameCtrl, codeCtrl, descCtrl, notesCtrl]);
      return;
    }

    final result = await showDialog<_StationEditorResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> reloadWarehouses(String pk) async {
              try {
                final list =
                    await ProductWarehouseStockService().listActiveWarehouses(
                  companyId: _companyId,
                  plantKey: pk,
                );
                setLocal(() {
                  warehouses = list;
                  inboundWhId = null;
                  outboundWhId = null;
                });
              } catch (_) {
                setLocal(() => warehouses = const []);
              }
            }

            final isMachine =
                selectedType == ProductionStationConfig.stationTypeMachine;

            return AlertDialog(
              title: Text(existing == null ? 'Nova stanica' : 'Uredi stanicu'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Slot: $slot', style: Theme.of(ctx).textTheme.labelLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Naziv stanice',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Šifra stanice',
                          hintText: 'npr. STATION_01',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedType),
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Tip stanice'),
                        items: ProductionStationConfig.stationTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(ProductionStationConfig.stationTypeLabel(t)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            selectedType = v;
                            if (v == ProductionStationConfig.stationTypeMachine) {
                              selectedProfile = 'standard_production';
                            }
                          });
                        },
                      ),
                      if (!isMachine) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedProfile),
                          initialValue: selectedProfile,
                          decoration: const InputDecoration(
                            labelText: 'Profil procesa',
                          ),
                          items: ProductionStationConfig.productionProfiles
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    ProductionStationConfig.processProfileLabel(p),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => selectedProfile = v);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(assignedPlantKey),
                        initialValue: assignedPlantKey,
                        decoration: const InputDecoration(labelText: 'Pogon'),
                        items: plants
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.plantKey,
                                child: Text(p.label),
                              ),
                            )
                            .toList(),
                        onChanged: plants.isEmpty
                            ? null
                            : (v) async {
                                if (v == null) return;
                                setLocal(() => assignedPlantKey = v);
                                await reloadWarehouses(v);
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedPhaseKey),
                        initialValue: ProductionStationConfig.productionPhaseKeys
                                .contains(selectedPhaseKey)
                            ? selectedPhaseKey
                            : ProductionStationConfig.productionPhaseKeys.first,
                        decoration: const InputDecoration(
                          labelText: 'Faza proizvodnje',
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
                          if (v != null) setLocal(() => selectedPhaseKey = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedPhase),
                        initialValue: selectedPhase,
                        decoration: const InputDecoration(
                          labelText: 'Operativna faza (legacy navigacija)',
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
                        onChanged: (v) {
                          if (v != null) setLocal(() => selectedPhase = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktivna'),
                        value: active,
                        onChanged: (v) => setLocal(() => active = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tok pakovanja (Stanica 1 / kutije)'),
                        value: packingFlowEnabled,
                        onChanged: (v) => setLocal(() => packingFlowEnabled = v),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Ponašanje (M2 operator unos)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Zahtijeva radni nalog'),
                        value: requiresWorkOrder,
                        onChanged: (v) => setLocal(() => requiresWorkOrder = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Zahtijeva proizvod'),
                        value: requiresProduct,
                        onChanged: (v) => setLocal(() => requiresProduct = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Evidentira količinu'),
                        value: requiresQuantityOutput,
                        onChanged: (v) =>
                            setLocal(() => requiresQuantityOutput = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Evidentira materijal / hemikalije'),
                        value: requiresMaterialConsumption,
                        onChanged: (v) =>
                            setLocal(() => requiresMaterialConsumption = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Zahtijeva kontrolu kvaliteta'),
                        value: requiresQualityCheck,
                        onChanged: (v) => setLocal(() => requiresQualityCheck = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Zahtijeva prijavu operatera'),
                        value: requiresOperatorLogin,
                        onChanged: (v) =>
                            setLocal(() => requiresOperatorLogin = v),
                      ),
                      const Divider(height: 24),
                      DropdownButtonFormField<int?>(
                        key: ValueKey(legacyNavSlot),
                        initialValue: legacyNavSlot,
                        decoration: const InputDecoration(
                          labelText: 'Legacy navigacija (Stanica 1/2/3)',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('— nije vezano —')),
                          DropdownMenuItem(value: 1, child: Text('Stanica 1')),
                          DropdownMenuItem(value: 2, child: Text('Stanica 2')),
                          DropdownMenuItem(value: 3, child: Text('Stanica 3')),
                        ],
                        onChanged: (v) => setLocal(() => legacyNavSlot = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('in_$inboundWhId'),
                        initialValue: inboundWhId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ulazni magacin',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— nije postavljeno —'),
                          ),
                          ...warehouses.map(
                            (w) => DropdownMenuItem<String?>(
                              value: w.id,
                              child: Text('${w.name} (${w.code})'),
                            ),
                          ),
                        ],
                        onChanged: warehouses.isEmpty
                            ? null
                            : (v) => setLocal(() => inboundWhId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('out_$outboundWhId'),
                        initialValue: outboundWhId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Izlazni magacin',
                          helperText:
                              'Obavezno za prijem kutija (Stanica 1) u logistici.',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— nije postavljeno —'),
                          ),
                          ...warehouses.map(
                            (w) => DropdownMenuItem<String?>(
                              value: w.id,
                              child: Text('${w.name} (${w.code})'),
                            ),
                          ),
                        ],
                        onChanged: warehouses.isEmpty
                            ? null
                            : (v) => setLocal(() => outboundWhId = v),
                      ),
                      if (isMachine) ...[
                        const Divider(height: 24),
                        Text(
                          'Mašinska integracija (M3 — samo konfiguracija)',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'IoT očitanja nisu aktivna u M1. Polja su priprema za kasniju fazu.',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Opis'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Napomena'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () {
                    if (assignedPlantKey == null || assignedPlantKey!.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Odaberite pogon.')),
                      );
                      return;
                    }
                    Navigator.pop(
                      ctx,
                      _StationEditorResult(
                        displayName: nameCtrl.text.trim(),
                        stationCode: codeCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                        active: active,
                        selectedType: selectedType,
                        selectedProfile: selectedProfile,
                        assignedPlantKey: assignedPlantKey!.trim(),
                        selectedPhaseKey: selectedPhaseKey,
                        selectedPhase: selectedPhase,
                        requiresOperatorLogin: requiresOperatorLogin,
                        requiresWorkOrder: requiresWorkOrder,
                        requiresProduct: requiresProduct,
                        requiresQuantityOutput: requiresQuantityOutput,
                        requiresMaterialConsumption: requiresMaterialConsumption,
                        requiresQualityCheck: requiresQualityCheck,
                        packingFlowEnabled: packingFlowEnabled,
                        legacyNavSlot: legacyNavSlot,
                        inboundWhId: inboundWhId,
                        outboundWhId: outboundWhId,
                      ),
                    );
                  },
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );

    _scheduleControllerDispose([nameCtrl, codeCtrl, descCtrl, notesCtrl]);

    if (result == null || !mounted) return;

    final config = ProductionStationConfig(
      id: ProductionStationConfig.buildConfigId(
        companyId: _companyId,
        stationSlot: slot,
      ),
      companyId: _companyId,
      stationSlot: slot,
      stationCode:
          result.stationCode.isEmpty ? null : result.stationCode,
      displayName:
          result.displayName.isEmpty ? null : result.displayName,
      order: slot,
      active: result.active,
      description:
          result.description.isEmpty ? null : result.description,
      notes: result.notes.isEmpty ? null : result.notes,
      stationType: result.selectedType,
      processProfileType:
          result.selectedType == ProductionStationConfig.stationTypeMachine
          ? 'standard_production'
          : result.selectedProfile,
      assignedPlantKey: result.assignedPlantKey,
      productionPhaseKey: result.selectedPhaseKey,
      phase: result.selectedPhase,
      requiresOperatorLogin: result.requiresOperatorLogin,
      requiresWorkOrder: result.requiresWorkOrder,
      requiresProduct: result.requiresProduct,
      requiresQuantityOutput: result.requiresQuantityOutput,
      requiresMaterialConsumption: result.requiresMaterialConsumption,
      requiresQualityCheck: result.requiresQualityCheck,
      supportsManualProductionInput: true,
      supportsMachineCounters:
          result.selectedType == ProductionStationConfig.stationTypeMachine,
      machineIntegration: const ProductionStationMachineIntegration(),
      packingFlowEnabled: result.packingFlowEnabled,
      inboundWarehouseId: result.inboundWhId,
      outboundWarehouseId: result.outboundWhId,
      legacyOperatorNavSlot: result.legacyNavSlot,
    );

    try {
      await _callable.upsertProductionStationConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stanica je spremljena.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productionStationLimitMessage(e))),
      );
    }
  }

  void _scheduleControllerDispose(List<TextEditingController> controllers) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  static String _phaseLabel(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return phase;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stanice proizvodnje'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osvježi',
          ),
          IconButton(
            onPressed: _loading ? null : _openAddChooser,
            icon: const Icon(Icons.add),
            tooltip: 'Dodaj stanicu',
          ),
        ],
      ),
      body: _companyId.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nedostaje podatak o kompaniji — stanice nisu dostupne.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _LimitsSummaryCard(limits: _limits),
                          const SizedBox(height: 16),
                          if (_configs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nema definiranih stanica. Dodajte prvu stanicu ili pokrenite migraciju iz legacy konfiguracije.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ..._configs.map((c) => _StationCard(
                                  config: c,
                                  companyId: _companyId,
                                  onTap: () => _openEditor(existing: c),
                                )),
                        ],
                      ),
                    ),
    );
  }
}

class _StationEditorResult {
  final String displayName;
  final String stationCode;
  final String description;
  final String notes;
  final bool active;
  final String selectedType;
  final String selectedProfile;
  final String assignedPlantKey;
  final String selectedPhaseKey;
  final String selectedPhase;
  final bool requiresOperatorLogin;
  final bool requiresWorkOrder;
  final bool requiresProduct;
  final bool requiresQuantityOutput;
  final bool requiresMaterialConsumption;
  final bool requiresQualityCheck;
  final bool packingFlowEnabled;
  final int? legacyNavSlot;
  final String? inboundWhId;
  final String? outboundWhId;

  const _StationEditorResult({
    required this.displayName,
    required this.stationCode,
    required this.description,
    required this.notes,
    required this.active,
    required this.selectedType,
    required this.selectedProfile,
    required this.assignedPlantKey,
    required this.selectedPhaseKey,
    required this.selectedPhase,
    required this.requiresOperatorLogin,
    required this.requiresWorkOrder,
    required this.requiresProduct,
    required this.requiresQuantityOutput,
    required this.requiresMaterialConsumption,
    required this.requiresQualityCheck,
    required this.packingFlowEnabled,
    required this.legacyNavSlot,
    required this.inboundWhId,
    required this.outboundWhId,
  });
}

class _LimitsSummaryCard extends StatelessWidget {
  final ProductionStationLimitsSummary limits;

  const _LimitsSummaryCard({required this.limits});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Iskorištenje paketa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Proizvodne stanice: ${limits.activeProductionStations} / ${limits.maxProductionStations}',
            ),
            Text(
              'Mašinske stanice: ${limits.activeMachineStations} / ${limits.maxMachineStations}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final ProductionStationConfig config;
  final String companyId;
  final VoidCallback onTap;

  const _StationCard({
    required this.config,
    required this.companyId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      config.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(
                      config.active ? 'Aktivna' : 'Neaktivna',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ProductionStationConfig.stationTypeLabel(config.stationType),
              ),
              if (config.productionPhaseKey != null)
                Text(
                  'Faza: ${ProductionStationConfig.productionPhaseLabel(config.productionPhaseKey!)}',
                ),
              Text(
                'Profil: ${ProductionStationConfig.processProfileLabel(config.processProfileType)}',
              ),
              Text(
                'Operativna faza: ${_ProductionStationsAdminScreenState._phaseLabel(config.phase)}',
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: CompanyPlantDisplayName.resolve(
                  companyId: companyId,
                  plantKey: config.assignedPlantKey,
                ),
                builder: (context, snap) {
                  final label = snap.data ?? '…';
                  return Text('Pogon: $label');
                },
              ),
              if (config.packingFlowEnabled)
                const Text('Tok pakovanja: uključen'),
              if (config.legacyOperatorNavSlot != null)
                Text('Navigacija: Stanica ${config.legacyOperatorNavSlot}'),
            ],
          ),
        ),
      ),
    );
  }
}
