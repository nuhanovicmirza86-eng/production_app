import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';

/// Kartica prečice na početnom zaslonu (standardni prikaz).
class ProductionDashboardActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? noticeText;
  final VoidCallback onTap;

  const ProductionDashboardActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.noticeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kOperonixProductionBrandGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kOperonixProductionBrandGreen.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                child: Icon(icon, color: kOperonixProductionBrandGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
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
                          color: kOperonixProductionBrandGreen.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: kOperonixProductionBrandGreen.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                              color: kOperonixProductionBrandGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                noticeText!,
                                style: TextStyle(
                                  color: kOperonixProductionBrandGreen
                                      .withValues(alpha: 0.95),
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
                color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
