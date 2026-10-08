import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';

/// Web Classic home tile. Geometry matches Maintenance web Classic.
///
/// [MaintenanceDashboardHomeModulesView.webMaxCrossAxisExtent] = 132
/// [MaintenanceDashboardHomeModulesView.iconGridChildAspectRatio] = 0.82
/// [MaintenanceDashboardHomeModulesView.tileGap] = 10
/// [MaintenanceDashboardIconGridTile] icon box 52, glyph 28,
/// padding 8×12, title gap 8, font 12 / w800 / height 1.2.
class ProductionClassicActionTile extends StatelessWidget {
  static const double maxCrossAxisExtent = 132;
  static const double childAspectRatio = 0.82;
  static const double gridSpacing = 10;
  static const double iconExtent = 52;
  static const double iconSize = 28;
  static const double titleGap = 8;

  final IconData icon;
  final String title;
  final String? noticeText;
  final VoidCallback onTap;

  const ProductionClassicActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.noticeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = tokens.moduleAccent;
    final hasNotice = noticeText != null && noticeText!.trim().isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
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
                    width: iconExtent,
                    height: iconExtent,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(icon, size: iconSize, color: accent),
                  ),
                  if (hasNotice)
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
              const SizedBox(height: titleGap),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2,
                  color: tokens.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
