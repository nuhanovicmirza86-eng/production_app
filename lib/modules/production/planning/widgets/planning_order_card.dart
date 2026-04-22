import 'package:flutter/material.dart';

import '../../production_orders/models/production_order_model.dart';
import '../planning_session_controller.dart';
import 'planning_order_display_helpers.dart';

/// Kompaktna kartica jednog naloga u poolu (alternativa retku u tablici).
class PlanningOrderCard extends StatelessWidget {
  const PlanningOrderCard({
    super.key,
    required this.order,
    required this.session,
  });

  final ProductionOrderModel order;
  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ex = session.excludedOrderIds.contains(order.id);
    final hasMachine = (order.machineId ?? '').trim().isNotEmpty;
    final rem = (order.plannedQty - order.producedGoodQty).clamp(0, double.infinity);
    final remStr = rem.toStringAsFixed(rem == rem.roundToDouble() ? 0 : 1);
    final sel = !ex && session.selectedOrder?.id == order.id;
    final exStyle = ex ? planningOrderExcludedStyle(t) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      elevation: sel ? 1.5 : 0.5,
      color: sel ? t.colorScheme.surfaceContainerHighest : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ex || session.isLocked ? null : () => session.setSelectedOrder(order),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: planningOrderRiskStripeColor(order)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            visualDensity: VisualDensity.compact,
                            value: ex ? false : session.selectedOrderIds.contains(order.id),
                            onChanged: ex || session.isLocked
                                ? null
                                : (v) => session.toggleOrderSelected(order.id, v),
                          ),
                          Expanded(
                            child: Text(
                              order.productionOrderCode,
                              style: t.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: exStyle?.color,
                                decoration: exStyle?.decoration,
                                decorationColor: exStyle?.decorationColor,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            enabled: !session.isLocked,
                            onSelected: (v) {
                              if (v == 'ex') {
                                session.excludeFromPlan(order.id);
                              } else if (v == 'in') {
                                session.includeInPlan(order.id);
                              }
                            },
                            itemBuilder: (c) => [
                              if (!ex) const PopupMenuItem(value: 'ex', child: Text('Isključi iz plana')),
                              if (ex) const PopupMenuItem(value: 'in', child: Text('Uključi u plan')),
                            ],
                            child: const Icon(Icons.more_vert, size: 22),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          order.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyMedium?.merge(exStyle),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip(
                            t,
                            '$remStr ${order.unit}',
                            Icons.scale,
                            exStyle,
                          ),
                          _chip(
                            t,
                            'Rok ${formatPlanningDueDate(order.requestedDeliveryDate)}',
                            Icons.event,
                            exStyle,
                          ),
                          _chip(
                            t,
                            formatPlanningCustomerLine(order),
                            Icons.business_outlined,
                            exStyle,
                          ),
                          _chip(
                            t,
                            'Routing ${order.routingId.isEmpty ? "—" : order.routingId}',
                            Icons.alt_route,
                            exStyle,
                          ),
                          _chip(
                            t,
                            ex
                                ? 'Isključen'
                                : (hasMachine ? 'Stroj: da' : 'Stroj: ne'),
                            hasMachine || ex ? Icons.precision_manufacturing : Icons.warning_amber_outlined,
                            ex
                                ? exStyle
                                : (hasMachine
                                    ? null
                                    : TextStyle(color: t.colorScheme.error, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData t, String text, IconData icon, TextStyle? merge) {
    return Chip(
      avatar: Icon(icon, size: 16, color: merge?.color ?? t.colorScheme.onSurfaceVariant),
      label: Text(text, style: t.textTheme.labelSmall?.merge(merge)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
