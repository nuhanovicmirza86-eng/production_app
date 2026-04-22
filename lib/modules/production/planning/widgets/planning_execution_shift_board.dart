import 'package:flutter/material.dart';

import '../../execution/services/production_execution_service.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/services/production_order_service.dart';
import '../models/scheduled_operation.dart';
import '../planning_session_controller.dart';
import '../services/planning_mes_today.dart';

typedef _BoardData = ({
  Map<String, ProductionOrderModel> orders,
  Map<String, List<Map<String, dynamic>>> mesByOrderId,
});

/// Smjenska tabla (plan): po stroju prva operacija u planu; „Stvarno” = očitano dobro u odnosu na plan na **nivou naloga**; „Danas” = suma MES [goodQty] za taj stroj/nalog u lokalnom danu.
class PlanningExecutionShiftBoard extends StatefulWidget {
  const PlanningExecutionShiftBoard({super.key, required this.session});

  final PlanningSessionController session;

  @override
  State<PlanningExecutionShiftBoard> createState() => _PlanningExecutionShiftBoardState();
}

class _PlanningExecutionShiftBoardState extends State<PlanningExecutionShiftBoard> {
  static final _orderSvc = ProductionOrderService();
  static final _execSvc = ProductionExecutionService();

  Future<_BoardData>? _boardFuture;
  String? _loadKey;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _syncOrderFuture();
  }

  @override
  void didUpdateWidget(PlanningExecutionShiftBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
    }
    if (oldWidget.session.result != widget.session.result) {
      _syncOrderFuture();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    _syncOrderFuture();
  }

  /// Ključ uključuje ID-eve operacija u planu + očitano/plan u poolu za te naloge (da se red osvježi nakon učitavanja poola).
  String? _buildLoadKey(PlanningSessionController session) {
    final r = session.result;
    if (r == null || r.scheduledOperations.isEmpty) {
      return null;
    }
    final idSet = r.scheduledOperations.map((e) => e.productionOrderId).toSet();
    final idList = idSet.toList()..sort();
    final buf = StringBuffer(idList.join('|'));
    for (final o in session.pool) {
      if (idSet.contains(o.id)) {
        buf.write(
          ':${o.id}=${o.producedGoodQty}:${o.plannedQty}:${o.updatedAt.millisecondsSinceEpoch}',
        );
      }
    }
    buf.write(':mes=${session.mesBoardRefreshToken}');
    return buf.toString();
  }

  void _syncOrderFuture() {
    final session = widget.session;
    final r = session.result;
    if (r == null || r.scheduledOperations.isEmpty) {
      if (_boardFuture != null || _loadKey != null) {
        setState(() {
          _boardFuture = null;
          _loadKey = null;
        });
      }
      return;
    }
    final key = _buildLoadKey(session);
    if (key == null) {
      return;
    }
    if (key == _loadKey && _boardFuture != null) {
      return;
    }
    _loadKey = key;
    final ids = r.scheduledOperations.map((e) => e.productionOrderId).toSet();
    setState(() {
      _boardFuture = _loadBoardData(ids);
    });
  }

  Future<Map<String, ProductionOrderModel>> _loadOrdersForIds(Set<String> ids) async {
    final session = widget.session;
    final fromPool = <String, ProductionOrderModel>{};
    for (final o in session.pool) {
      if (ids.contains(o.id)) {
        fromPool[o.id] = o;
      }
    }
    final missing = ids.difference(fromPool.keys.toSet());
    if (missing.isEmpty) {
      return fromPool;
    }
    final fetched = await _orderSvc.getByIds(
      companyId: session.companyId,
      plantKey: session.plantKey,
      ids: missing,
    );
    fromPool.addAll(fetched);
    return fromPool;
  }

  Future<_BoardData> _loadBoardData(Set<String> ids) async {
    final session = widget.session;
    final orders = await _loadOrdersForIds(ids);
    try {
      final Map<String, List<Map<String, dynamic>>> mes = await _execSvc.getExecutionsByOrderIds(
        companyId: session.companyId,
        plantKey: session.plantKey,
        productionOrderIds: ids,
      );
      return (orders: orders, mesByOrderId: mes);
    } catch (e, st) {
      debugPrint('PlanningExecutionShiftBoard: MES $e\n$st');
      return (
        orders: orders,
        mesByOrderId: <String, List<Map<String, dynamic>>>{},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _buildTable(context, t, widget.session);
  }

  Widget _buildTable(
    BuildContext context,
    ThemeData t,
    PlanningSessionController session,
  ) {
    final r = session.result;
    if (r == null) {
      return Text(
        'Nema generiranog plana — tab Nalozi → Generiši plan.',
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }
    if (r.scheduledOperations.isEmpty) {
      return Text(
        'Nema zakazanih operacija u zadnjem rezultatu.',
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }

    final orderCodes = <String, String>{};
    for (final it in r.plan.items) {
      final c = (it.productionOrderCode ?? '').trim();
      orderCodes[it.productionOrderId] = c.isEmpty ? '—' : c;
    }

    final byMachine = <String, List<ScheduledOperation>>{};
    for (final op in r.scheduledOperations) {
      byMachine.putIfAbsent(op.machineId, () => []).add(op);
    }
    for (final list in byMachine.values) {
      list.sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
    }

    String labelFor(String id) {
      if (id.isEmpty) {
        return 'Nije dodijeljen stroj';
      }
      return session.poolMachineLabel(id);
    }

    final machineKeys = byMachine.keys.toList()
      ..sort((a, b) => labelFor(a).compareTo(labelFor(b)));

    return FutureBuilder<_BoardData>(
      future: _boardFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Text(
            'Nije moguće učitati naloge za očitano: ${snap.error}',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error),
          );
        }
        final data = snap.data;
        final orders = data?.orders ?? {};
        final mesByOrder = data?.mesByOrderId ?? {};
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 44,
            columns: [
              const DataColumn(label: Text('Stroj')),
              const DataColumn(label: Text('Nalog')),
              const DataColumn(label: Text('Plan poč.')),
              const DataColumn(label: Text('Plan kraj')),
              DataColumn(
                label: Tooltip(
                  message:
                      'Kumulativno očitano dobro u odnosu na planirano na cijelom proizvodnom nalogu. '
                      'Ne predstavlja jednu proizvodnu smjenu dok nije povezano očitavanje MES po smjeni.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Stvarno (nalog)', style: t.textTheme.labelLarge),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 16, color: t.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: Tooltip(
                  message:
                      'Suma polja dobro iz zapisa production_execution za ovaj stroj i nalog, '
                      'pripisana lokalnom danu (završetak ili aktivni započeti danas).',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Danas (MES, stroj)', style: t.textTheme.labelLarge),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 16, color: t.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const DataColumn(label: Text('Status (plan)')),
            ],
            rows: machineKeys.map((mk) {
              final op = byMachine[mk]!.first;
              return DataRow(
                cells: [
                  DataCell(Text(labelFor(mk))),
                  DataCell(Text(orderCodes[op.productionOrderId] ?? '—')),
                  DataCell(Text(_fmtDt(op.plannedStart))),
                  DataCell(Text(_fmtDt(op.plannedEnd))),
                  DataCell(Text(_actualText(orders, op.productionOrderId))),
                  DataCell(Text(_mesTodayText(orders, mesByOrder, op.productionOrderId, mk))),
                  DataCell(Text(_statusHr(op.status))),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _mesTodayText(
    Map<String, ProductionOrderModel> orders,
    Map<String, List<Map<String, dynamic>>> mesByOrderId,
    String productionOrderId,
    String machineId,
  ) {
    if (machineId.trim().isEmpty) {
      return '—';
    }
    final list = mesByOrderId[productionOrderId] ?? const [];
    final u = orders[productionOrderId]?.unit ?? 'kom';
    final v = sumLocalDayGoodOnMachine(
      list,
      machineId,
      day: DateTime.now(),
    );
    return '${_fmtQty(v)} $u';
  }

  String _actualText(
    Map<String, ProductionOrderModel> orders,
    String productionOrderId,
  ) {
    final o = orders[productionOrderId];
    if (o == null) {
      return '—';
    }
    final g = o.producedGoodQty;
    final p = o.plannedQty;
    if (p <= 0) {
      return '${_fmtQty(g)} dobro (plan 0)';
    }
    return '${_fmtQty(g)} / ${_fmtQty(p)} ${o.unit} dobro';
  }

  String _fmtQty(double v) {
    if (v.isNaN) {
      return '0';
    }
    final r = v.roundToDouble();
    if ((v - r).abs() < 1e-9) {
      return r.toInt().toString();
    }
    return v.toStringAsFixed(1);
  }

  String _statusHr(String s) {
    switch (s) {
      case 'planned':
        return 'planirano';
      case 'running':
        return 'u toku';
      case 'done':
      case 'completed':
        return 'završeno';
      default:
        return s;
    }
  }

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}. '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
