import 'package:flutter/material.dart';

import '../helpers/aps_capacity_load_helper.dart';

/// Oznaka opterećenja: OK / Upozorenje / Usko grlo.
class ApsCapacityLoadBadge extends StatelessWidget {
  const ApsCapacityLoadBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final ApsCapacityLoadLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (level) {
      ApsCapacityLoadLevel.ok => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      ApsCapacityLoadLevel.warning => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        Icons.warning_amber_outlined,
      ),
      ApsCapacityLoadLevel.bottleneck => (
        cs.errorContainer,
        cs.onErrorContainer,
        Icons.report_outlined,
      ),
    };

    final label = ApsCapacityLoadHelper.label(level);
    if (compact) {
      return Chip(
        avatar: Icon(icon, size: 16, color: fg),
        label: Text(label, style: TextStyle(color: fg, fontSize: 12)),
        backgroundColor: bg,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
