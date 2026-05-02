// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../models/development_project_stage_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Stage-Gate lista + seed za stare projekte + Callable update.
class DevelopmentProjectStagesSection extends StatelessWidget {
  const DevelopmentProjectStagesSection({
    super.key,
    required this.companyData,
    required this.project,
    this.currentUserId,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;
  final String? currentUserId;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (companyData['plantKey'] ?? '').toString().trim();

  bool get _canEdit => DevelopmentPermissions.canMutateDevelopmentStages(
        role: companyData['role']?.toString(),
        companyData: companyData,
      );

  bool get _canSeed => DevelopmentPermissions.canSeedDevelopmentStages(
        role: companyData['role']?.toString(),
        companyData: companyData,
        project: project,
        currentUserId: currentUserId,
      );

  Future<void> _seedIfEmpty(BuildContext context) async {
    final service = DevelopmentProjectService();
    try {
      final seeded = await service.seedStagesIfEmptyViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: project.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              seeded ? 'Stage-Gate faze su kreirane.' : 'Faze već postoje.',
            ),
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

  Future<void> _openStageEditor(
    BuildContext context,
    DevelopmentProjectService service,
    DevelopmentProjectStageModel stage,
  ) async {
    final notesCtrl = TextEditingController(text: stage.notes ?? '');
    var status = stage.status;
    if (!DevelopmentStageStatuses.all.contains(status)) {
      status = DevelopmentStageStatuses.pending;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(stage.title.isEmpty ? stage.gateCode : stage.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status faze',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentStageStatuses.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.stageStatusLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => status = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Napomena',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
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
      notesCtrl.dispose();
      return;
    }
    final notes = notesCtrl.text.trim();
    notesCtrl.dispose();

    try {
      await service.updateStageViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: project.id,
        stageId: stage.id,
        patch: {
          'status': status,
          'notes': notes.isEmpty ? null : notes,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faza ažurirana.')),
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
      title: 'Stage-Gate (G0–G9)',
      children: [
        StreamBuilder<List<DevelopmentProjectStageModel>>(
          stream: service.watchStages(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Faze trenutno nisu dostupne.',
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nema zapisanih faza (legacy projekat ili greška).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_canSeed) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _seedIfEmpty(context),
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Inicijaliziraj Stage-Gate'),
                    ),
                  ],
                ],
              );
            }
            return Column(
              children: list.map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    child: Text(
                      s.gateCode.replaceAll('G', ''),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(
                    s.title.isEmpty ? s.gateCode : s.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    DevelopmentDisplay.stageStatusLabel(s.status),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _canEdit
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openStageEditor(context, service, s),
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
