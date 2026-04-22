import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../production_orders/models/production_order_model.dart';
import '../planning_session_controller.dart';
import '../planning_workflow_scope.dart';
import '../services/planning_engine_service.dart';
import '../widgets/planning_precheck_panel.dart';
import '../widgets/planning_summary_kpi_row.dart';

/// Tab **Nalozi**: pool, filteri (placeholder), pre-check / konflikti, parametri motora.
class ProductionPlanningScreen extends StatelessWidget {
  const ProductionPlanningScreen({super.key});

  static const _wide = 1180.0;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _wide;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 44, child: _orderPoolTable(context, session)),
              Expanded(flex: 28, child: _filtersAndSummary(context, session)),
              Expanded(flex: 28, child: _precheck(context, session)),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            SizedBox(height: 420, child: _orderPoolTable(context, session)),
            const Divider(),
            SizedBox(height: 260, child: _filtersAndSummary(context, session)),
            const Divider(),
            SizedBox(height: 280, child: _precheck(context, session)),
          ],
        );
      },
    );
  }

  Widget _orderPoolTable(BuildContext context, PlanningSessionController session) {
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
                        : _table(context, session),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, PlanningSessionController session) {
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
          rows: list.map((o) => _row(context, session, o)).toList(),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, PlanningSessionController session, ProductionOrderModel o) {
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
            onChanged: ex || session.isLocked
                ? null
                : (v) => session.toggleOrderSelected(o.id, v),
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
            ex
                ? 'isključen'
                : (hasMachine ? 'da' : 'ne'),
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

  Widget _filtersAndSummary(BuildContext context, PlanningSessionController session) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Text('Filteri (placeholder)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            'Work centar, grupa strojeva, alat, proizvođač, kupac, opseg roka, samo mogući / rizik — '
            'povezivanje s master podacima u sljedećim iteracijama.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          PlanningSummaryKpiRow(session: session),
          const Divider(height: 20),
          Text('Parametri motora', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: session.perfController,
            enabled: !session.isLocked,
            decoration: const InputDecoration(
              labelText: 'Performansa (0–1)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: session.setupController,
            enabled: !session.isLocked,
            decoration: const InputDecoration(
              labelText: 'Setup (min)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: session.cycleController,
            enabled: !session.isLocked,
            decoration: const InputDecoration(
              labelText: 'Ciklus (s/kom) kad nema routingsa',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _precheck(BuildContext context, PlanningSessionController session) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: PlanningPrecheckPanel(
        pool: session.pool,
        result: session.result,
      ),
    );
  }
}
