import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';

/// Naslov bloka na početnom zaslonu: koji SaaS / poslovni modul pokriva kartice ispod.
class ProductionDashboardModuleGroupHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const ProductionDashboardModuleGroupHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: kOperonixProductionBrandGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
