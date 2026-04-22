import 'package:flutter/material.dart';

import '../../production_orders/models/production_order_model.dart';
import '../planning_session_controller.dart';
import '../services/planning_engine_service.dart';

/// Tablica order poola: pretraga, gumbi odabira, [DataTable] s nalozima.
class PlanningOrderPoolTable extends StatelessWidget {
  const PlanningOrderPoolTable({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text('Order pool', style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Pretraga (šifra, proizvod…)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: session.setSearchQuery,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: session.isLocked ? null : session.selectAllInPool, child: const Text('Sve')),
              TextButton(
                onPressed: session.isLocked || session.searchQuery.trim().isEmpty
                    ? null
                    : session.selectFiltered,
                child: const Text('+ filtrirane'),
              ),
              TextButton(
                onPressed: session.isLocked || session.searchQuery.trim().isEmpty
                    ? null
                    : session.clearFilteredFromSelection,
                child: const Text('− filtrirane'),
              ),
              TextButton(
                onPressed: session.isLocked ? null : session.clearSelection,
                child: const Text('Očisti odabir'),
              ),
            ],
          ),
          Text(
            'Maks. ${PlanningEngineService.maxOrdersPerRun} naloga; isključeni ne ulaze u odabir.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Expanded(
            child: session.loadingPool
                ? const Center(child: CircularProgressIndicator())
                : session.poolError != null
                    ? Center(child: Text(session.poolError!))
                    : session.pool.isEmpty
                        ? const Center(child: Text('Nema naloga (pušten / u toku).'))
                        : _OrderDataTable(session: session),
          ),
        ],
      ),
    );
  }
}

class _OrderDataTable extends StatelessWidget {
  const _OrderDataTable({required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final list = session.ordersForTable;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          columns: const [
            DataColumn(label: Text('')),
            DataColumn(label: Text('Nalog')),
            DataColumn(label: Text('Proizvod')),
            DataColumn(label: Text('Kol.')),
            DataColumn(label: Text('Rok')),
            DataColumn(label: Text('Kupac')),
            DataColumn(label: Text('Routing')),
            DataColumn(label: Text('Izv. stroj')),
            DataColumn(label: Text('Akcije')),
          ],
          rows: list.map((o) => _dataRow(context, session, o)).toList(),
        ),
      ),
    );
  }
}

DataRow _dataRow(BuildContext context, PlanningSessionController session, ProductionOrderModel o) {
  final t = Theme.of(context);
  final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
  final rem = (o.plannedQty - o.producedGoodQty).clamp(0, double.infinity);
  final due = o.requestedDeliveryDate;
  final ex = session.excludedOrderIds.contains(o.id);
  final styleIfEx = ex
      ? t.textTheme.bodySmall?.copyWith(
          color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          decoration: TextDecoration.lineThrough,
          decorationColor: t.colorScheme.onSurfaceVariant,
        )
      : null;
  return DataRow(
    selected: !ex && session.selectedOrder?.id == o.id,
    onSelectChanged: ex || session.isLocked
        ? null
        : (v) {
            session.setSelectedOrder(o);
          },
    cells: [
      DataCell(
        Checkbox(
          value: ex ? false : session.selectedOrderIds.contains(o.id),
          onChanged: ex || session.isLocked ? null : (v) => session.toggleOrderSelected(o.id, v),
        ),
      ),
      DataCell(Text(
        o.productionOrderCode,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: styleIfEx?.color,
          decoration: styleIfEx?.decoration,
          decorationColor: styleIfEx?.decorationColor,
        ),
      )),
      DataCell(
        SizedBox(
          width: 120,
          child: Text(
            o.productName,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: styleIfEx,
          ),
        ),
      ),
      DataCell(Text('${rem.toStringAsFixed(rem == rem.roundToDouble() ? 0 : 1)} ${o.unit}', style: styleIfEx)),
      DataCell(Text(due != null ? _fmtDate(due) : '—', style: styleIfEx)),
      DataCell(
        Text(
          _customerLabel(o),
          style: styleIfEx,
        ),
      ),
      DataCell(
        Text(
          o.routingId.isEmpty ? '—' : o.routingId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styleIfEx,
        ),
      ),
      DataCell(
        Text(
          ex ? 'isključen' : (hasMachine ? 'da' : 'ne'),
          style: ex
              ? styleIfEx
              : TextStyle(
                  color: hasMachine ? null : t.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
        ),
      ),
      DataCell(
        PopupMenuButton<String>(
          enabled: !session.isLocked,
          onSelected: (v) {
            if (v == 'ex') {
              session.excludeFromPlan(o.id);
            } else if (v == 'in') {
              session.includeInPlan(o.id);
            }
          },
          itemBuilder: (c) => [
            if (!ex) const PopupMenuItem(value: 'ex', child: Text('Isključi iz plana')),
            if (ex) const PopupMenuItem(value: 'in', child: Text('Uključi u plan')),
          ],
          child: const Icon(Icons.more_vert, size: 20),
        ),
      ),
    ],
  );
}

String _fmtDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day}.${l.month}.${l.year}';
}

String _customerLabel(ProductionOrderModel o) {
  final a = o.customerName?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = o.sourceCustomerName?.trim();
  if (b != null && b.isNotEmpty) return b;
  return '—';
}
