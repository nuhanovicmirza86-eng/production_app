import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/work_center_model.dart';
import '../services/work_center_service.dart';
import '../widgets/work_center_help.dart';
import 'work_center_create_screen.dart';
import 'work_center_details_screen.dart';

class WorkCentersListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const WorkCentersListScreen({super.key, required this.companyData});

  @override
  State<WorkCentersListScreen> createState() => _WorkCentersListScreenState();
}

class _WorkCentersListScreenState extends State<WorkCentersListScreen> {
  final WorkCenterService _service = WorkCenterService();

  bool _filtersExpanded = false;

  String? _filterStatus;
  String? _filterType;
  String? _filterOee;
  String? _filterActive;

  late String _selectedPlantKey;
  List<({String plantKey, String label})> _plants = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.workCenters,
  );

  @override
  void initState() {
    super.initState();
    _selectedPlantKey = _sessionPlantKey;
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    if (_companyId.isEmpty) return;
    final list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() {
      _plants = list;
      if (_selectedPlantKey.isEmpty && list.isNotEmpty) {
        _selectedPlantKey = list.first.plantKey;
      } else if (list.isNotEmpty &&
          !list.any((p) => p.plantKey == _selectedPlantKey)) {
        _selectedPlantKey = list.first.plantKey;
      }
    });
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
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WorkCenterCreateScreen(
                      companyData: widget.companyData,
                      initialPlantKey: _selectedPlantKey,
                    ),
                  ),
                );
              },
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
            child: StreamBuilder<List<WorkCenter>>(
              stream: _service.watchWorkCenters(
                companyId: _companyId,
                plantKey: _selectedPlantKey,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppErrorMapper.toMessage(snap.error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _applyFilters(snap.data!).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      snap.data!.isEmpty
                          ? 'Nema radnih centara na ovom pogonu. ${_canManage ? 'Dodajte prvi zapis.' : ''}'
                          : 'Nema zapisa za trenutne filtere.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final wc = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => WorkCenterDetailsScreen(
                                companyData: widget.companyData,
                                workCenterId: wc.id,
                                plantKey: _selectedPlantKey,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${wc.workCenterCode} | ${wc.name}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (!wc.active)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Neaktivan',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  WorkCenterInfoIcon(
                                    title: WorkCenterHelpTexts.listCardTitle,
                                    message: WorkCenterHelpTexts.listCardBody,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Tip: ${WorkCenter.labelForType(wc.type)}'),
                              Text(
                                'Status: ${WorkCenter.labelForStatus(wc.status)}',
                              ),
                              Text('Kapacitet: ${_fmtCapacity(wc)}'),
                              Text('Ciklus: ${_fmtCycle(wc)}'),
                              Text('OEE: ${wc.isOeeRelevant ? 'Da' : 'Ne'}'),
                              Text('Pogon: ${_plantLabel(wc.plantKey)}'),
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
        ],
      ),
    );
  }
}
