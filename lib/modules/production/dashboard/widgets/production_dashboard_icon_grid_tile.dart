import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/operonix_premium_iconography.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import 'premium_home_icon_grid_metrics.dart';

/// Kompaktna ikona + naslov (ikonski prikaz početnog zaslona).
class ProductionDashboardIconGridTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badgeText;
  final VoidCallback onTap;

  const ProductionDashboardIconGridTile({
    super.key,
    required this.icon,
    required this.title,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final glyph = tokens.isPremium
        ? OperonixPremiumIconography.resolve(title: title, icon: icon)
        : null;
    final accent = tokens.isPremium
        ? PremiumIconAccent.of(OperonixPremiumIconography.roleFor(glyph), tokens)
        : tokens.moduleAccent;
    final shape = tokens.isPremium
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
              width: 1.2,
            ),
          );
    return Card(
      margin: tokens.isPremium ? EdgeInsets.zero : null,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: tokens.isPremium ? const Color(0x33000000) : null,
      color: tokens.isPremium ? tokens.surfaceElevated : null,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final lines = tokens.isPremium
                ? PremiumHomeIconGridMetrics.titleMaxLinesForTileWidth(
                    constraints.maxWidth,
                  )
                : 3;
            return Padding(
          padding: tokens.isPremium
              ? const EdgeInsets.fromLTRB(
                  PremiumHomeIconGridMetrics.tilePaddingH,
                  PremiumHomeIconGridMetrics.padTop,
                  PremiumHomeIconGridMetrics.tilePaddingH,
                  PremiumHomeIconGridMetrics.padBottom,
                )
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: tokens.isPremium
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            mainAxisAlignment: tokens.isPremium
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  tokens.isPremium
                      ? PremiumIconBadge(
                          icon: icon,
                          glyph: glyph,
                          role: OperonixPremiumIconography.roleFor(glyph),
                          variant: PremiumBadgeVariant.large,
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: accent,
                          ),
                        ),
                  if (badgeText != null && badgeText!.trim().isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.surface, width: 1.5),
                        ),
                        child: Icon(
                          Icons.notifications,
                          size: 10,
                          color: tokens.onAccent,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: tokens.isPremium ? PremiumHomeIconGridMetrics.titleGap : 8,
              ),
              Text(
                title,
                textAlign: tokens.isPremium ? TextAlign.start : TextAlign.center,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: tokens.isPremium
                      ? PremiumHomeIconGridMetrics.titleFontSize
                      : 12,
                  height: tokens.isPremium
                      ? PremiumHomeIconGridMetrics.titleLineHeight
                      : 1.2,
                  color: tokens.isPremium ? tokens.primaryText : null,
                ),
              ),
            ],
          ),
        );
          },
        ),
      ),
    );
  }
}
