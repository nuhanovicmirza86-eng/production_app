// ignore_for_file: deprecated_member_use
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/development_project_approval_model.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Zahtjevi za odobrenje (Gate / dokument) — Callable create/update.
class DevelopmentProjectApprovalsSection extends StatelessWidget {
  const DevelopmentProjectApprovalsSection({
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

  bool get _canPropose =>
      DevelopmentPermissions.canMutateDevelopmentApprovals(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  bool get _canDecide => DevelopmentPermissions.canDecideDevelopmentApproval(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  bool _canWithdraw(DevelopmentProjectApprovalModel a) {
    return DevelopmentPermissions.canWithdrawDevelopmentApproval(
      role: companyData['role']?.toString(),
      companyData: companyData,
      createdByUid: a.createdBy,
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  Future<void> _openApprovalEditor(
    BuildContext context,
    DevelopmentProjectService service, {
    DevelopmentProjectApprovalModel? approval,
  }) async {
    final titleCtrl = TextEditingController(text: approval?.title ?? '');
    final descCtrl = TextEditingController(text: approval?.description ?? '');
    final docIdCtrl =
        TextEditingController(text: approval?.linkedDocumentId ?? '');
    var kind = approval?.approvalKind ?? DevelopmentApprovalKinds.general;
    if (!DevelopmentApprovalKinds.all.contains(kind)) {
      kind = DevelopmentApprovalKinds.general;
    }
    String? linkedGate = approval?.linkedGate;
    if (linkedGate != null && linkedGate.isEmpty) linkedGate = null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(approval == null ? 'Novi zahtjev' : 'Uredi zahtjev'),
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
                  items: DevelopmentApprovalKinds.all
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(DevelopmentDisplay.approvalKindLabel(k)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => kind = v);
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
      return;
    }

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final docId = docIdCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    docIdCtrl.dispose();

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslov je obavezan.')),
        );
      }
      return;
    }

    try {
      if (approval == null) {
        await service.createApprovalViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          approvalKind: kind,
          linkedGate: linkedGate,
          linkedDocumentId: docId.isEmpty ? null : docId,
        );
      } else {
        await service.updateApprovalViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          approvalId: approval.id,
          patch: {
            'title': title,
            'description': desc.isEmpty ? null : desc,
            'approvalKind': kind,
            'linkedGate': linkedGate,
            'linkedDocumentId': docId.isEmpty ? null : docId,
          },
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahtjev spremljen.')),
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

  Future<void> _decide(
    BuildContext context,
    DevelopmentProjectService service,
    DevelopmentProjectApprovalModel approval,
    bool approved,
  ) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? 'Odobri zahtjev' : 'Odbij zahtjev'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Napomena odluke (opc.)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Potvrdi'),
          ),
        ],
      ),
    );
    if (ok != true) {
      noteCtrl.dispose();
      return;
    }
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();

    try {
      await service.updateApprovalViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: project.id,
        approvalId: approval.id,
        patch: {
          'status':
              approved ? DevelopmentApprovalStatuses.approved : DevelopmentApprovalStatuses.rejected,
          if (note.isNotEmpty) 'decisionNote': note,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Zahtjev odobren.' : 'Zahtjev odbijen.'),
          ),
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

  Future<void> _withdraw(
    BuildContext context,
    DevelopmentProjectService service,
    DevelopmentProjectApprovalModel approval,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Povuci zahtjev'),
        content: const Text(
          'Zahtjev će biti označen kao povučen. Nastaviti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da, povuci'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await service.updateApprovalViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: project.id,
        approvalId: approval.id,
        patch: {
          'status': DevelopmentApprovalStatuses.withdrawn,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahtjev povučen.')),
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
      title: 'Odobrenja',
      children: [
        if (_canPropose)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openApprovalEditor(context, service),
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('Novi zahtjev'),
            ),
          ),
        if (_canPropose) const SizedBox(height: 12),
        StreamBuilder<List<DevelopmentProjectApprovalModel>>(
          stream: service.watchApprovals(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Zahtjevi trenutno nisu dostupni.',
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
                'Još nema zahtjeva za odobrenje.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: list.map((a) {
                final gate = (a.linkedGate ?? '').trim();
                final doc = (a.linkedDocumentId ?? '').trim();
                final extras = <String>[
                  DevelopmentDisplay.approvalKindLabel(a.approvalKind),
                  DevelopmentDisplay.approvalStatusLabel(a.status),
                  if (gate.isNotEmpty) gate,
                  if (doc.isNotEmpty) 'dok. $doc',
                ];
                final pending = a.status == DevelopmentApprovalStatuses.pending;
                final showMenu = pending &&
                    (_canPropose || _canDecide || _canWithdraw(a));

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.title),
                  subtitle: Text(
                    extras.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: showMenu
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            switch (v) {
                              case 'edit':
                                _openApprovalEditor(
                                  context,
                                  service,
                                  approval: a,
                                );
                              case 'approve':
                                _decide(context, service, a, true);
                              case 'reject':
                                _decide(context, service, a, false);
                              case 'withdraw':
                                _withdraw(context, service, a);
                              default:
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (_canPropose && pending)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Uredi'),
                              ),
                            if (_canDecide && pending) ...[
                              const PopupMenuItem(
                                value: 'approve',
                                child: Text('Odobri'),
                              ),
                              const PopupMenuItem(
                                value: 'reject',
                                child: Text('Odbij'),
                              ),
                            ],
                            if (_canWithdraw(a) && pending)
                              const PopupMenuItem(
                                value: 'withdraw',
                                child: Text('Povuci'),
                              ),
                          ],
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
