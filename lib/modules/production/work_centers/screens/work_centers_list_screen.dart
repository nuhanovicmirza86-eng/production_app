import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/visual/operonix_collapsible_section.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/operonix_premium_icon.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import '../models/work_center_model.dart';
import '../services/work_center_service.dart';
import '../widgets/work_center_help.dart';
import 'work_center_create_screen.dart';
import 'work_center_details_screen.dart';

class WorkCentersListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// When set, skips the plant lookup and uses this allowed-source list.
  /// Production leaves it null and loads plants the existing way.
  final List<({String plantKey, String label})>? plantOptions;

  const WorkCentersListScreen({
    super.key,
    required this.companyData,
    this.plantOptions,
  });

  @override
  State<WorkCentersListScreen> createState() => _WorkCentersListScreenState();
}

class _WorkCentersListScreenState extends State<WorkCentersListScreen> {
  late final WorkCenterService _service = WorkCenterService();

  bool _filtersExpanded = false;

  String? _filterStatus;
  String? _filterType;
  String? _filterOee;
  String? _filterActive;

  late String _selectedPlantKey;
  List<({String plantKey, String label})> _plants = const [];
  bool _listLoading = true;
  String? _listError;
  List<WorkCenter> _items = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _isPlantScopedList {
    return _role == ProductionAccessHelper.roleProductionManager ||
        _role == ProductionAccessHelper.roleShiftLead;
  }

  bool get _canSwitchPlant {
    if (_isPlantScopedList) return false;
    if (ProductionAccessHelper.isCompanyWideContextRole(_role) ||
        ProductionAccessHelper.isAdminRole(_role) ||
        ProductionAccessHelper.isSuperAdminRole(_role)) {
      return true;
    }
    return _sessionPlantKey.isEmpty;
  }

