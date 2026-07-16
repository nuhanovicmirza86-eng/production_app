import 'package:flutter/material.dart';

import '../models/worker_performance_ai_signals_models.dart';

/// Kratki read-only status normativa u tijelu ekrana (M2-G4-F2).
class WorkerAiNormativeContextCard extends StatelessWidget {
  const WorkerAiNormativeContextCard({
    super.key,
    required this.result,
  });

  final WorkerPerformanceAiSignalsResult result;

  static const _noNormStatus = 'Normativ nije pronađen.';
  static const _withNormStatus = 'Poređenje s normativom aktivno.';

  List<WorkerPerformanceAiNormativeRef> get _refs {
    if (result.normativeRefs.isNotEmpty) return result.normativeRefs;
    final primary = result.normativeContext?.primaryComparison;
    if (primary == null || !primary.normativeReady) return const [];
    return [
      WorkerPerformanceAiNormativeRef(
        normName: primary.matchedNormLabel == '—'
            ? null
            : primary.matchedNormLabel,
        normVersion: primary.normVersion,
        normativeStatus: primary.normativeStatus,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final ready = result.normativeReady;

    return Card(
      margin: EdgeInsets.zero,
      color: ready
          ? cs.primaryContainer.withValues(alpha: 0.18)
          : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ready ? _withNormStatus : _noNormStatus,
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (ready) ...[
              const SizedBox(height: 10),
              for (final ref in _refs) ...[
                _labelValue(context, 'Naziv normativa', ref.normName ?? '—'),
                const SizedBox(height: 6),
                _labelValue(
                  context,
                  'Verzija normativa',
                  ref.normVersion != null ? '${ref.normVersion}' : '—',
                ),
                const SizedBox(height: 6),
                _labelValue(
                  context,
                  'Status poređenja',
                  ref.statusLabel,
                ),
                const SizedBox(height: 6),
                _labelValue(
                  context,
                  'Referenca normativa',
                  ref.referenceLabel,
                ),
                if (ref != _refs.last) const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelValue(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: t.textTheme.labelMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
