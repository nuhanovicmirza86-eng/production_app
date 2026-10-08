import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';

/// Classic home shortcut. Vertical icon tile at the Maintenance Classic scale.
///
/// Maintenance reference (`MaintenanceDashboardHomeModulesView` /
/// `MaintenanceDashboardIconGridTile`):
/// web cell cap 132, aspect 0.82 (height 161), icon box 52, glyph 28.
/// Production cards are 180 wide so the longer titles fit on two lines.
class ProductionClassicActionTile extends StatelessWidget {
  /// Maintenance web cell cap is 132. Production titles such as
  /// "Način rada na ovom uređaju" need 156 px of text at the same 12 px
  /// weight, so the card is 180 px (padding 8 + 8) and still one compact tile.
  static const double maxTileWidth = 180;

  /// `MaintenanceDashboardHomeModulesView.iconGridChildAspectRatio`.
  static const double childAspectRatio = 0.82;

  /// Maintenance cell height at its 132 px cap: 132 / 0.82.
  static const double tileHeight = 132 / childAspectRatio;

  /// `MaintenanceDashboardIconGridTile` icon container.
  static const double iconExtent = 52;

  /// Glyph inside that container.
  static const double iconSize = 28;

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

  /// Same tile on every width. A narrower pane uses the pane; it does not grow.
  static double tileWidthFor(double contentWidth) {
    if (!contentWidth.isFinite || contentWidth <= 0) return maxTileWidth;
    if (contentWidth < maxTileWidth) return contentWidth;
    return maxTileWidth;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = tokens.moduleAccent;
    final hasNotice = noticeText != null && noticeText!.trim().isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
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
              const SizedBox(height: 8),
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