  bool get _canManage => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.workCenters,
  );

  bool get _canViewList => ProductionAccessHelper.canView(
    role: _role,
    card: ProductionDashboardCard.workCenters,
  );

  @override
  void initState() {
    super.initState();
    _selectedPlantKey = _sessionPlantKey;
    final preset = widget.plantOptions;
    if (preset != null) {
      _applyAllowedSelection(_allowedPlants(preset));
      _reloadList();
    } else {
      _loadPlants();
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkCenterCreateScreen(
          companyData: widget.companyData,
          initialPlantKey: _selectedPlantKey,
        ),
      ),
    );
    await _reloadList();
  }

  Future<void> _loadPlants() async {
    if (_companyId.isEmpty) return;
    List<({String plantKey, String label})> list;
    try {
      list = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listLoading = false;
        _listError = AppErrorMapper.toMessage(e);
        _items = const [];
      });
      return;
    }
    if (!mounted) return;
    setState(() => _applyAllowedSelection(_allowedPlants(list)));
    await _reloadList();
  }

  List<({String plantKey, String label})> _allowedPlants(
    List<({String plantKey, String label})> list,
  ) {
    if (!_canSwitchPlant && _sessionPlantKey.isNotEmpty) {
      final allowed = list
          .where((p) => p.plantKey == _sessionPlantKey)
          .toList();
      if (allowed.isEmpty) {
        return [(plantKey: _sessionPlantKey, label: _sessionPlantKey)];
      }
      return allowed;
    }
    return list;
  }

  void _applyAllowedSelection(List<({String plantKey, String label})> allowed) {
    _plants = allowed;
    if (!_canSwitchPlant && _sessionPlantKey.isNotEmpty) {
      _selectedPlantKey = _sessionPlantKey;
    } else if (_selectedPlantKey.isEmpty && allowed.isNotEmpty) {
      _selectedPlantKey = allowed.first.plantKey;
    } else if (allowed.isNotEmpty &&
        !allowed.any((p) => p.plantKey == _selectedPlantKey)) {
      _selectedPlantKey = allowed.first.plantKey;
    }
  }

  Future<void> _pickPlant() async {
    if (_plants.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final tokens = OperonixVisualTokens.of(ctx);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final plant in _plants)
                ListTile(
                  selected:
                      tokens.isPremium && plant.plantKey == _selectedPlantKey,
                  selectedTileColor: tokens.isPremium
                      ? tokens.surfaceInteractive
                      : null,
                  title: Text(
                    plant.label,
                    style: tokens.isPremium
                        ? TextStyle(color: tokens.primaryText)
                        : null,
                  ),
                  trailing:
                      tokens.isPremium && plant.plantKey == _selectedPlantKey
                      ? Icon(Icons.check_rounded, color: tokens.primaryAccent)
                      : null,
                  onTap: () => Navigator.pop(ctx, plant.plantKey),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || chosen == null || chosen == _selectedPlantKey) return;
    setState(() => _selectedPlantKey = chosen);
    await _reloadList();
  }

  Future<void> _reloadList() async {
    if (_companyId.isEmpty || _selectedPlantKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _listLoading = false;
        _listError = null;
        _items = const [];
      });
      return;
    }
    if (!_canViewList) {
      if (!mounted) return;
      setState(() {
        _listLoading = false;
        _listError =
            'Nemate pristup radnim centrima za ovu ulogu ili pogon. '
            'Provjerite dodijeljenu ulogu i pogon.';
        _items = const [];
      });
      return;
    }
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final list = await _service.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: _selectedPlantKey,
        onlyActive: false,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _listLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listLoading = false;
        _listError = _canViewList
            ? AppErrorMapper.toMessage(e)
            : 'Nemate pristup radnim centrima za ovu ulogu ili pogon. '
                'Provjerite dodijeljenu ulogu i pogon.';
        _items = const [];
      });
    }
  }

  String _plantLabel(String key) {
    for (final p in _plants) {
      if (p.plantKey == key) return p.label;
    }
    return key.isEmpty ? '—' : key;
  }

  Iterable<WorkCenter> _applyFilters(List<WorkCenter> items) sync* {
    for (final wc in items) {
      if (_filterStatus != null && wc.status != _filterStatus) continue;
      if (_filterType != null && wc.type != _filterType) continue;
      if (_filterOee == 'yes' && !wc.isOeeRelevant) continue;
      if (_filterOee == 'no' && wc.isOeeRelevant) continue;
      if (_filterActive == 'active' && !wc.active) continue;
      if (_filterActive == 'inactive' && wc.active) continue;
      yield wc;
    }
  }

  String _fmtCapacity(WorkCenter wc) {
    if (wc.capacityPerHour <= 0) return '—';
    final v = wc.capacityPerHour;
    final t = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1).replaceAll('.', ',');
    return '$t kom/h';
  }

  String _fmtCycle(WorkCenter wc) {
    if (wc.standardCycleTimeSec <= 0) return '—';
    final v = wc.standardCycleTimeSec;
    final t = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1).replaceAll('.', ',');
    return '$t s';
  }

  Widget _filterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _filterStatus,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Status',
            suffixIcon: WorkCenterInfoIcon(
              title: WorkCenterHelpTexts.statusTitle,
              message: WorkCenterHelpTexts.statusBody,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Svi')),
            ...WorkCenter.selectableStatuses.map(
              (e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _filterStatus = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _filterType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Tip radnog centra',
            suffixIcon: WorkCenterInfoIcon(
              title: WorkCenterHelpTexts.typeTitle,
              message: WorkCenterHelpTexts.typeBody,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Svi')),
            ...WorkCenter.selectableTypes.map(
              (e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _filterType = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _filterOee,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'OEE relevantan',
            suffixIcon: WorkCenterInfoIcon(
              title: WorkCenterHelpTexts.oeeFlagTitle,
              message: WorkCenterHelpTexts.oeeFlagBody,
            ),
          ),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('Svi')),
            DropdownMenuItem<String?>(value: 'yes', child: Text('Da')),
            DropdownMenuItem<String?>(value: 'no', child: Text('Ne')),
          ],
          onChanged: (v) => setState(() => _filterOee = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _filterActive,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Aktivno u šifrarniku',
            suffixIcon: WorkCenterInfoIcon(
              title: WorkCenterHelpTexts.activeTitle,
              message: WorkCenterHelpTexts.activeBody,
            ),
          ),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('Svi')),
            DropdownMenuItem<String?>(value: 'active', child: Text('Aktivni')),
            DropdownMenuItem<String?>(
              value: 'inactive',
              child: Text('Neaktivni'),
            ),
          ],
          onChanged: (v) => setState(() => _filterActive = v),
        ),
      ],
    );
  }

  Widget _buildPremiumScaffold() {
    final tokens = OperonixVisualTokens.of(context);
    final filtered = _applyFilters(_items).toList();
    final emptyCopy = _items.isEmpty
        ? 'Nema radnih centara na ovom pogonu. ${_canManage ? 'Dodajte prvi zapis.' : ''}'
        : 'Nema zapisa za trenutne filtere.';
    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Radni centri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: WorkCenterHelpTexts.overviewTitle,
            onPressed: () => showWorkCenterHelpDialog(
              context,
              title: WorkCenterHelpTexts.overviewTitle,
              message: WorkCenterHelpTexts.overviewBody,
            ),
          ),
          if (_canManage)
            IconButton(
              tooltip: 'Dodaj radni centar',
              onPressed: _openCreate,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PremiumContextCard(
            leading: const PremiumIconBadge(
              icon: Icons.factory_outlined,
              glyph: OperonixPremiumGlyph.plant,
              role: PremiumIconRole.info,
              size: 36,
            ),
            label: 'Pogon',
            value: _plantLabel(_selectedPlantKey),
            trailing: _plants.isEmpty
                ? null
                : Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: tokens.secondaryText,
                  ),
            onTap: _plants.isEmpty ? null : _pickPlant,
          ),
          const SizedBox(height: 10),
          OperonixCollapsibleSection(
            title: 'Filteri',
            summary: 'Status, tip, OEE, aktivno',
            expanded: _filtersExpanded,
            glyph: OperonixPremiumGlyph.entryDate,
            role: PremiumIconRole.info,
            onToggle: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            child: _filterControls(),
          ),
          const SizedBox(height: 12),
          if (_listLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_listError != null)
            PremiumEmptyState(
              icon: Icons.error_outline,
              glyph: OperonixPremiumGlyph.workCenter,
              role: PremiumIconRole.warning,
              title: _listError!,
            )
          else if (filtered.isEmpty)
            PremiumEmptyState(
              icon: Icons.precision_manufacturing_outlined,
              glyph: OperonixPremiumGlyph.workCenter,
              role: PremiumIconRole.active,
              title: emptyCopy,
            )
          else
            for (final wc in filtered) _workCenterCard(wc),
        ],
      ),
    );
  }

  Widget _workCenterCard(WorkCenter wc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumListCard(
        icon: Icons.precision_manufacturing_outlined,
        glyph: OperonixPremiumGlyph.workCenter,
        role: PremiumIconRole.active,
        title: '${wc.workCenterCode} | ${wc.name}',
        subtitle:
            '${WorkCenter.labelForType(wc.type)} · ${WorkCenter.labelForStatus(wc.status)} · ${_fmtCapacity(wc)}',
        onTap: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => WorkCenterDetailsScreen(
                companyData: widget.companyData,
                workCenterId: wc.id,
                plantKey: _selectedPlantKey,
              ),
            ),
          );
          await _reloadList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _selectedPlantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Radni centri')),
        body: const Center(
          child: Text(
            'Nedostaje kontekst kompanije ili pogona. Ponovo se prijavite.',
          ),
        ),
      );
    }

    if (OperonixVisualTokens.of(context).isPremium) {
      return _buildPremiumScaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radni centri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: WorkCenterHelpTexts.overviewTitle,
            onPressed: () => showWorkCenterHelpDialog(
              context,
              title: WorkCenterHelpTexts.overviewTitle,
              message: WorkCenterHelpTexts.overviewBody,
            ),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_plants.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPlantKey,
                    decoration: InputDecoration(
                      labelText: 'Pogon (filter)',
                      suffixIcon: WorkCenterInfoIcon(
                        title: WorkCenterHelpTexts.plantTitle,
                        message: WorkCenterHelpTexts.plantBody,
                      ),
                    ),
                    items: _plants
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.plantKey,
                            child: Text(p.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedPlantKey = v);
                      _reloadList();
                    },
                  ),
                  const SizedBox(height: 10),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Pogon: ${_plantLabel(_selectedPlantKey)}',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      WorkCenterInfoIcon(
                        title: WorkCenterHelpTexts.plantTitle,
                        message: WorkCenterHelpTexts.plantBody,
                      ),
                    ],
                  ),
                ExpansionTile(
                  title: Row(
                    children: [
                      const Expanded(child: Text('Filteri')),
                      WorkCenterInfoIcon(
                        title: WorkCenterHelpTexts.filtersTitle,
                        message: WorkCenterHelpTexts.filtersBody,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _filtersExpanded ? 'Sakrij' : 'Status, tip, OEE, aktivno',
                  ),
                  initiallyExpanded: _filtersExpanded,
                  onExpansionChanged: (x) =>
                      setState(() => _filtersExpanded = x),
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _filterStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        suffixIcon: WorkCenterInfoIcon(
                          title: WorkCenterHelpTexts.statusTitle,
                          message: WorkCenterHelpTexts.statusBody,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        ...WorkCenter.selectableStatuses.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _filterType,
                      decoration: InputDecoration(
                        labelText: 'Tip radnog centra',
                        suffixIcon: WorkCenterInfoIcon(
                          title: WorkCenterHelpTexts.typeTitle,
                          message: WorkCenterHelpTexts.typeBody,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        ...WorkCenter.selectableTypes.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterType = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _filterOee,
                      decoration: InputDecoration(
                        labelText: 'OEE relevantan',
                        suffixIcon: WorkCenterInfoIcon(
                          title: WorkCenterHelpTexts.oeeFlagTitle,
                          message: WorkCenterHelpTexts.oeeFlagBody,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'yes',
                          child: Text('Da'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'no',
                          child: Text('Ne'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterOee = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _filterActive,
                      decoration: InputDecoration(
                        labelText: 'Aktivno u šifrarniku',
                        suffixIcon: WorkCenterInfoIcon(
                          title: WorkCenterHelpTexts.activeTitle,
                          message: WorkCenterHelpTexts.activeBody,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'active',
                          child: Text('Aktivni'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'inactive',
                          child: Text('Neaktivni'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterActive = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reloadList,
              child: _listLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _listError != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 48),
                        Text(
                          _listError!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Builder(
                      builder: (context) {
                        final filtered = _applyFilters(_items).toList();
                        if (filtered.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 48),
                              Text(
                                _items.isEmpty
                                    ? 'Nema radnih centara na ovom pogonu. ${_canManage ? 'Dodajte prvi zapis.' : ''}'
                                    : 'Nema zapisa za trenutne filtere.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final wc = filtered[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => WorkCenterDetailsScreen(
                                        companyData: widget.companyData,
                                        workCenterId: wc.id,
                                        plantKey: _selectedPlantKey,
                                      ),
                                    ),
                                  );
                                  await _reloadList();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${wc.workCenterCode} | ${wc.name}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (!wc.active)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      left: 6,
                                                    ),
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors
                                                          .grey
                                                          .shade300,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Neaktivan',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          WorkCenterInfoIcon(
                                            title:
                                                WorkCenterHelpTexts.listCardTitle,
                                            message:
                                                WorkCenterHelpTexts.listCardBody,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tip: ${WorkCenter.labelForType(wc.type)}',
                                      ),
                                      Text(
                                        'Status: ${WorkCenter.labelForStatus(wc.status)}',
                                      ),
                                      Text('Kapacitet: ${_fmtCapacity(wc)}'),
                                      Text('Ciklus: ${_fmtCycle(wc)}'),
                                      Text(
                                        'OEE: ${wc.isOeeRelevant ? 'Da' : 'Ne'}',
                                      ),
                                      Text(
                                        'Pogon: ${_plantLabel(wc.plantKey)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
