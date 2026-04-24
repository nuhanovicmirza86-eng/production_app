import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import '../models/production_process_model.dart';
import '../services/production_process_service.dart';
import 'production_process_edit_screen.dart';

class ProductionProcessDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String processId;
  final String plantKey;

  const ProductionProcessDetailsScreen({
    super.key,
    required this.companyData,
    required this.processId,
    required this.plantKey,
  });

  @override
  State<ProductionProcessDetailsScreen> createState() =>
      _ProductionProcessDetailsScreenState();
}

class _ProductionProcessDetailsScreenState extends State<ProductionProcessDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ProductionProcessService _processService = ProductionProcessService();
  final WorkCenterService _workCenterService = WorkCenterService();

  late TabController _tabController;

  bool _loading = true;
  String? _error;
  ProductionProcess? _process;
  String _plantLabel = '';
  Map<String, String> _wcLabels = const {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

  bool get _canManage => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.productionProcesses,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pk = widget.plantKey.trim();
      final pl = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: pk,
      );
      final p = await _processService.getById(
        companyId: _companyId,
        plantKey: pk,
        processId: widget.processId.trim(),
      );

      final wcs = await _workCenterService.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: pk,
        onlyActive: false,
      );
      final labels = <String, String>{};
      for (final wc in wcs) {
        labels[wc.id] = '${wc.workCenterCode} — ${wc.name}';
      }

      if (!mounted) return;
      setState(() {
        _plantLabel = pl;
        _process = p;
        _wcLabels = labels;
        _loading = false;
        if (p == null) {
          _error = 'Proces nije pronađen ili nije u vašem kontekstu.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final day = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final y = d.year.toString();
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day.$m.$y $h:$min';
  }

  String _yesNo(bool v) => v ? 'Da' : 'Ne';

  Future<void> _setStatus(String newStatus) async {
    final p = _process;
    if (p == null || !_canManage) return;
    try {
      await _processService.setStatus(
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _confirmArchive() async {
    final p = _process;
    if (p == null || !_canManage || p.isArchived) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arhivirati proces?'),
        content: Text(
          'Zapis ostaje radi historije i sljedljivosti (${p.processCode}). '
          'Neće se moći uređivati.',
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
    if (ok == true) await _setStatus(ProductionProcess.statusArchived);
  }

  Widget _placeholderTab(String title, String body) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proces')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proces')),
        body: Center(child: Text(_error!)),
      );
    }

    final p = _process!;
    final wcLines = p.linkedWorkCenterIds
        .map((id) => _wcLabels[id] ?? id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.processCode),
        actions: [
          if (_canManage && !p.isArchived)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Uredi',
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProductionProcessEditScreen(
                      companyData: widget.companyData,
                      processId: p.id,
                      plantKey: widget.plantKey.trim(),
                    ),
                  ),
                );
                if (changed == true) await _load();
              },
            ),
          if (_canManage && !p.isArchived)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'activate') {
                  await _setStatus(ProductionProcess.statusActive);
                } else if (v == 'deactivate') {
                  await _setStatus(ProductionProcess.statusInactive);
                } else if (v == 'draft') {
                  await _setStatus(ProductionProcess.statusDraft);
                } else if (v == 'archive') {
                  await _confirmArchive();
                }
              },
              itemBuilder: (ctx) => [
                if (p.status != ProductionProcess.statusActive)
                  const PopupMenuItem(
                    value: 'activate',
                    child: Text('Aktiviraj'),
                  ),
                if (p.status == ProductionProcess.statusActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Deaktiviraj'),
                  ),
                if (p.status != ProductionProcess.statusDraft)
                  const PopupMenuItem(
                    value: 'draft',
                    child: Text('Vrati u nacrt'),
                  ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Arhiviraj'),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Osnovno'),
            Tab(text: 'IATF'),
            Tab(text: 'Radni centri'),
            Tab(text: 'Parametri'),
            Tab(text: 'Kontrolne tačke'),
            Tab(text: 'Dokumenti'),
            Tab(text: 'Historija'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('Pogon', _plantLabel),
              _detailRow('Tip', ProductionProcess.labelForType(p.processType)),
              _detailRow('Status', ProductionProcess.labelForStatus(p.status)),
              _detailRow('Aktivan u operativi', _yesNo(p.isActive)),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Opis',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(p.description),
              ],
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailRow('IATF relevantan', _yesNo(p.iatfRelevant)),
              _detailRow('Sljedljivost obavezna', _yesNo(p.traceabilityRequired)),
              _detailRow('QC zapis obavezan', _yesNo(p.qualityControlRequired)),
              const Divider(height: 24),
              _detailRow('Prvi komad', _yesNo(p.firstPieceApprovalRequired)),
              _detailRow('Procesni parametri', _yesNo(p.processParametersRequired)),
              _detailRow('Kvalifikacija operatera', _yesNo(p.operatorQualificationRequired)),
              _detailRow('Radna instrukcija', _yesNo(p.workInstructionRequired)),
              _detailRow('PFMEA', _yesNo(p.pfmeaRequired)),
              _detailRow('Control Plan', _yesNo(p.controlPlanRequired)),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p.linkedWorkCenterTypes.isEmpty)
                const Text('Nema ograničenja po tipu radnog centra.')
              else
                ...p.linkedWorkCenterTypes.map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${WorkCenter.labelForType(k)}'),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Dozvoljeni radni centri (${p.linkedWorkCenterIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (wcLines.isEmpty)
                const Text('Nije odabran nijedan radni centar.')
              else
                ...wcLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $line'),
                  ),
                ),
            ],
          ),
          _placeholderTab(
            'Parametri procesa',
            'Evidencija obaveznih tehnoloških parametara i tolerancija dolazi u sljedećoj verziji.',
          ),
          _placeholderTab(
            'Kontrolne tačke',
            'Definicija kontrolnih tačaka i quality gateova u izvršenju bit će povezana s Quality modulom.',
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailRow('PFMEA referenca', p.pfmeaReference.isEmpty ? '—' : p.pfmeaReference),
              _detailRow('Control Plan referenca', p.controlPlanReference.isEmpty ? '—' : p.controlPlanReference),
              _detailRow('Radna instrukcija referenca', p.workInstructionReference.isEmpty ? '—' : p.workInstructionReference),
              const SizedBox(height: 16),
              Text(
                'Dublje povezivanje (PFMEA, plan kontrole, SPC) razvija se u QMS ekranima.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailRow('Kreirano', _fmtDate(p.createdAt)),
              _detailRow('Kreirao', p.createdBy.isEmpty ? '—' : p.createdBy),
              const Divider(height: 24),
              _detailRow('Ažurirano', _fmtDate(p.updatedAt)),
              _detailRow('Ažurirao', p.updatedBy.isEmpty ? '—' : p.updatedBy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
