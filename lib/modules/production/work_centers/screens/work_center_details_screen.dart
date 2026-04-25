import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/screens/production_order_details_screen.dart';
import '../../production_orders/services/production_order_service.dart';
import '../models/work_center_model.dart';
import '../services/work_center_service.dart';
import '../widgets/work_center_help.dart';
import 'work_center_edit_screen.dart';

class WorkCenterDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String workCenterId;
  final String plantKey;

  const WorkCenterDetailsScreen({
    super.key,
    required this.companyData,
    required this.workCenterId,
    required this.plantKey,
  });

  @override
  State<WorkCenterDetailsScreen> createState() =>
      _WorkCenterDetailsScreenState();
}

class _WorkCenterDetailsScreenState extends State<WorkCenterDetailsScreen> {
  final WorkCenterService _service = WorkCenterService();
  final ProductionOrderService _orderService = ProductionOrderService();

  bool _loading = true;
  String? _error;
  WorkCenter? _wc;
  String _plantLabel = '';

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
    card: ProductionDashboardCard.workCenters,
  );

  @override
  void initState() {
    super.initState();
    _load();
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
      final wc = await _service.getById(
        companyId: _companyId,
        plantKey: pk,
        workCenterId: widget.workCenterId.trim(),
      );
      if (!mounted) return;
      setState(() {
        _plantLabel = pl;
        _wc = wc;
        _loading = false;
        if (wc == null) {
          _error = 'Radni centar nije pronađen ili nije u vašem kontekstu.';
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

  Future<void> _confirmDeactivate() async {
    final wc = _wc;
    if (wc == null || !_canManage) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deaktivirati radni centar?'),
        content: Text(
          'Zapis ostaje u bazi, ali će biti označen kao neaktivan '
          '(${wc.workCenterCode}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deaktiviraj'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.deactivateWorkCenter(
        workCenterId: wc.id,
        companyId: _companyId,
        plantKey: widget.plantKey.trim(),
        updatedBy: _userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radni centar je deaktiviran.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => WorkCenterEditScreen(
          companyData: widget.companyData,
          workCenterId: widget.workCenterId.trim(),
          plantKey: widget.plantKey.trim(),
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Widget _sectionTitle(
    String t, {
    String? helpTitle,
    String? helpBody,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              t,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (helpTitle != null &&
              helpBody != null &&
              helpTitle.isNotEmpty &&
              helpBody.isNotEmpty)
            WorkCenterInfoIcon(title: helpTitle, message: helpBody),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            k,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );

  Widget _recentProductionOrdersCard(WorkCenter wc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nedavni proizvodni nalozi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  WorkCenterInfoIcon(
                    title: 'Nalozi na ovom centru',
                    message:
                        'Lista prikazuje naloge čije je polje workCenterId jednako ovom radnom centru. '
                        'Dodjelu mijenjate u detaljima proizvodnog naloga (Postavi radni centar / resurse).',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            StreamBuilder<List<ProductionOrderModel>>(
              stream: _orderService.watchOrdersForWorkCenter(
                companyId: _companyId,
                plantKey: widget.plantKey.trim(),
                workCenterId: wc.id,
                limit: 25,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(AppErrorMapper.toMessage(snap.error!)),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Još nema naloga dodijeljenih ovom centru. U detaljima naloga odaberite ovaj radni centar.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return Column(
                  children: list.map((o) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        o.productionOrderCode,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${o.productCode} · ${o.status}'),
                      trailing: Text(
                        _fmtDate(o.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ProductionOrderDetailsScreen(
                              companyData: widget.companyData,
                              productionOrderId: o.id,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radni centar'),
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
          if (_canManage && _wc != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
            ),
            if (_wc!.active)
              IconButton(
                icon: const Icon(Icons.highlight_off_outlined),
                tooltip: 'Deaktiviraj',
                onPressed: _confirmDeactivate,
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _wc == null
          ? const Center(child: Text('Nema podataka.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${_wc!.workCenterCode} | ${_wc!.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!_wc!.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: const Text('Neaktivan u šifrarniku'),
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                _sectionTitle(
                  'Osnovni podaci',
                  helpTitle: WorkCenterHelpTexts.basicDataTitle,
                  helpBody: WorkCenterHelpTexts.basicDataBody,
                ),
                _kv('Tip', WorkCenter.labelForType(_wc!.type)),
                _kv('Status', WorkCenter.labelForStatus(_wc!.status)),
                _kv('Pogon', _plantLabel),
                _kv('Lokacija / zona', _wc!.locationName.isEmpty ? '—' : _wc!.locationName),
                _sectionTitle(
                  'Kapacitet i resursi',
                  helpTitle: WorkCenterHelpTexts.capacityResourcesTitle,
                  helpBody: WorkCenterHelpTexts.capacityResourcesBody,
                ),
                _kv(
                  'Kapacitet',
                  _wc!.capacityPerHour > 0
                      ? '${_wc!.capacityPerHour == _wc!.capacityPerHour.roundToDouble() ? _wc!.capacityPerHour.toInt() : _wc!.capacityPerHour} kom/h'
                      : '—',
                ),
                _kv(
                  'Standardni ciklus',
                  _wc!.standardCycleTimeSec > 0
                      ? '${_wc!.standardCycleTimeSec == _wc!.standardCycleTimeSec.roundToDouble() ? _wc!.standardCycleTimeSec.toInt() : _wc!.standardCycleTimeSec} s'
                      : '—',
                ),
                _kv('Broj operatera', _wc!.operatorCount.toString()),
                _sectionTitle(
                  'Mjerne kategorije učinka',
                  helpTitle: WorkCenterHelpTexts.oeeBlockTitle,
                  helpBody: WorkCenterHelpTexts.oeeBlockBody,
                ),
                _kv('Uključeno u mjeru iskoristivosti resursa', _wc!.isOeeRelevant ? 'Da' : 'Ne'),
                _kv('Uključeno u mjeru učinkovitosti (bruto)', _wc!.isOoeRelevant ? 'Da' : 'Ne'),
                _kv('Uključeno u mjeru iskorištenja planiranog fonda vremena', _wc!.isTeepRelevant ? 'Da' : 'Ne'),
                _sectionTitle(
                  'Povezani asset',
                  helpTitle: WorkCenterHelpTexts.assetTitle,
                  helpBody: WorkCenterHelpTexts.assetBody,
                ),
                _kv(
                  'Uređaj / linija',
                  _wc!.linkedAssetId.isEmpty
                      ? 'Nije povezano'
                      : _wc!.linkedAssetName.isEmpty
                      ? _wc!.linkedAssetId
                      : '${_wc!.linkedAssetName} (${_wc!.linkedAssetId})',
                ),
                _sectionTitle(
                  'Operativni kontekst (proširenja)',
                  helpTitle: WorkCenterHelpTexts.extensionsTitle,
                  helpBody: WorkCenterHelpTexts.extensionsBody,
                ),
                _recentProductionOrdersCard(_wc!),
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.upcoming_outlined,
                          size: 22,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'U planu: povezivanje ruta, dozvole po operacijama, '
                            'povijest zastoja i otklona, te sažetak učinka po smjeni, '
                            'kad se u potpunosti povežu zapisnici s ovim centrom.',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _sectionTitle(
                  'Audit',
                  helpTitle: WorkCenterHelpTexts.auditTitle,
                  helpBody: WorkCenterHelpTexts.auditBody,
                ),
                _kv('Kreirano', _fmtDate(_wc!.createdAt)),
                _kv('Kreirao', _wc!.createdBy.isEmpty ? '—' : _wc!.createdBy),
                _kv('Ažurirano', _fmtDate(_wc!.updatedAt)),
                _kv('Ažurirao', _wc!.updatedBy.isEmpty ? '—' : _wc!.updatedBy),
                const SizedBox(height: 24),
                if (_canManage)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _wc!.active ? _confirmDeactivate : null,
                          icon: const Icon(Icons.block),
                          label: const Text('Deaktiviraj radni centar'),
                        ),
                      ),
                      WorkCenterInfoIcon(
                        title: WorkCenterHelpTexts.deactivateTitle,
                        message: WorkCenterHelpTexts.deactivateBody,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
