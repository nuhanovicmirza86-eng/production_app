import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/services/production_order_service.dart';
import '../../processes/models/production_process_model.dart';
import '../../processes/services/production_process_service.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import '../models/downtime_event_model.dart';
import '../services/downtime_service.dart';

class DowntimeCreateScreen extends StatefulWidget {
  const DowntimeCreateScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<DowntimeCreateScreen> createState() => _DowntimeCreateScreenState();
}

class _DowntimeCreateScreenState extends State<DowntimeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _shiftIdCtrl = TextEditingController();
  final _shiftNameCtrl = TextEditingController();

  final _orderService = ProductionOrderService();
  final _wcService = WorkCenterService();
  final _processService = ProductionProcessService();
  final _downtimeService = DowntimeService();

  List<ProductionOrderModel> _orders = const [];
  List<WorkCenter> _workCenters = const [];
  List<ProductionProcess> _processes = const [];

  ProductionOrderModel? _order;
  WorkCenter? _workCenter;
  ProductionProcess? _process;

  String _category = DowntimeCategoryKeys.machineEquipment;
  String _severity = DowntimeSeverity.medium;
  bool _isPlanned = false;
  bool _affectsOee = true;
  bool _affectsOoe = true;
  bool _affectsTeep = true;
  bool _loading = true;
  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _descriptionCtrl.dispose();
    _shiftIdCtrl.dispose();
    _shiftNameCtrl.dispose();
    super.dispose();
  }

  void _applyPlannedDefaults() {
    if (_isPlanned) {
      _affectsOee = false;
      _affectsOoe = true;
      _affectsTeep = true;
      if (_category != DowntimeCategoryKeys.planned) {
        _category = DowntimeCategoryKeys.planned;
      }
    } else {
      _affectsOee = true;
      _affectsOoe = true;
      _affectsTeep = true;
    }
  }

  Future<void> _loadMasters() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final orders = await _orderService.getRecentOrders(
        companyId: _companyId,
        plantKey: _plantKey,
        limit: 100,
      );
      final wcs = await _wcService.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final procsSnap = await _processService
          .watchProcesses(companyId: _companyId, plantKey: _plantKey)
          .first;

      ProductionOrderModel? pickOrder;
      for (final o in orders) {
        final st = o.status.trim().toLowerCase();
        if (st != 'closed' && st != 'cancelled') {
          pickOrder = o;
          break;
        }
      }
      pickOrder ??= orders.isNotEmpty ? orders.first : null;

      WorkCenter? pickWc;
      if (pickOrder != null &&
          (pickOrder.workCenterId ?? '').trim().isNotEmpty) {
        final id = pickOrder.workCenterId!.trim();
        for (final w in wcs) {
          if (w.id == id) {
            pickWc = w;
            break;
          }
        }
      }
      pickWc ??= wcs.isNotEmpty ? wcs.first : null;

      ProductionProcess? pickProc;
      final wcLocal = pickWc;
      if (wcLocal != null && procsSnap.isNotEmpty) {
        for (final p in procsSnap) {
          if (p.linkedWorkCenterIds.contains(wcLocal.id)) {
            pickProc = p;
            break;
          }
        }
        pickProc ??= () {
          for (final p in procsSnap) {
            if (p.isActive) return p;
          }
          return procsSnap.first;
        }();
      }

      if (!mounted) return;
      setState(() {
        _orders = orders;
        _workCenters = wcs;
        _processes = procsSnap;
        _order = pickOrder;
        _workCenter = pickWc;
        _process = pickProc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niste prijavljeni.')),
      );
      return;
    }

    if (_order == null ||
        _workCenter == null ||
        _process == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberite nalog, radni centar i proces.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final name = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email ?? user.uid);

      await _downtimeService.createDowntime(
        companyId: _companyId,
        plantKey: _plantKey,
        productionOrderId: _order!.id,
        productionOrderCode: _order!.productionOrderCode,
        workCenterId: _workCenter!.id,
        workCenterCode: _workCenter!.workCenterCode,
        workCenterName: _workCenter!.name,
        processId: _process!.id,
        processCode: _process!.processCode,
        processName: _process!.name,
        downtimeCategory: _category,
        downtimeReason: _reasonCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        severity: _severity,
        startedAt: DateTime.now(),
        isPlanned: _isPlanned,
        affectsOee: _affectsOee,
        affectsOoe: _affectsOoe,
        affectsTeep: _affectsTeep,
        operatorId: user.uid,
        reportedBy: user.uid,
        reportedByName: name,
        shiftId: _shiftIdCtrl.text.trim(),
        shiftName: _shiftNameCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zastoj je prijavljen.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prijavi zastoj')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty || _workCenters.isEmpty || _processes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _orders.isEmpty
                      ? 'Nema dostupnih proizvodnih naloga za ovaj pogon.'
                      : _workCenters.isEmpty
                      ? 'Nema definiranih radnih centara.'
                      : 'Nema definiranih procesa.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Obavezna polja za analitiku: nalog, radni centar, proces, kategorija, razlog.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ProductionOrderModel>(
                    decoration: const InputDecoration(
                      labelText: 'Proizvodni nalog',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    value: _order,
                    items: _orders
                        .map(
                          (o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                              '${o.productionOrderCode} · ${o.productCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (o) => setState(() => _order = o),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WorkCenter>(
                    decoration: const InputDecoration(
                      labelText: 'Radni centar',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    value: _workCenter,
                    items: _workCenters
                        .map(
                          (w) => DropdownMenuItem(
                            value: w,
                            child: Text(
                              '${w.workCenterCode} — ${w.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (w) => setState(() => _workCenter = w),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductionProcess>(
                    decoration: const InputDecoration(
                      labelText: 'Proces',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    value: _process,
                    items: _processes
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.processCode} — ${p.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => setState(() => _process = p),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Kategorija zastoja',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    value: _category,
                    items: DowntimeCategoryKeys.all
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(DowntimeCategoryKeys.labelHr(k)),
                          ),
                        )
                        .toList(),
                    onChanged: _isPlanned
                        ? null
                        : (v) {
                            if (v != null) setState(() => _category = v);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Konkretan razlog',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Unesite razlog.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Opis / napomena (opcionalno)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Kritičnost',
                      border: OutlineInputBorder(),
                    ),
                    value: _severity,
                    items: DowntimeSeverity.all
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(DowntimeSeverity.labelHr(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _severity = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Planirani zastoj'),
                    subtitle: const Text(
                      'Kod planiranog zastoja uobičajeno se ne umanjuje iskoristivost resursa (dostupnost).',
                    ),
                    value: _isPlanned,
                    onChanged: (v) {
                      setState(() {
                        _isPlanned = v;
                        _applyPlannedDefaults();
                      });
                    },
                  ),
                  if (!_isPlanned) ...[
                    SwitchListTile(
                      title: const Text('Utječe na mjeru iskoristivosti resursa'),
                      value: _affectsOee,
                      onChanged: (v) => setState(() => _affectsOee = v),
                    ),
                    SwitchListTile(
                      title: const Text('Utječe na mjeru učinkovitosti (gubitci)'),
                      value: _affectsOoe,
                      onChanged: (v) => setState(() => _affectsOoe = v),
                    ),
                    SwitchListTile(
                      title: const Text('Utječe na mjeru cijelog planiranog fonda vremena'),
                      value: _affectsTeep,
                      onChanged: (v) => setState(() => _affectsTeep = v),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'Iskoristivost resursa: ne; učinak s gubicima: da; cijeli fond: da (uobičajeno za planirano)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shiftIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Oznaka smjene (opcijalno)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shiftNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Naziv smjene (opcijalno)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Spremi prijavu'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
