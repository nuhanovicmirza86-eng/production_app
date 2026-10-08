import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/operonix_premium_iconography.dart';
import '../../../../core/visual/premium/premium_widgets.dart';

/// Web Premium home shortcut. Compact horizontal row. Not used on Android.
class ProductionWebPremiumActionTile extends StatelessWidget {
  static const double iconExtent = 46;

  final IconData icon;
  final String title;
  final String subtitle;
  final String? noticeText;
  final VoidCallback onTap;

  const ProductionWebPremiumActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.noticeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = tokens.moduleAccent;
    final glyph = OperonixPremiumIconography.resolve(title: title, icon: icon);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: tokens.surfaceElevated,
      shape: tokens.cardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: iconExtent,
                height: iconExtent,
                child: PremiumIconBadge(
                  icon: icon,
                  glyph: glyph,
                  role: OperonixPremiumIconography.roleFor(glyph),
                  size: iconExtent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.2,
                        color: tokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: tokens.secondaryText),
                    ),
                    if (noticeText != null && noticeText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                noticeText!,
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: accent.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
