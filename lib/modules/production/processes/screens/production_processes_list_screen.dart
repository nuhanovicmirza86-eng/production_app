import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/production_process_model.dart';
import '../services/production_process_service.dart';
import 'production_process_create_screen.dart';
import 'production_process_details_screen.dart';
import 'production_process_edit_screen.dart';

class ProductionProcessesListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionProcessesListScreen({super.key, required this.companyData});

  @override
  State<ProductionProcessesListScreen> createState() =>
      _ProductionProcessesListScreenState();
}

class _ProductionProcessesListScreenState
    extends State<ProductionProcessesListScreen> {
  final ProductionProcessService _service = ProductionProcessService();

  bool _filtersExpanded = false;

  String? _filterType;
  String? _filterStatus;
  String? _filterIatf;
  String? _filterQc;
  String? _filterTrace;

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
    card: ProductionDashboardCard.productionProcesses,
  );

  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

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
      } else if (list.any((p) => p.plantKey == _selectedPlantKey)) {
        // keep
      } else if (list.isNotEmpty) {
        _selectedPlantKey = list.first.plantKey;
      }
    });
  }

  String _plantLabel(String plantKey) {
    for (final p in _plants) {
      if (p.plantKey == plantKey) return p.label;
    }
    return plantKey;
  }

  Iterable<ProductionProcess> _applyFilters(List<ProductionProcess> all) sync* {
    for (final p in all) {
      if (_filterType != null && p.processType != _filterType) continue;
      if (_filterStatus != null && p.status != _filterStatus) continue;
      if (_filterIatf == 'yes' && !p.iatfRelevant) continue;
      if (_filterIatf == 'no' && p.iatfRelevant) continue;
      if (_filterQc == 'yes' && !p.qualityControlRequired) continue;
      if (_filterQc == 'no' && p.qualityControlRequired) continue;
      if (_filterTrace == 'yes' && !p.traceabilityRequired) continue;
      if (_filterTrace == 'no' && p.traceabilityRequired) continue;
      yield p;
    }
  }

  Future<void> _setStatus(ProductionProcess p, String newStatus) async {
    if (!_canManage) return;
    try {
      await _service.setStatus(
        existing: p,
        newStatus: newStatus,
        updatedBy: _userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status: ${ProductionProcess.labelForStatus(newStatus)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _confirmArchive(ProductionProcess p) async {
    if (!_canManage || p.isArchived) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arhivirati proces?'),
        content: Text(
          'Zapis ostaje radi historije (${p.processCode}). Neće se moći uređivati.',
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
    if (ok == true) await _setStatus(p, ProductionProcess.statusArchived);
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _selectedPlantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Procesi')),
        body: const Center(
          child: Text(
            'Nedostaje kontekst kompanije ili pogona. Ponovo se prijavite.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Procesi (master-data)')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProductionProcessCreateScreen(
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
                    decoration: const InputDecoration(
                      labelText: 'Pogon (filter)',
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
                  Text(
                    'Pogon: ${_plantLabel(_selectedPlantKey)}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ExpansionTile(
                  title: const Text('Filteri'),
                  subtitle: Text(
                    _filtersExpanded
                        ? 'Sakrij'
                        : 'Tip, status, IATF, QC, sljedljivost',
                  ),
                  initiallyExpanded: _filtersExpanded,
                  onExpansionChanged: (x) =>
                      setState(() => _filtersExpanded = x),
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _filterType,
                      decoration: const InputDecoration(
                        labelText: 'Tip procesa',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        ...ProductionProcess.selectableTypes.map(
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
                      initialValue: _filterStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        ...ProductionProcess.selectableStatuses.map(
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
                      initialValue: _filterIatf,
                      decoration: const InputDecoration(
                        labelText: 'IATF relevantan',
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
                      onChanged: (v) => setState(() => _filterIatf = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _filterQc,
                      decoration: const InputDecoration(
                        labelText: 'QC obavezan',
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
                      onChanged: (v) => setState(() => _filterQc = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _filterTrace,
                      decoration: const InputDecoration(
                        labelText: 'Sljedljivost obavezna',
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
                      onChanged: (v) => setState(() => _filterTrace = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ProductionProcess>>(
              stream: _service.watchProcesses(
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
                          ? 'Nema procesa na ovom pogonu. ${_canManage ? 'Dodajte prvi zapis.' : ''}'
                          : 'Nema zapisa za trenutne filtere.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ProductionProcessDetailsScreen(
                                companyData: widget.companyData,
                                processId: p.id,
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
                                    child: Text(
                                      p.processCode,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_canManage)
                                    PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'view') {
                                          await Navigator.push<void>(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ProductionProcessDetailsScreen(
                                                    companyData:
                                                        widget.companyData,
                                                    processId: p.id,
                                                    plantKey: _selectedPlantKey,
                                                  ),
                                            ),
                                          );
                                        } else if (v == 'edit' &&
                                            !p.isArchived) {
                                          final changed =
                                              await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute<bool>(
                                                  builder: (_) =>
                                                      ProductionProcessEditScreen(
                                                        companyData:
                                                            widget.companyData,
                                                        processId: p.id,
                                                        plantKey:
                                                            _selectedPlantKey,
                                                      ),
                                                ),
                                              );
                                          if (changed == true && mounted) {
                                            setState(() {});
                                          }
                                        } else if (v == 'activate') {
                                          await _setStatus(
                                            p,
                                            ProductionProcess.statusActive,
                                          );
                                        } else if (v == 'deactivate') {
                                          await _setStatus(
                                            p,
                                            ProductionProcess.statusInactive,
                                          );
                                        } else if (v == 'archive') {
                                          await _confirmArchive(p);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Text('Pregled'),
                                        ),
                                        if (!p.isArchived)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Uredi'),
                                          ),
                                        if (!p.isArchived &&
                                            p.status !=
                                                ProductionProcess.statusActive)
                                          const PopupMenuItem(
                                            value: 'activate',
                                            child: Text('Aktiviraj'),
                                          ),
                                        if (!p.isArchived &&
                                            p.status ==
                                                ProductionProcess.statusActive)
                                          const PopupMenuItem(
                                            value: 'deactivate',
                                            child: Text('Deaktiviraj'),
                                          ),
                                        if (!p.isArchived)
                                          const PopupMenuItem(
                                            value: 'archive',
                                            child: Text('Arhiviraj'),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tip: ${ProductionProcess.labelForType(p.processType)}',
                              ),
                              Text(
                                'Status: ${ProductionProcess.labelForStatus(p.status)}',
                              ),
                              Text('IATF: ${p.iatfRelevant ? 'Da' : 'Ne'}'),
                              Text(
                                'Traceability: ${p.traceabilityRequired ? 'Da' : 'Ne'}',
                              ),
                              Text(
                                'QC: ${p.qualityControlRequired ? 'Da' : 'Ne'}',
                              ),
                              Text(
                                'Radni centri: ${p.linkedWorkCenterIds.length}',
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
        ],
      ),
    );
  }
}
