import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';

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
    final accent = tokens.moduleAccent;
    final shape = tokens.isPremium
        ? tokens.cardShape
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
              width: 1.2,
            ),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: tokens.isPremium ? 0 : 1,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
