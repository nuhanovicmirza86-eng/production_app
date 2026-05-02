// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/development_project_change_model.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Evidencija izmjena (ECO) — Callable create/update.
class DevelopmentProjectChangesSection extends StatelessWidget {
  const DevelopmentProjectChangesSection({
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

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentChanges(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  Future<void> _openChangeEditor(
    BuildContext context,
    DevelopmentProjectService service, {
    DevelopmentProjectChangeModel? change,
  }) async {
    final titleCtrl = TextEditingController(text: change?.title ?? '');
    final descCtrl = TextEditingController(text: change?.description ?? '');
    final docIdCtrl =
        TextEditingController(text: change?.linkedDocumentId ?? '');
    final extRefCtrl = TextEditingController(text: change?.externalRef ?? '');
    var kind = change?.changeKind ?? DevelopmentChangeKinds.eco;
    if (!DevelopmentChangeKinds.all.contains(kind)) {
      kind = DevelopmentChangeKinds.other;
    }
    var status = change?.status ?? DevelopmentChangeStatuses.open;
    if (!DevelopmentChangeStatuses.all.contains(status)) {
      status = DevelopmentChangeStatuses.open;
    }
    var blocksRelease = change?.blocksRelease ??
        (kind == DevelopmentChangeKinds.regulatory);
    String? linkedGate = change?.linkedGate;
    if (linkedGate != null && linkedGate.isEmpty) linkedGate = null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(change == null ? 'Nova izmjena (ECO)' : 'Uredi izmjenu'),
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
                  value: kind,
                  decoration: const InputDecoration(
                    labelText: 'Vrsta',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentChangeKinds.all
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(DevelopmentDisplay.changeKindLabel(k)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialog(() {
                        kind = v;
                        if (change == null && v == DevelopmentChangeKinds.regulatory) {
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
                  items: DevelopmentChangeStatuses.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.changeStatusLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => status = v);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blokira release'),
                  value: blocksRelease,
                  onChanged: (v) => setDialog(() => blocksRelease = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: linkedGate,
                  decoration: const InputDecoration(
                    labelText: 'Povezani Gate (opc.)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('—'),
                    ),
                    ...DevelopmentGateCodes.ordered.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g,
                        child: Text(g),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialog(() => linkedGate = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: docIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID dokumenta (opc.)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: extRefCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vanjski ref. / ECO broj (opc.)',
                    border: OutlineInputBorder(),
                  ),
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
      docIdCtrl.dispose();
      extRefCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final docId = docIdCtrl.text.trim();
    final ext = extRefCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    docIdCtrl.dispose();
    extRefCtrl.dispose();

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslov je obavezan.')),
        );
      }
      return;
    }

    try {
      if (change == null) {
        await service.createChangeViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          changeKind: kind,
          status: status,
          blocksRelease: blocksRelease,
          linkedGate: linkedGate,
          linkedDocumentId: docId.isEmpty ? null : docId,
          externalRef: ext.isEmpty ? null : ext,
        );
      } else {
        await service.updateChangeViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          changeId: change.id,
          patch: {
            'title': title,
            'description': desc.isEmpty ? null : desc,
            'changeKind': kind,
            'status': status,
            'blocksRelease': blocksRelease,
            'linkedGate': linkedGate,
            'linkedDocumentId': docId.isEmpty ? null : docId,
            'externalRef': ext.isEmpty ? null : ext,
          },
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izmjena spremljena.')),
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
      title: 'Izmjene (ECO)',
      children: [
        if (_canMutate)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openChangeEditor(context, service),
              icon: const Icon(Icons.change_circle_outlined),
              label: const Text('Nova izmjena'),
            ),
          ),
        if (_canMutate) const SizedBox(height: 12),
        StreamBuilder<List<DevelopmentProjectChangeModel>>(
          stream: service.watchChanges(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Izmjene trenutno nisu dostupne.',
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
                'Još nema evidentiranih izmjena.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: list.map((c) {
                final extras = <String>[
                  DevelopmentDisplay.changeKindLabel(c.changeKind),
                  DevelopmentDisplay.changeStatusLabel(c.status),
                  if (c.blocksRelease) 'blokira release',
                  if ((c.linkedGate ?? '').isNotEmpty) c.linkedGate!,
                  if ((c.externalRef ?? '').isNotEmpty) c.externalRef!,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.title),
                  subtitle: Text(
                    extras,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _canMutate
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openChangeEditor(context, service, change: c),
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
