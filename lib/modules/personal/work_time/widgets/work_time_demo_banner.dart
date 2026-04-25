import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Diskretna napomena za module u izgradnji (bez tehničkih putanja u korisničkom tekstu).
class WorkTimeDemoBanner extends StatelessWidget {
  const WorkTimeDemoBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: compact ? 18 : 22,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact
                    ? 'Brojke ovdje mogu biti probni prikaz.'
                    : 'Brojke i statusi ovdje mogu biti probni, dok se u potpunosti ne usklade s vašom evidencijom.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
