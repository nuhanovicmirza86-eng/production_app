import 'package:flutter/material.dart';

import '../../production_orders/models/production_order_model.dart';

String formatPlanningDueDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day}.${l.month}.${l.year}';
}

String formatPlanningCustomerLine(ProductionOrderModel o) {
  final a = o.customerName?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = o.sourceCustomerName?.trim();
  if (b != null && b.isNotEmpty) return b;
  return '—';
}

/// Lijevi rub kartice: nema stroja → crveno; rok prije 3 dana → žuto; inače zeleno.
Color planningOrderRiskStripeColor(ProductionOrderModel o) {
  if ((o.machineId ?? '').trim().isEmpty) {
    return Colors.red;
  }
  final due = o.requestedDeliveryDate;
  if (due != null && due.difference(DateTime.now()).inDays < 3) {
    return Colors.amber;
  }
  return Colors.green;
}

TextStyle? planningOrderExcludedStyle(ThemeData t) {
  return t.textTheme.bodySmall?.copyWith(
    color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    decoration: TextDecoration.lineThrough,
    decorationColor: t.colorScheme.onSurfaceVariant,
  );
}

/// Ikone (rizik / stroj) — usklađeno s [planningOrderRiskStripeColor], za tablicu i kartice.
Widget planningOrderSignalRow(ThemeData t, ProductionOrderModel o) {
  final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
  final due = o.requestedDeliveryDate;
  final lateRisk = due != null && due.difference(DateTime.now()).inDays < 3;
  final children = <Widget>[];
  if (!hasMachine) {
    children.add(
      Tooltip(
        message: 'Nema dodijeljenog stroja na nalogu',
        child: Icon(Icons.precision_manufacturing_outlined, size: 18, color: t.colorScheme.error),
      ),
    );
  }
  if (lateRisk) {
    children.add(
      Tooltip(
        message: 'Rizik roka: isporuka u manje od 3 dana',
        child: Icon(Icons.event_busy, size: 18, color: Colors.amber.shade800),
      ),
    );
  }
  if (children.isEmpty) {
    children.add(
      Tooltip(
        message: 'Nema posebnog signala (stroj + rok u redu)',
        child: Icon(Icons.check_circle_outline, size: 16, color: t.colorScheme.outline),
      ),
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        children[i],
      ],
    ],
  );
}
