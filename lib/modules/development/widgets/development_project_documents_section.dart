// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/development_project_document_model.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Lista dokumenata (metadata) + Callable create/update.
class DevelopmentProjectDocumentsSection extends StatelessWidget {
  const DevelopmentProjectDocumentsSection({
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

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentDocuments(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  Future<void> _openDocumentEditor(
    BuildContext context,
    DevelopmentProjectService service, {
    DevelopmentProjectDocumentModel? doc,
  }) async {
    final titleCtrl = TextEditingController(text: doc?.title ?? '');
    final descCtrl = TextEditingController(text: doc?.description ?? '');
    final extCtrl = TextEditingController(text: doc?.externalRef ?? '');
    var docType = doc?.docType ?? DevelopmentDocumentTypes.other;
    if (!DevelopmentDocumentTypes.all.contains(docType)) {
      docType = DevelopmentDocumentTypes.other;
    }
    var status = doc?.status ?? DevelopmentDocumentStatuses.draft;
    if (!DevelopmentDocumentStatuses.all.contains(status)) {
      status = DevelopmentDocumentStatuses.draft;
    }
    String? linkedGate = doc?.linkedGate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(doc == null ? 'Novi dokument' : 'Uredi dokument'),
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
                    labelText: 'Opis / napomena',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(
                    labelText: 'Tip',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentDocumentTypes.all
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(DevelopmentDisplay.documentTypeLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => docType = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentDocumentStatuses.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.documentStatusLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => status = v);
                  },
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
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(g),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialog(() => linkedGate = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: extCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vanjska referenca / poveznica (opc.)',
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
      extCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final ext = extCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    extCtrl.dispose();

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslov je obavezan.')),
        );
      }
      return;
    }

    try {
      if (doc == null) {
        await service.createDocumentViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          docType: docType,
          status: status,
          linkedGate: linkedGate,
          externalRef: ext.isEmpty ? null : ext,
        );
      } else {
        await service.updateDocumentViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          documentId: doc.id,
          patch: {
            'title': title,
            'description': desc.isEmpty ? null : desc,
            'docType': docType,
            'status': status,
            'linkedGate': linkedGate,
            'externalRef': ext.isEmpty ? null : ext,
          },
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokument spremljen.')),
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
      title: 'Dokumenti (evidencija)',
      children: [
        Text(
          'Metadata u aplikaciji; datoteke mogu biti na vanjskoj poveznici.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_canMutate)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openDocumentEditor(context, service),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Novi dokument'),
            ),
          ),
        if (_canMutate) const SizedBox(height: 12),
        StreamBuilder<List<DevelopmentProjectDocumentModel>>(
          stream: service.watchDocuments(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Dokumenti trenutno nisu dostupni.',
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
                'Još nema evidentiranih dokumenata.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: list.map((d) {
                final gate = (d.linkedGate ?? '').trim();
                final sub = [
                  DevelopmentDisplay.documentTypeLabel(d.docType),
                  DevelopmentDisplay.documentStatusLabel(d.status),
                  if (gate.isNotEmpty) gate,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.title),
                  subtitle: Text(
                    sub,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _canMutate
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openDocumentEditor(context, service, doc: d),
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
