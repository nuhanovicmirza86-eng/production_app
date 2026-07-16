import 'package:flutter/material.dart';

import '../models/worker_performance_ai_signals_models.dart';

/// Read-only prikaz normativnog konteksta za AI preporuke (M2-G4-F2).
class WorkerAiNormativeContextCard extends StatelessWidget {
  const WorkerAiNormativeContextCard({
    super.key,
    required this.result,
  });

  final WorkerPerformanceAiSignalsResult result;

  static const _noNormTitle =
      'Za odabrani period i kontekst nije pronađen aktivan normativ.';
  static const _noNormBody =
      'AI preporuke su zasnovane samo na stvarnim evidencijama rada.';
  static const _withNormTitle =
      'AI koristi aktivno poređenje s normativom.';

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
          ? cs.primaryContainer.withValues(alpha: 0.22)
          : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ready ? Icons.rule_outlined : Icons.rule_folder_outlined,
                  size: 22,
                  color: ready ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready ? _withNormTitle : _noNormTitle,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!ready) ...[
                        const SizedBox(height: 8),
                        Text(
                          _noNormBody,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (ready) ...[
              const SizedBox(height: 12),
              for (final ref in _refs) ...[
                if (_refs.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Reference normativa',
                      style: t.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _refBlock(context, ref),
                if (ref != _refs.last) const SizedBox(height: 10),
              ],
              if (_refs.isEmpty)
                Text(
                  result.normativeSummary.trim().isNotEmpty
                      ? result.normativeSummary.trim()
                      : 'Poređenje s normativom aktivno.',
                  style: t.textTheme.bodyMedium,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _refBlock(BuildContext context, WorkerPerformanceAiNormativeRef ref) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final statusColor = _statusColor(cs, ref.normativeStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelValue(context, 'Naziv normativa', ref.normName ?? '—'),
          const SizedBox(height: 6),
          _labelValue(
            context,
            'Verzija normativa',
            ref.normVersion != null ? '${ref.normVersion}' : '—',
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Status poređenja',
                  style: t.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(ref.statusLabel),
                side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                labelStyle: TextStyle(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _labelValue(context, 'Referenca normativa', ref.referenceLabel),
        ],
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

  Color _statusColor(ColorScheme cs, String? status) {
    switch (status) {
      case 'within_norm':
        return cs.primary;
      case 'below_speed_norm':
      case 'above_scrap_norm':
        return cs.tertiary;
      case 'mixed_warning':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }
}
