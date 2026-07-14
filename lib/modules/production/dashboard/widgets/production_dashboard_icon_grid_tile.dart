import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';

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
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kOperonixProductionBrandGreen.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kOperonixProductionBrandGreen.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: kOperonixProductionBrandGreen,
                    ),
                  ),
                  if (badgeText != null && badgeText!.trim().isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kOperonixProductionBrandGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.notifications,
                          size: 10,
                          color: Colors.white,
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
