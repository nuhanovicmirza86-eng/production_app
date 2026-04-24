import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart'
    show ProductionAccessHelper, ProductionDashboardCard;
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../models/ooe_alert_rule.dart';
import '../services/ooe_alert_rule_service.dart';

/// Upravljanje pragovima (ooe_alert_rules).
class OoeAlertRulesScreen extends StatefulWidget {
  const OoeAlertRulesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<OoeAlertRulesScreen> createState() => _OoeAlertRulesScreenState();
}

class _OoeAlertRulesScreenState extends State<OoeAlertRulesScreen> {
  final _svc = OoeAlertRuleService();
  late final Future<ProductionPlantAssetsSnapshot> _assets;

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
    _assets = ProductionTrackingAssetsService().loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
      limit: 128,
    );
  }

  void _openEditor({OoeAlertRule? existing}) {
    if (!_canManage) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RuleEditor(
        companyId: _companyId,
        plantKey: _plantKey,
        existing: existing,
        assets: _assets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pragovi OOE alarma')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Novo pravilo'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            child: StreamBuilder<List<OoeAlertRule>>(
              stream: _svc.watchRules(companyId: _companyId, plantKey: _plantKey),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(AppErrorMapper.toMessage(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Nema pravila. Dodaj prag za OOE iliudio škarta.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.name ?? r.ruleType),
                        subtitle: Text(
                          'Stroj ${r.machineId} · prag ${(r.threshold * 100).toStringAsFixed(0)} % · ${r.active ? "aktivno" : "neaktivno"}',
                        ),
                        trailing: _canManage
                            ? IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEditor(existing: r),
                              )
                            : null,
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

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({
    required this.companyId,
    required this.plantKey,
    this.existing,
    required this.assets,
  });

  final String companyId;
  final String plantKey;
  final OoeAlertRule? existing;
  final Future<ProductionPlantAssetsSnapshot> assets;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final _svc = OoeAlertRuleService();
  final _name = TextEditingController();
  final _th = TextEditingController();
  String _type = OoeAlertRule.typeOoeBelow;
  String _mid = '';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name ?? '';
      _th.text = (e.threshold * 100).toStringAsFixed(0);
      _type = e.ruleType;
      _mid = e.machineId;
      _active = e.active;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _th.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_mid.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi stroj (šifru).')),
      );
      return;
    }
    final p = double.tryParse(_th.text.trim().replaceAll(',', '.'));
    if (p == null || p < 0 || p > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prag 0–100 (%).')),
      );
      return;
    }
    final t = p / 100.0;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _svc.createRule(
          companyId: widget.companyId,
          plantKey: widget.plantKey,
          machineId: _mid.trim(),
          ruleType: _type,
          threshold: t,
          name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          active: _active,
        );
      } else {
        await _svc.updateRule(
          ruleId: widget.existing!.id,
          companyId: widget.companyId,
          plantKey: widget.plantKey,
          machineId: _mid.trim(),
          ruleType: _type,
          threshold: t,
          name: _name.text.trim(),
          active: _active,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        top: 8,
      ),
      child: FutureBuilder<ProductionPlantAssetsSnapshot>(
        future: widget.assets,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final machines = snap.data!.machines;
          if (_mid.isEmpty && machines.isNotEmpty) {
            _mid = machines.first.id;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Novo pravilo' : 'Uredi pravilo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mid.isEmpty || !machines.any((m) => m.id == _mid)
                    ? (machines.isEmpty ? null : machines.first.id)
                    : _mid,
                items: machines
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.id} — ${m.title}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _mid = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Stroj',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                    value: OoeAlertRule.typeOoeBelow,
                    child: Text('OOE ispod praga (trenutna smjena)'),
                  ),
                  DropdownMenuItem(
                    value: OoeAlertRule.typeScrapRateAbove,
                    child: Text('Udio škarta iznad praga (live)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Tip',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _th,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Prag (%)',
                  hintText: 'npr. 50 za 50 %',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Naziv (opc.)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktivno'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '…' : 'Spremi'),
              ),
            ],
          );
        },
      ),
    );
  }
}
