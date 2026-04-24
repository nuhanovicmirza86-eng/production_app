import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart'
    show ProductionAccessHelper, ProductionDashboardCard;
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../services/ooe_machine_target_service.dart';

/// Ciljni OOE po stroju (`ooe_machine_targets`).
class OoeMachineTargetsScreen extends StatefulWidget {
  const OoeMachineTargetsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<OoeMachineTargetsScreen> createState() => _OoeMachineTargetsScreenState();
}

class _OoeMachineTargetsScreenState extends State<OoeMachineTargetsScreen> {
  final _svc = OoeMachineTargetService();
  final _val = <String, TextEditingController>{};
  String? _saving;
  late final Future<_TargetPageData> _load;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  @override
  void initState() {
    super.initState();
    _load = _loadData();
  }

  Future<_TargetPageData> _loadData() async {
    final assets = await ProductionTrackingAssetsService().loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
      limit: 128,
    );
    final o = await _svc.loadTargetOoeByMachineForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    return _TargetPageData(assets: assets, ooeTargetById: o);
  }

  @override
  void dispose() {
    for (final c in _val.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String id) => _val.putIfAbsent(
        id,
        () => TextEditingController(),
      );

  Future<void> _save(String machineId) async {
    if (!_canManage) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _saving = machineId);
    try {
      final raw = _c(machineId).text.trim();
      if (raw.isEmpty) {
        await _svc.upsertTargetOoe(
          companyId: _companyId,
          plantKey: _plantKey,
          machineId: machineId,
          targetOoe: null,
        );
      } else {
        final p = double.tryParse(raw.replaceAll(',', '.'));
        if (p == null || p < 0 || p > 100) {
          throw Exception('Unesi 0–100 ili ostavi prazno.');
        }
        await _svc.upsertTargetOoe(
          companyId: _companyId,
          plantKey: _plantKey,
          machineId: machineId,
          targetOoe: p / 100.0,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spremljeno.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ciljevi OOE po stroju')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CompanyPlantLabelText(
              companyId: _companyId,
              plantKey: _plantKey,
              prefix: '',
            ),
          ),
          Expanded(
            child: FutureBuilder<_TargetPageData>(
              future: _load,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(AppErrorMapper.toMessage(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = snap.data!;
                for (final m in d.assets.machines) {
                  final t = d.ooeTargetById[m.id];
                  final ctrl = _c(m.id);
                  if (ctrl.text.isEmpty && t != null) {
                    ctrl.text = (t * 100).toStringAsFixed(0);
                  }
                }
                final m = d.assets.machines;
                if (m.isEmpty) {
                  return const Center(child: Text('Nema strojeva u pogonu.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: m.length,
                  itemBuilder: (context, i) {
                    final a = m[i];
                    return Card(
                      child: ListTile(
                        title: Text(a.title),
                        subtitle: Text('Šifra: ${a.id}'),
                        trailing: SizedBox(
                          width: 120,
                          child: _canManage
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _c(a.id),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.,]'),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Cilj %',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _saving == a.id
                                          ? null
                                          : () => _save(a.id),
                                      icon: _saving == a.id
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.save_outlined),
                                    ),
                                  ],
                                )
                              : null,
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

class _TargetPageData {
  _TargetPageData({required this.assets, required this.ooeTargetById});
  final ProductionPlantAssetsSnapshot assets;
  final Map<String, double?> ooeTargetById;
}
