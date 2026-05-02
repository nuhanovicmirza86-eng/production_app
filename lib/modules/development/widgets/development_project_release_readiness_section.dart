// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_permissions.dart';

/// Heuristička provjera spremnosti za release (Callable §10 — bez povezivanja na proizvod).
class DevelopmentProjectReleaseReadinessSection extends StatefulWidget {
  const DevelopmentProjectReleaseReadinessSection({
    super.key,
    required this.companyData,
    required this.project,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;

  @override
  State<DevelopmentProjectReleaseReadinessSection> createState() =>
      _DevelopmentProjectReleaseReadinessSectionState();
}

class _DevelopmentProjectReleaseReadinessSectionState
    extends State<DevelopmentProjectReleaseReadinessSection> {
  String _targetGate = DevelopmentGateCodes.g8;

  bool get _canRun => DevelopmentPermissions.canCheckDevelopmentReleaseReadiness(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  Future<void> _runCheck() async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Provjera na poslužitelju…')),
          ],
        ),
      ),
    );

    try {
      final service = DevelopmentProjectService();
      final res = await service.checkReleaseReadinessViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: widget.project.id,
        targetGate: _targetGate,
      );
      nav.pop();
      if (!mounted) return;

      final body = res.ok
          ? Text(
              'Nema detektovanih blokada za $_targetGate prema trenutnim pravilima.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Blokade (${res.blockers.length}):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...res.blockers.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${b['message'] ?? b.toString()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            );

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(res.ok ? 'Spremnost ($_targetGate)' : 'Blokade ($_targetGate)'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                body,
                if (res.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    res.notes.join('\n'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori'),
            ),
          ],
        ),
      );
    } catch (e) {
      nav.pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provjera: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRun) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spremnost za release',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Heuristička provjera (rizici, izmjene, faza Gate, čekajuća odobrenja). '
              'Ne zamjenjuje povezivanje na proizvod / nalog.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetGate,
                    decoration: const InputDecoration(
                      labelText: 'Referentni Gate',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DevelopmentGateCodes.ordered
                        .map(
                          (g) => DropdownMenuItem(value: g, child: Text(g)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetGate = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _runCheck,
                  child: const Text('Provjeri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
