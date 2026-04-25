import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_settlement_status.dart';

/// Prikaz statusa obrade mjeseca (vrijednost iz Firestore / [WorkTimeSettlementStatus]).
class WorkTimeSettlementStatusBadge extends StatelessWidget {
  const WorkTimeSettlementStatusBadge({
    super.key,
    required this.wire,
    this.compact = false,
  });

  final String wire;
  final bool compact;

  static String labelHr(String s) {
    switch (s) {
      case WorkTimeSettlementStatus.draft:
        return 'Nacrt';
      case WorkTimeSettlementStatus.needsReview:
        return 'Za pregled (greške)';
      case WorkTimeSettlementStatus.readyForApproval:
        return 'Spremno za odobrenje';
      case WorkTimeSettlementStatus.approved:
        return 'Odobreno';
      case WorkTimeSettlementStatus.locked:
        return 'Zaključano';
      case WorkTimeSettlementStatus.exported:
        return 'Poslano (obračun)';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = _colors(scheme);
    if (compact) {
      return Chip(
        label: Text(
          labelHr(wire),
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          labelHr(wire),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  (Color, Color) _colors(ColorScheme scheme) {
    switch (wire) {
      case WorkTimeSettlementStatus.draft:
        return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
      case WorkTimeSettlementStatus.needsReview:
        return (scheme.errorContainer, scheme.onErrorContainer);
      case WorkTimeSettlementStatus.readyForApproval:
        return (scheme.tertiaryContainer, scheme.onTertiaryContainer);
      case WorkTimeSettlementStatus.approved:
        return (scheme.primaryContainer, scheme.onPrimaryContainer);
      case WorkTimeSettlementStatus.locked:
        return (scheme.secondaryContainer, scheme.onSecondaryContainer);
      case WorkTimeSettlementStatus.exported:
        return (scheme.primary, scheme.onPrimary);
      default:
        return (scheme.surfaceContainerHighest, scheme.onSurface);
    }
  }
}
