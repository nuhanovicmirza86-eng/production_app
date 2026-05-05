import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../models/development_project_supplier_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_help_texts.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';

List<String> splitDevelopmentSupplierIds(String raw) {
  return raw
      .split(RegExp(r'[\s,;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Sva polja dobavljača na projektu; spremanje preko [DevelopmentProjectService.upsertSupplierViaCallable].
/// Vraća `true` ako je korisnik spremio (Callable uspješan).
Future<bool> showDevelopmentSupplierEditorDialog(
  BuildContext context, {
  required Map<String, dynamic> companyData,
  required DevelopmentProjectModel project,
  DevelopmentProjectSupplierModel? supplier,
}) async {
  final companyId = (companyData['companyId'] ?? '').toString().trim();
  final plantKey = (companyData['plantKey'] ?? '').toString().trim();
  final service = DevelopmentProjectService();

  final nameCtrl = TextEditingController(text: supplier?.displayName ?? '');
  final scopeCtrl = TextEditingController(text: supplier?.scopeSummary ?? '');
  final iatfCtrl = TextEditingController(text: supplier?.iatfControlNote ?? '');
  final evalCtrl = TextEditingController(text: supplier?.evaluationNote ?? '');
  final taskIdsCtrl = TextEditingController(
    text: supplier?.assignedTaskIds.join(', ') ?? '',
  );
  final partsCtrl = TextEditingController(
    text: supplier?.assignedPartLabels.join(', ') ?? '',
  );

  var category = supplier?.category ?? DevelopmentSupplierCategories.other;
  if (!DevelopmentSupplierCategories.all.contains(category)) {
    category = DevelopmentSupplierCategories.other;
  }
  var approval = supplier?.approvalStatus ??
      DevelopmentSupplierApprovalStatuses.draft;
  if (!DevelopmentSupplierApprovalStatuses.all.contains(approval)) {
    approval = DevelopmentSupplierApprovalStatuses.draft;
  }
  var extRisk = supplier?.externalRiskLevel ?? DevelopmentRiskLevels.medium;
  if (!<String>{
    DevelopmentRiskLevels.low,
    DevelopmentRiskLevels.medium,
    DevelopmentRiskLevels.high,
  }.contains(extRisk)) {
    extRisk = DevelopmentRiskLevels.medium;
  }
  int? q = supplier?.qualityRating;
  int? dv = supplier?.deliveryRating;
  int? pr = supplier?.priceRating;
  DateTime? due = supplier?.dueDate;

  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(supplier == null ? 'Novi dobavljač' : 'Uredi dobavljača'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naziv dobavljača *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('dev_sup_cat_$category'),
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Kategorija',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentSupplierCategories.all
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(DevelopmentDisplay.supplierCategoryLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => category = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('dev_sup_appr_$approval'),
                  initialValue: approval,
                  decoration: const InputDecoration(
                    labelText: 'Status odobrenja',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentSupplierApprovalStatuses.all
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(DevelopmentDisplay.supplierApprovalLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => approval = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('dev_sup_risk_$extRisk'),
                        initialValue: extRisk,
                        decoration: const InputDecoration(
                          labelText: 'Vanjski rizik (IATF 8.4 kontekst)',
                          border: OutlineInputBorder(),
                        ),
                        items: <String>[
                          DevelopmentRiskLevels.low,
                          DevelopmentRiskLevels.medium,
                          DevelopmentRiskLevels.high,
                        ]
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child:
                                    Text(DevelopmentDisplay.supplierExternalRiskLabel(c)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialog(() => extRisk = v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OoeInfoIcon(
                        tooltip: DevelopmentHelpTexts.supplierExternalRiskTooltip,
                        dialogTitle: DevelopmentHelpTexts.supplierExternalRiskTitle,
                        dialogBody: DevelopmentHelpTexts.supplierExternalRiskBody,
                        iconSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: scopeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opseg rada i isporuke (npr. kalup, granulat, usluga)',
                    hintText: 'Ukratko što dobavljač radi i što predaje projektu',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taskIdsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID zadataka (odvojeni zarezom)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: partsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dijelovi / artikli koje isporučuje (zarezom)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rok isporuke'),
                  subtitle: Text(
                    due?.toLocal().toString() ?? 'Nije postavljen',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.event),
                        onPressed: () async {
                          final d0 = await showDatePicker(
                            context: ctx,
                            initialDate: due ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2040),
                          );
                          if (d0 != null) setDialog(() => due = d0);
                        },
                      ),
                      if (due != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialog(() => due = null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('dev_sup_q_$q'),
                        initialValue: q,
                        decoration: const InputDecoration(
                          labelText: 'Kvalitet 1–5',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('—'),
                          ),
                          for (var i = 1; i <= 5; i++)
                            DropdownMenuItem<int?>(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setDialog(() => q = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('dev_sup_dv_$dv'),
                        initialValue: dv,
                        decoration: const InputDecoration(
                          labelText: 'Rok 1–5',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('—'),
                          ),
                          for (var i = 1; i <= 5; i++)
                            DropdownMenuItem<int?>(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setDialog(() => dv = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('dev_sup_pr_$pr'),
                        initialValue: pr,
                        decoration: const InputDecoration(
                          labelText: 'Cijena 1–5',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('—'),
                          ),
                          for (var i = 1; i <= 5; i++)
                            DropdownMenuItem<int?>(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setDialog(() => pr = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: iatfCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IATF 8.4 — kontrole / trag',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: OoeInfoIcon(
                        tooltip: DevelopmentHelpTexts.supplierIatfFieldTooltip,
                        dialogTitle: DevelopmentHelpTexts.supplierIatfFieldTitle,
                        dialogBody: DevelopmentHelpTexts.supplierIatfFieldBody,
                        iconSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: evalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Interna ocjena / napomena',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Spremi'),
            ),
          ],
        ),
      ),
    );

    final nm = nameCtrl.text.trim();
    final scopeT = scopeCtrl.text.trim();
    final iatfT = iatfCtrl.text.trim();
    final evalT = evalCtrl.text.trim();
    final taskT = taskIdsCtrl.text;
    final partsT = partsCtrl.text;

    if (ok != true || !context.mounted) return false;
    if (nm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naziv je obavezan.')),
      );
      return false;
    }

    await service.upsertSupplierViaCallable(
      companyId: companyId,
      plantKey: plantKey,
      projectId: project.id,
      supplierId: supplier?.id,
      displayName: nm,
      category: category,
      approvalStatus: approval,
      externalRiskLevel: extRisk,
      scopeSummary: scopeT.isEmpty ? null : scopeT,
      iatfControlNote: iatfT.isEmpty ? null : iatfT,
      evaluationNote: evalT.isEmpty ? null : evalT,
      assignedTaskIds: splitDevelopmentSupplierIds(taskT),
      assignedPartLabels: splitDevelopmentSupplierIds(partsT),
      qualityRating: q,
      deliveryRating: dv,
      priceRating: pr,
      dueDate: due,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dobavljač je spremljen.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
    return false;
  } finally {
    nameCtrl.dispose();
    scopeCtrl.dispose();
    iatfCtrl.dispose();
    evalCtrl.dispose();
    taskIdsCtrl.dispose();
    partsCtrl.dispose();
  }
}
