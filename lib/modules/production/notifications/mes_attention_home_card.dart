import 'package:flutter/material.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';

import 'mes_inbox_attention.dart';

/// NOTIF-M1-C-UI-HOTFIX-01 — kartica na Početnoj. Klik otvara Obavijesti.
class MesAttentionHomeCard extends StatelessWidget {
  const MesAttentionHomeCard({
    super.key,
    required this.counts,
    required this.onOpenInbox,
  });

  final MesInboxAttentionCounts counts;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    if (!counts.hasAttention) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final chips = MesInboxAttention.homeCardChipLabels(counts);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onOpenInbox,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kOperonixProductionBrandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: kOperonixProductionBrandGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MesInboxAttention.homeCardTitle(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < chips.length; i++)
                            _AttentionCountChip(
                              label: chips[i],
                              emphasis: i == chips.length - 1 &&
                                  counts.waitingActionCount > 0,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      MesInboxAttention.homeCardOpenActionLabel(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: kOperonixProductionBrandGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionCountChip extends StatelessWidget {
  const _AttentionCountChip({
    required this.label,
    required this.emphasis,
  });

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasis
            ? kOperonixProductionBrandGreen.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasis
              ? kOperonixProductionBrandGreen
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Mali broj gore/desno na ikoni Obavijesti. Nikad `99+ / 50`.
class MesInboxNavBadge extends StatelessWidget {
  const MesInboxNavBadge({
    super.key,
    required this.counts,
    required this.outlined,
  });

  final MesInboxAttentionCounts counts;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      outlined ? Icons.notifications_outlined : Icons.notifications,
    );
    final label = MesInboxAttention.badgeLabel(counts);
    if (label.isEmpty) return icon;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          Positioned(
            right: -8,
            top: -6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.surface, width: 1),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
