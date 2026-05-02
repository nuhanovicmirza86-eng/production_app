// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../models/development_project_task_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Lista zadatka + Callable create/update.
class DevelopmentProjectTasksSection extends StatelessWidget {
  const DevelopmentProjectTasksSection({
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

  Future<void> _openTaskEditor(
    BuildContext context,
    DevelopmentProjectService service, {
    DevelopmentProjectTaskModel? task,
  }) async {
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    final descCtrl = TextEditingController(text: task?.description ?? '');
    var status = task?.status ?? DevelopmentTaskStatuses.open;
    if (!DevelopmentTaskStatuses.all.contains(status)) {
      status = DevelopmentTaskStatuses.open;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(task == null ? 'Novi zadatak' : 'Uredi zadatak'),
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
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentTaskStatuses.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(DevelopmentDisplay.taskStatusLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => status = v);
                  },
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
      return;
    }

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslov je obavezan.')),
        );
      }
      return;
    }

    try {
      if (task == null) {
        await service.createTaskViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          status: status,
        );
      } else {
        await service.updateTaskViaCallable(
          companyId: _companyId,
          plantKey: _plantKey,
          projectId: project.id,
          taskId: task.id,
          patch: {
            'title': title,
            'description': desc.isEmpty ? null : desc,
            'status': status,
          },
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zadatak spremljen.')),
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
      title: 'Zadaci',
      children: [
        if (_canMutate)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openTaskEditor(context, service),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Novi zadatak'),
            ),
          ),
        if (_canMutate) const SizedBox(height: 12),
        StreamBuilder<List<DevelopmentProjectTaskModel>>(
          stream: service.watchTasks(project.id),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Zadaci trenutno nisu dostupni.',
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
                'Još nema zadataka.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: list.map((t) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.title),
                  subtitle: Text(
                    DevelopmentDisplay.taskStatusLabel(t.status),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _canMutate
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openTaskEditor(context, service, task: t),
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
