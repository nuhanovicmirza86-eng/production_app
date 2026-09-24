import 'package:flutter/material.dart';

import '../models/ncr_action_history_models.dart';

/// M1-I13-E — kompaktan poslovni banner rizika na NCR detalju (bez AI).
class NcrActionRiskBanner extends StatelessWidget {
  const NcrActionRiskBanner({
    super.key,
    required this.risk,
    this.loading = false,
  });

  final NcrActionRiskSignalsResult? risk;
  final bool loading;

  static String riskLevelLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'none':
        return 'Nema rizika';
      case 'low':
        return 'Nizak rizik';
      case 'medium':
        return 'Srednji rizik';
      case 'high':
        return 'Visok rizik';
      default:
        return 'Nema rizika';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 4,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (risk == null) return const SizedBox.shrink();

    final level = risk!.riskLevel.trim().toLowerCase();
    final title = riskLevelLabel(level);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final style = _styleForLevel(level, scheme);
    final signalLabels = risk!.signals
        .map((s) => s.label.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Material(
      color: style.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: style.border, width: style.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(style.icon, color: style.iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: style.titleColor,
                    ),
                  ),
                ),
              ],
            ),
            if (signalLabels.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...signalLabels.map(
                (label) => Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: textTheme.bodySmall?.copyWith(
                          color: style.bodyColor,
                          height: 1.35,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          label,
                          style: textTheme.bodySmall?.copyWith(
                            color: style.bodyColor,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (level == 'none') ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Nema aktivnih signala rizika na ovoj neusaglašenosti.',
                  style: textTheme.bodySmall?.copyWith(
                    color: style.bodyColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _BannerStyle _styleForLevel(String level, ColorScheme scheme) {
    switch (level) {
      case 'high':
        return _BannerStyle(
          background: scheme.errorContainer.withValues(alpha: 0.45),
          border: scheme.error.withValues(alpha: 0.55),
          borderWidth: 1.5,
          icon: Icons.warning_amber_rounded,
          iconColor: scheme.error,
          titleColor: scheme.onErrorContainer,
          bodyColor: scheme.onErrorContainer.withValues(alpha: 0.92),
        );
      case 'medium':
        return _BannerStyle(
          background: scheme.tertiaryContainer.withValues(alpha: 0.55),
          border: scheme.tertiary.withValues(alpha: 0.5),
          borderWidth: 1.5,
          icon: Icons.info_outline,
          iconColor: scheme.tertiary,
          titleColor: scheme.onTertiaryContainer,
          bodyColor: scheme.onTertiaryContainer.withValues(alpha: 0.92),
        );
      case 'low':
        return _BannerStyle(
          background: scheme.secondaryContainer.withValues(alpha: 0.35),
          border: scheme.outlineVariant.withValues(alpha: 0.7),
          borderWidth: 1,
          icon: Icons.notifications_none_outlined,
          iconColor: scheme.secondary,
          titleColor: scheme.onSecondaryContainer,
          bodyColor: scheme.onSecondaryContainer.withValues(alpha: 0.9),
        );
      default:
        return _BannerStyle(
          background: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: scheme.outlineVariant.withValues(alpha: 0.45),
          borderWidth: 1,
          icon: Icons.verified_outlined,
          iconColor: scheme.primary.withValues(alpha: 0.75),
          titleColor: scheme.onSurface,
          bodyColor: scheme.onSurfaceVariant,
        );
    }
  }
}

class _BannerStyle {
  const _BannerStyle({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.icon,
    required this.iconColor,
    required this.titleColor,
    required this.bodyColor,
  });

  final Color background;
  final Color border;
  final double borderWidth;
  final IconData icon;
  final Color iconColor;
  final Color titleColor;
  final Color bodyColor;
}
