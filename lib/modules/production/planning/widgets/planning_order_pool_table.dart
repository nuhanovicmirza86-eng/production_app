import 'dart:async';

import 'package:flutter/material.dart';

import '../../production_orders/models/production_order_model.dart';
import '../planning_order_pool_view_mode.dart';
import '../planning_session_controller.dart';
import '../services/planning_engine_service.dart';
import '../services/planning_pool_view_prefs.dart';
import 'planning_order_card.dart';
import 'planning_order_display_helpers.dart';

/// Panel order poola: pretraga, gumbi odabira, prikaz **tablica** ili **kartice**.
class PlanningOrderPoolTable extends StatefulWidget {
  const PlanningOrderPoolTable({super.key, required this.session});

  final PlanningSessionController session;

  @override
  State<PlanningOrderPoolTable> createState() => _PlanningOrderPoolTableState();
}

class _PlanningOrderPoolTableState extends State<PlanningOrderPoolTable> {
  PlanningOrderPoolViewMode _view = PlanningOrderPoolViewMode.table;

  PlanningSessionController get session => widget.session;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedView());
  }

  Future<void> _loadSavedView() async {
    final m = await PlanningPoolViewPrefs.read(
      session.companyId,
      session.plantKey,
    );
    if (!mounted || m == null) return;
    setState(() => _view = m);
  }

  Future<void> _persistView(PlanningOrderPoolViewMode m) async {
    await PlanningPoolViewPrefs.write(session.companyId, session.plantKey, m);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Text(
                  'Order pool',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                SegmentedButton<PlanningOrderPoolViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: PlanningOrderPoolViewMode.table,
                      label: Text('Tablica'),
                      icon: Icon(Icons.table_rows, size: 18),
                    ),
                    ButtonSegment(
                      value: PlanningOrderPoolViewMode.cards,
                      label: Text('Kartice'),
                      icon: Icon(Icons.view_agenda_outlined, size: 18),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) async {
                    if (s.isEmpty) return;
                    final next = s.first;
                    setState(() => _view = next);
                    await _persistView(next);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Pretraga (šifra, proizvod…)',
              ),
              onChanged: session.setSearchQuery,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: session.isLocked ? null : session.selectAllInPool,
                child: const Text('Sve'),
              ),
              TextButton(
                onPressed:
                    session.isLocked || session.searchQuery.trim().isEmpty
                    ? null
                    : session.selectFiltered,
                child: const Text('+ filtrirane'),
              ),
              TextButton(
                onPressed:
                    session.isLocked || session.searchQuery.trim().isEmpty
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
                : _view == PlanningOrderPoolViewMode.table
                ? _OrderDataTable(session: session)
                : _OrderCardList(session: session),
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
            DataColumn(
              label: Text('Signali'),
              tooltip: 'Stroj, rok — isto kao lijevi rub (zeleno/žuto/crveno).',
            ),
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

class _OrderCardList extends StatelessWidget {
  const _OrderCardList({required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final list = session.ordersForTable;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      itemCount: list.length,
      itemBuilder: (context, i) {
        return PlanningOrderCard(order: list[i], session: session);
      },
    );
  }
}

DataRow _dataRow(
  BuildContext context,
  PlanningSessionController session,
  ProductionOrderModel o,
) {
  final t = Theme.of(context);
  final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
  final rem = (o.plannedQty - o.producedGoodQty).clamp(0, double.infinity);
  final due = o.requestedDeliveryDate;
  final ex = session.excludedOrderIds.contains(o.id);
  final exStyle = ex ? planningOrderExcludedStyle(t) : null;
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
      DataCell(
        Text(
          o.productionOrderCode,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: exStyle?.color,
            decoration: exStyle?.decoration,
            decorationColor: exStyle?.decorationColor,
          ),
        ),
      ),
      DataCell(planningOrderSignalRow(t, o)),
      DataCell(
        SizedBox(
          width: 120,
          child: Text(
            o.productName,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: exStyle,
          ),
        ),
      ),
      DataCell(
        Text(
          '${rem.toStringAsFixed(rem == rem.roundToDouble() ? 0 : 1)} ${o.unit}',
          style: exStyle,
        ),
      ),
      DataCell(Text(formatPlanningDueDate(due), style: exStyle)),
      DataCell(Text(formatPlanningCustomerLine(o), style: exStyle)),
      DataCell(
        Text(
          o.routingId.isEmpty ? '—' : o.routingId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: exStyle,
        ),
      ),
      DataCell(
        Text(
          ex ? 'isključen' : (hasMachine ? 'da' : 'ne'),
          style: ex
              ? exStyle
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
            if (!ex)
              const PopupMenuItem(
                value: 'ex',
                child: Text('Isključi iz plana'),
              ),
            if (ex)
              const PopupMenuItem(value: 'in', child: Text('Uključi u plan')),
          ],
          child: const Icon(Icons.more_vert, size: 20),
        ),
      ),
    ],
  );
}
