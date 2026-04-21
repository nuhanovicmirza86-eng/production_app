import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/inventory_adjustment_service.dart';

class InventoryAdjustmentsScreen extends StatefulWidget {
  const InventoryAdjustmentsScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  final Map<String, dynamic> companyData;
  final bool embedInHubShell;

  @override
  State<InventoryAdjustmentsScreen> createState() =>
      _InventoryAdjustmentsScreenState();
}

class _InventoryAdjustmentsScreenState
    extends State<InventoryAdjustmentsScreen> {
  final _svc = InventoryAdjustmentService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _hasLogistics {
    final raw = widget.companyData['enabledModules'];
    if (raw is! List || raw.isEmpty) return false;
    return raw.map((e) => e.toString().trim().toLowerCase()).contains(
      'logistics',
    );
  }

  bool get _canApply {
    final r = _role;
    return r == ProductionAccessHelper.roleSuperAdmin ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleLogisticsManager ||
        r == ProductionAccessHelper.roleProductionManager;
  }

  Future<void> _openApplyDialog() async {
    final lotCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final reasonTextCtrl = TextEditingController();
    var reasonCode = 'COUNT_DIFF';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Korekcija zalihe na lotu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unesi internu oznaku lota iz skladišta (npr. nakon skeniranja ili iz pregleda zaliha).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lotCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Oznaka lota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nova raspoloživa količina',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Kod razloga',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: reasonCode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'COUNT_DIFF',
                            child: Text('COUNT_DIFF — inventura'),
                          ),
                          DropdownMenuItem(
                            value: 'DAMAGE',
                            child: Text('DAMAGE — oštećenje'),
                          ),
                          DropdownMenuItem(
                            value: 'DATA_ENTRY',
                            child: Text('DATA_ENTRY — ispravak unosa'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('OTHER — ostalo'),
                          ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => reasonCode = v ?? 'COUNT_DIFF'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonTextCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Obrazloženje (obavezno)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () {
                  if (lotCtrl.text.trim().isEmpty ||
                      qtyCtrl.text.trim().isEmpty ||
                      reasonTextCtrl.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Primijeni'),
              ),
            ],
          );
        },
      ),
    );

    final lotDocId = lotCtrl.text.trim();
    final qtyRaw = qtyCtrl.text.trim();
    final reasonTxt = reasonTextCtrl.text.trim();

    lotCtrl.dispose();
    qtyCtrl.dispose();
    reasonTextCtrl.dispose();

    if (ok != true || !mounted) return;

    final q = double.tryParse(qtyRaw.replaceAll(',', '.'));
    if (q == null || q < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nevaljana količina.')),
      );
      return;
    }

    try {
      await _svc.applyLotAdjustment(
        companyId: _companyId,
        lotDocId: lotDocId,
        newQuantityOnHand: q,
        reasonCode: reasonCode,
        reasonText: reasonTxt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Korekcija je knjižena.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  String _formatTime(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasLogistics || _companyId.isEmpty) {
      final body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _companyId.isEmpty
                ? 'Nedostaje podatak o kompaniji. Obrati se administratoru.'
                : 'Modul logistike nije uključen za ovu kompaniju.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
      return wmsTabScaffold(
        embedInHubShell: widget.embedInHubShell,
        title: 'Korekcije zaliha',
        body: body,
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Evidentirane korekcije (zadnjih 50). Knjiženje ide kroz Callable: '
            'lot, movement, inventory_balances po artiklu/magacinu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('inventory_adjustments')
                .where('companyId', isEqualTo: _companyId)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppErrorMapper.toMessage(snap.error!),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Još nema korekcija.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final oldQ = d['oldQty'];
                  final newQ = d['newQty'];
                  final code = (d['reasonCode'] ?? '').toString();
                  final lot = (d['lotId'] ?? '').toString();
                  final wh = (d['warehouseId'] ?? '').toString();
                  final created = _formatTime(d['createdAt']);
                  return Card(
                    child: ListTile(
                      title: Text(
                        '$oldQ → $newQ  (${d['unit'] ?? 'pcs'})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (created.isNotEmpty) created,
                          'Magacin: $wh',
                          'Lot: $lot',
                          'Razlog: $code',
                          (d['reasonText'] ?? '').toString(),
                        ].where((x) => x.toString().trim().isNotEmpty).join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Korekcije zaliha',
      body: body,
      floatingActionButton: _canApply
          ? FloatingActionButton.extended(
              onPressed: _openApplyDialog,
              icon: const Icon(Icons.tune),
              label: const Text('Nova korekcija'),
            )
          : null,
    );
  }
}
