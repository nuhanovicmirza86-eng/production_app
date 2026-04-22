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
