import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../models/development_project_supplier_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_help_texts.dart';
import '../utils/development_permissions.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';
import 'development_supplier_editor_dialog.dart';

/// Vanjski dobavljači na NPI projektu (odobrenje, dijelovi/zadaci, ocjene, IATF trag za AI).
class DevelopmentProjectSuppliersTab extends StatelessWidget {
  const DevelopmentProjectSuppliersTab({
    super.key,
    required this.companyData,
    required this.project,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (companyData['plantKey'] ?? '').toString().trim();

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentTasks(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  Future<void> _showSupplierDetailSheet(
    BuildContext context,
    DevelopmentProjectSupplierModel s,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: 16 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.displayName.isEmpty ? 'Dobavljač' : s.displayName,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${DevelopmentDisplay.supplierCategoryLabel(s.category)} · '
                    '${DevelopmentDisplay.supplierApprovalLabel(s.approvalStatus)}',
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vanjski rizik: ${DevelopmentDisplay.supplierExternalRiskLabel(s.externalRiskLevel)}',
                    style: tt.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Što dostavlja na ovom projektu',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DevelopmentDisplay.supplierDeliveryDescription(s),
                    style: tt.bodySmall?.copyWith(height: 1.35),
                  ),
                  if (s.dueDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rok: ${s.dueDate!.toLocal()}',
                      style: tt.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Ocjene (1–5)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    'Kvaliteta: ${s.qualityRating ?? '—'} · '
                    'Rok: ${s.deliveryRating ?? '—'} · '
                    'Cijena: ${s.priceRating ?? '—'}',
                    style: tt.bodySmall,
                  ),
                  if ((s.evaluationNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Evaluacija / problemi', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      s.evaluationNote!,
                      style: tt.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                  if ((s.iatfControlNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'IATF 8.4 trag',
                            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OoeInfoIcon(
                          tooltip: DevelopmentHelpTexts.iatf84TraceTooltip,
                          dialogTitle: DevelopmentHelpTexts.iatf84TraceTitle,
                          dialogBody: DevelopmentHelpTexts.iatf84TraceBody,
                          iconSize: 18,
                        ),
                      ],
                    ),
                    Text(
                      s.iatfControlNote!,
                      style: tt.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_canMutate)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showDevelopmentSupplierEditorDialog(
                          context,
                          companyData: companyData,
                          project: project,
                          supplier: s,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Uredi'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    DevelopmentProjectSupplierModel? supplier,
  }) async {
    await showDevelopmentSupplierEditorDialog(
      context,
      companyData: companyData,
      project: project,
      supplier: supplier,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DevelopmentProjectService service,
    DevelopmentProjectSupplierModel s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni dobavljača'),
        content: Text('Ukloniti „${s.displayName}” s projekta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.deleteSupplierViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: project.id,
        supplierId: s.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dobavljač je uklonjen.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DevelopmentProjectService();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dobavljači na projektu',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OoeInfoIcon(
                    tooltip: DevelopmentHelpTexts.suppliersTabTooltip,
                    dialogTitle: DevelopmentHelpTexts.suppliersTabTitle,
                    dialogBody: DevelopmentHelpTexts.suppliersTabBody,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DevelopmentProjectSupplierModel>>(
              stream: service.watchSuppliers(project.id),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Greška: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _canMutate
                            ? 'Još nema dobavljača — dodaj alatnicu, materijal ili uslugodavca.'
                            : 'Nema evidentiranih dobavljača.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final apColor = switch (s.approvalStatus) {
                      DevelopmentSupplierApprovalStatuses.approved => scheme.primary,
                      DevelopmentSupplierApprovalStatuses.rejected => scheme.error,
                      DevelopmentSupplierApprovalStatuses.pendingApproval =>
                        scheme.tertiary,
                      _ => scheme.outline,
                    };
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () =>
                            _showSupplierDetailSheet(context, s),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.displayName,
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: apColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      DevelopmentDisplay.supplierApprovalLabel(
                                        s.approvalStatus,
                                      ),
                                      style: tt.labelSmall?.copyWith(
                                        color: apColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DevelopmentDisplay.supplierCategoryLabel(s.category),
                                style: tt.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Što dostavlja',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DevelopmentDisplay.supplierDeliveryDescription(s),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(height: 1.35),
                              ),
                              if (s.dueDate != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Rok: ${s.dueDate!.toLocal()}',
                                  style: tt.labelSmall,
                                ),
                              ],
                              if (_canMutate)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _confirmDelete(context, service, s),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Ukloni'),
                                  ),
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
      floatingActionButton: _canMutate
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Dobavljač'),
            )
          : null,
    );
  }
}
