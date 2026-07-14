import 'package:flutter/material.dart';

import '../models/production_dashboard_layout.dart';

/// Odabir izgleda početnog zaslona: standardni ili ikonski prikaz.
class ProductionDashboardLayoutSelector extends StatelessWidget {
  final ProductionDashboardLayout value;
  final ValueChanged<ProductionDashboardLayout> onChanged;

  const ProductionDashboardLayoutSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Prikaz:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SegmentedButton<ProductionDashboardLayout>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ProductionDashboardLayout.standard,
                label: Text('Standardno'),
              ),
              ButtonSegment(
                value: ProductionDashboardLayout.iconGrid,
                label: Text('Ikone'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              onChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }
}
