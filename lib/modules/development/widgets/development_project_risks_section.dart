// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../models/development_project_risk_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Lista rizika + Callable create/update.
class DevelopmentProjectRisksSection extends StatelessWidget {
  const DevelopmentProjectRisksSection({
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

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentRisks(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  Future<void> _openRiskEditor(
    BuildContext context,
    DevelopmentProjectService service, {
    DevelopmentProjectRiskModel? risk,
  }) async {
    final titleCtrl = TextEditingController(text: risk?.title ?? '');
    final descCtrl = TextEditingController(text: risk?.description ?? '');
    final mitCtrl =
        TextEditingController(text: risk?.mitigationNote ?? '');
    var severity = risk?.severity ?? DevelopmentRiskLevels.medium;
    if (!const [
      DevelopmentRiskLevels.low,
      DevelopmentRiskLevels.medium,
      DevelopmentRiskLevels.high,
      DevelopmentRiskLevels.critical,
    ].contains(severity)) {
      severity = DevelopmentRiskLevels.medium;
    }
    var status = risk?.status ?? DevelopmentRiskStatuses.open;
    if (!DevelopmentRiskStatuses.all.contains(status)) {
      status = DevelopmentRiskStatuses.open;
    }
    String? category = risk?.category;
    var blocksRelease = risk?.blocksRelease ??
        (severity == DevelopmentRiskLevels.critical);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(risk == null ? 'Novi rizik' : 'Uredi rizik'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naslov *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opis',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(
                    labelText: 'Težina',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DevelopmentRiskLevels.low,
                    DevelopmentRiskLevels.medium,
                    DevelopmentRiskLevels.high,
                    DevelopmentRiskLevels.critical,
                  ]
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.riskSeverityLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialog(() {
                        severity = v;
                        if (risk == null &&
                            v == DevelopmentRiskLevels.critical) {
                          blocksRelease = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentRiskStatuses.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.riskStatusLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => status = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Kategorija (opc.)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('—'),
                    ),
                    ...DevelopmentRiskCategories.all.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(DevelopmentDisplay.riskCategoryLabel(c)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialog(() => category = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blokira release'),
                  value: blocksRelease,
                  onChanged: (v) => setDialog(() => blocksRelease = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mitigacija / napomena',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      titleCtrl.dispose();
      descCtrl.dispose();
      mitCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final mit = mitCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    mitCtrl.dispose();

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslov je obavezan.')),
        );
      }
      return;
    }

    try {
      if (risk == null) {
        await service.createRiskViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          severity: severity,
          status: status,
          category: category,
          blocksRelease: blocksRelease,
          mitigationNote: mit.isEmpty ? null : mit,
        );
      } else {
        await service.updateRiskViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          riskId: risk.id,
          patch: {
            'title': title,
            'description': desc.isEmpty ? null : desc,
            'severity': severity,
            'status': status,
            'category': category,
            'blocksRelease': blocksRelease,
            'mitigationNote': mit.isEmpty ? null : mit,
          },
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rizik spremljen.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DevelopmentProjectService();

    return _SectionCard(
      title: 'Rizici',
      children: [
        if (_canMutate)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openRiskEditor(context, service),
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Novi rizik'),
            ),
          ),
        if (_canMutate) const SizedBox(height: 12),
        StreamBuilder<List<DevelopmentProjectRiskModel>>(
          stream: service.watchRisks(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Rizici trenutno nisu dostupni.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return Text(
                'Još nema evidentiranih rizika.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: list.map((r) {
                final cat = (r.category ?? '').trim();
                final sub = [
                  DevelopmentDisplay.riskSeverityLabel(r.severity),
                  DevelopmentDisplay.riskStatusLabel(r.status),
                  if (r.blocksRelease) 'blokira release',
                  if (cat.isNotEmpty) DevelopmentDisplay.riskCategoryLabel(cat),
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.title),
                  subtitle: Text(
                    sub,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _canMutate
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openRiskEditor(context, service, risk: r),
                        )
                      : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
