import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import '../models/production_order_model.dart';
import '../services/production_order_service.dart';

/// Dodjela radnog centra i tehničkih referenci (stroj/linija) na proizvodni nalog.
class ProductionOrderMesAssignmentScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final ProductionOrderModel order;

  const ProductionOrderMesAssignmentScreen({
    super.key,
    required this.companyData,
    required this.order,
  });

  @override
  State<ProductionOrderMesAssignmentScreen> createState() =>
      _ProductionOrderMesAssignmentScreenState();
}

class _ProductionOrderMesAssignmentScreenState
    extends State<ProductionOrderMesAssignmentScreen> {
  final _service = ProductionOrderService();
  final _wcService = WorkCenterService();

  final _machineCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();

  List<WorkCenter> _centers = const [];
  bool _loadingCenters = true;
  String? _selectedWorkCenterId;
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _userId =>
      (widget.companyData['userId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _machineCtrl.text = (o.machineId ?? '').trim();
    _lineCtrl.text = (o.lineId ?? '').trim();
    _selectedWorkCenterId = (o.workCenterId ?? '').trim().isEmpty
        ? null
        : o.workCenterId!.trim();
    _loadCenters();
  }

  @override
  void dispose() {
    _machineCtrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    setState(() => _loadingCenters = true);
    try {
      var list = await _wcService.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
        onlyActive: true,
      );
      final oid = widget.order.workCenterId?.trim();
      if (oid != null &&
          oid.isNotEmpty &&
          !list.any((w) => w.id == oid)) {
        final orphan = await _wcService.getById(
          companyId: _companyId,
          plantKey: _plantKey,
          workCenterId: oid,
        );
        if (orphan != null) {
          list = [orphan, ...list];
        }
      }
      if (!mounted) return;
      setState(() {
        _centers = list;
        _loadingCenters = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCenters = false);
    }
  }

  WorkCenter? _centerById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final w in _centers) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> _save() async {
    if (_role != 'admin' && _role != 'production_manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nemate pravo spremanja MES dodjele.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final sel = _centerById(_selectedWorkCenterId);
      final String? wid;
      final String? wcode;
      final String? wname;
      if (sel != null) {
        wid = sel.id;
        wcode = sel.workCenterCode;
        wname = sel.name;
      } else if (_selectedWorkCenterId != null &&
          _selectedWorkCenterId == widget.order.workCenterId?.trim()) {
        wid = widget.order.workCenterId;
        wcode = widget.order.workCenterCode;
        wname = widget.order.workCenterName;
      } else {
        wid = null;
        wcode = null;
        wname = null;
      }

      await _service.updateProductionOrderMesAssignment(
        productionOrderId: widget.order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUserId: _userId,
        actorRole: _role,
        workCenterId: wid,
        workCenterCode: wcode,
        workCenterName: wname,
        machineId: _machineCtrl.text.trim().isEmpty
            ? null
            : _machineCtrl.text.trim(),
        lineId: _lineCtrl.text.trim().isEmpty ? null : _lineCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MES dodjela je spremljena.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.order.status.toLowerCase();
    final blocked = st == 'closed' || st == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radni centar i resursi'),
      ),
      body: blocked
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nalog u ovom statusu se ne može mijenjati.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.order.productionOrderCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.order.productName,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Radni centar određuje gdje se MES izvršenje planira i bilježi. '
                  'Stroj/linija su dodatne tehničke reference (npr. asset ID ili oznaka linije).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_loadingCenters)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                else
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedWorkCenterId,
                    decoration: const InputDecoration(
                      labelText: 'Radni centar',
                      border: OutlineInputBorder(),
                      helperText: 'Obavezno za puni MES tok; može ostati prazno u prijelazu.',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— bez radnog centra —'),
                      ),
                      ..._centers.map(
                        (w) => DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text(
                            '${w.workCenterCode} — ${w.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedWorkCenterId = v),
                  ),
                if (!_loadingCenters &&
                    _selectedWorkCenterId != null &&
                    _centerById(_selectedWorkCenterId) == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Trenutno spremljeni centar nije u listi aktivnih — odaberite ponovo ili uklonite.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _machineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mašina / asset referenca (opcionalno)',
                    border: OutlineInputBorder(),
                    hintText: 'Interna oznaka uređaja',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Linija (opcionalno)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Spremi'),
                ),
              ],
            ),
    );
  }
}
