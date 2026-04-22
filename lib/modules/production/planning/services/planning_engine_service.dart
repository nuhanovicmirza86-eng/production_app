import 'dart:math' as math;

import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/services/production_order_service.dart';
import '../models/planning_conflict.dart';
import '../models/planning_engine_result.dart';
import '../models/planning_resource_snapshot.dart';
import '../models/production_plan.dart';
import '../models/production_plan_item.dart';
import '../models/production_plan_status.dart';
import '../models/scheduled_operation.dart';
import 'planning_routing_service.dart';

/// **Finite capacity scheduling** — lokalni izvor istine; plan se po želji sprema u Firestore.
///
/// - Nalozi **EDD**; ako postoji [routing_steps] za `routingId` naloga, planira se
///   **više operacija** s redom; inače jedna sintetička.
/// - Stroj: [PlanningRoutingStep] može imati `machineId`; inače stroj s naloga.
/// - Vrijeme: setup + (količina × min/jed iz standarda) / [performanceFactor], ili globalni ciklus (s/kom).
class PlanningEngineService {
  PlanningEngineService({
    ProductionOrderService? orderService,
    PlanningRoutingService? routingService,
  })  : _orders = orderService ?? ProductionOrderService(),
        _routing = routingService ?? PlanningRoutingService();

  final ProductionOrderService _orders;
  final PlanningRoutingService _routing;

  static const double defaultSetupMinutes = 30;
  static const double defaultCycleSecPerUnit = 60;
  static const int maxOrdersPerRun = 100;
  static const int maxScheduledOperations = 2000;

  Future<PlanningEngineResult> generateDraftPlan({
    required String companyId,
    required String plantKey,
    required DateTime horizonStart,
    required DateTime horizonEnd,
    List<String>? productionOrderIds,
    double performanceFactor = 0.65,
    double setupMinutes = defaultSetupMinutes,
    double cycleSecPerUnit = defaultCycleSecPerUnit,
  }) async {
    if (!horizonEnd.isAfter(horizonStart)) {
      throw ArgumentError('horizonEnd mora biti poslije horizonStart.');
    }
    final perf = performanceFactor.clamp(0.05, 1.0);
    final cycleMinPerUnit = cycleSecPerUnit / 60.0;

    final all = await _orders.getOrders(companyId: companyId, plantKey: plantKey);
    var pool = all.where((o) {
      final s = o.status.toLowerCase();
      return s == 'released' || s == 'in_progress';
    }).toList();

    if (productionOrderIds != null && productionOrderIds.isNotEmpty) {
      final want = productionOrderIds.toSet();
      pool = pool.where((o) => want.contains(o.id)).toList();
    }

    pool = pool.take(maxOrdersPerRun).toList();
    _sortForScheduling(pool);

    final planId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final planCode =
        'P-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${planId.length > 6 ? planId.substring(planId.length - 6) : planId}';

    final machineNext = <String, DateTime>{};
    final machineAssignedMin = <String, int>{};
    final scheduled = <ScheduledOperation>[];
    final conflicts = <PlanningConflict>[];
    final items = <ProductionPlanItem>[];
    int feasible = 0;
    int infeasible = 0;
    int onTime = 0;
    int lateMinutesSum = 0;
    var usedRouting = false;

    for (final o in pool) {
      final remaining = _remainingQty(o);
      if (remaining <= 0) continue;

      if (scheduled.length >= maxScheduledOperations) {
        infeasible++;
        conflicts.add(
          PlanningConflict(
            planId: planId,
            productionOrderId: o.id,
            type: PlanningConflictType.other,
            message:
                'Dostignut je interni limit broja zakazanih operacija u jednom pokretanju plana.',
            suggestion: 'Smanjite broj naloga ili skratite broj koraka u routingsu.',
          ),
        );
        items.add(
          ProductionPlanItem(
            productionOrderId: o.id,
            productionOrderCode: o.productionOrderCode,
            feasible: false,
            reasonCodes: const ['engine_op_limit'],
          ),
        );
        continue;
      }

      final steps = await _routing.loadStepsForOrder(
        companyId: companyId,
        routingId: o.routingId,
      );

      if (steps.isEmpty) {
        // ---------- sintetički jedan korak (kao do sada) ----------
        final machineId = (o.machineId ?? '').trim();
        if (machineId.isEmpty) {
          infeasible++;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              type: PlanningConflictType.noMachineAssigned,
              message:
                  'Nalog ${o.productionOrderCode} nema stroj na nalogu, a nema učitavanih koraka u routingsu.',
              suggestion: 'Dodijelite stroj na nalogu ili unesite routings s koracima (i strojem po koraku).',
            ),
          );
          items.add(
            ProductionPlanItem(
              productionOrderId: o.id,
              productionOrderCode: o.productionOrderCode,
              feasible: false,
              reasonCodes: const ['no_machine_assigned'],
            ),
          );
          continue;
        }

        var start = machineNext[machineId] ?? horizonStart;
        if (start.isBefore(horizonStart)) start = horizonStart;
        final runMin = remaining * cycleMinPerUnit / perf;
        final totalMin = setupMinutes + runMin;
        final duration =
            Duration(microseconds: (totalMin * 60 * 1e6).round());
        final end = start.add(duration);
        if (end.isAfter(horizonEnd)) {
          infeasible++;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              relatedMachineId: machineId,
              type: PlanningConflictType.beyondHorizon,
              message: 'Nalog ${o.productionOrderCode} ne staje u horizont planiranja.',
              suggestion: 'Proširite horizont, smanjite količinu ili promijenite redoslijed.',
            ),
          );
          items.add(
            ProductionPlanItem(
              productionOrderId: o.id,
              productionOrderCode: o.productionOrderCode,
              feasible: false,
              reasonCodes: const ['beyond_horizon'],
            ),
          );
          continue;
        }
        int lateness = 0;
        final due = o.requestedDeliveryDate;
        if (due != null && end.isAfter(due)) {
          lateness = end.difference(due).inMinutes;
          lateMinutesSum += lateness;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              relatedMachineId: machineId,
              type: PlanningConflictType.dueDateRisk,
              message:
                  'Nalog ${o.productionOrderCode} završava poslije traženog roka (+$lateness min).',
              suggestion: 'Povećajte kapacitet, prebacite nalog ili dogovorite novi rok.',
            ),
          );
        } else {
          onTime++;
        }
        scheduled.add(
          ScheduledOperation(
            id: 'op_${o.id}_10',
            planId: planId,
            productionOrderId: o.id,
            routingOperationId: 'synthetic_10',
            operationSequence: 10,
            machineId: machineId,
            plannedStart: start,
            plannedEnd: end,
            runStart: start.add(Duration(minutes: setupMinutes.floor())),
            runEnd: end,
            expectedQty: remaining,
            expectedCycleSec: cycleSecPerUnit,
            expectedRuntimeMin: runMin,
            sourceFactors: {
              'setupMinutes': setupMinutes,
              'performanceFactor': perf,
              'formula': 'setup + (qty×ciklus_s)/60/perf',
              'operationLabel': 'Sintetička operacija',
            },
          ),
        );
        machineNext[machineId] = end;
        feasible++;
        items.add(
          ProductionPlanItem(
            productionOrderId: o.id,
            productionOrderCode: o.productionOrderCode,
            priority: 0,
            plannedStart: start,
            plannedEnd: end,
            feasible: true,
            latenessMinutes: lateness,
            reasonCodes: lateness > 0 ? const ['late_vs_due'] : const [],
          ),
        );
        continue;
      }

      // ---------- više operacija iz routingsa ----------
      usedRouting = true;
      final beforeSnap = Map<String, DateTime>.from(machineNext);
      final schedIdx0 = scheduled.length;
      final orderMachine = (o.machineId ?? '').trim();

      var lastEndOnOrder = horizonStart;
      DateTime? firstStart;
      DateTime? lastEnd;
      var orderFailed = false;

      for (final step in steps) {
        if (scheduled.length >= maxScheduledOperations) {
          orderFailed = true;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              type: PlanningConflictType.other,
              message: 'Dostignut interni limit operacija tijekom routingsa naloga ${o.productionOrderCode}.',
            ),
          );
          break;
        }
        final mid = (step.machineId != null && step.machineId!.trim().isNotEmpty)
            ? step.machineId!.trim()
            : orderMachine;
        if (mid.isEmpty) {
          orderFailed = true;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              type: PlanningConflictType.noMachineAssigned,
              message:
                  'Nalog ${o.productionOrderCode}: za korak „${step.displayLabel}” nije zadan stroj (ni na nalogu).',
              suggestion:
                  'Dodajte `machineId` na korak u routingsu ili na proizvodni nalog.',
            ),
          );
          break;
        }

        final setup = step.setupTimeMinutes ?? setupMinutes;
        final runMin = (step.standardTimeMinutesPerUnit != null &&
                step.standardTimeMinutesPerUnit! > 0)
            ? (remaining * step.standardTimeMinutesPerUnit! / perf)
            : (remaining * cycleMinPerUnit / perf);
        final totalMin = setup + runMin;

        var start = machineNext[mid] ?? horizonStart;
        if (start.isBefore(horizonStart)) start = horizonStart;
        if (start.isBefore(lastEndOnOrder)) {
          start = lastEndOnOrder;
        }

        final duration =
            Duration(microseconds: (totalMin * 60 * 1e6).round());
        final end = start.add(duration);
        if (end.isAfter(horizonEnd)) {
          orderFailed = true;
          conflicts.add(
            PlanningConflict(
              planId: planId,
              productionOrderId: o.id,
              relatedMachineId: mid,
              type: PlanningConflictType.beyondHorizon,
              message:
                  'Nalog ${o.productionOrderCode}, korak „${step.displayLabel}”: ne staje u horizont planiranja.',
              suggestion: 'Proširite horizont, smanjite količinu ili promijenite routings.',
            ),
          );
          break;
        }

        firstStart ??= start;
        lastEnd = end;
        lastEndOnOrder = end;

        final cyc = step.standardTimeMinutesPerUnit != null &&
                step.standardTimeMinutesPerUnit! > 0
            ? step.standardTimeMinutesPerUnit! * 60
            : cycleSecPerUnit;

        scheduled.add(
          ScheduledOperation(
            id: 'op_${o.id}_${step.stepOrder}',
            planId: planId,
            productionOrderId: o.id,
            routingOperationId: step.operationCode.isNotEmpty
                ? step.operationCode
                : 'step_${step.stepOrder}',
            operationSequence: step.stepOrder == 0 ? 10 : step.stepOrder,
            machineId: mid,
            plannedStart: start,
            plannedEnd: end,
            runStart: start.add(Duration(minutes: setup.floor())),
            runEnd: end,
            expectedQty: remaining,
            expectedCycleSec: cyc,
            expectedRuntimeMin: runMin,
            sourceFactors: {
              'setupMinutes': setup,
              'performanceFactor': perf,
              'routingStepDocId': step.id,
              'standardTimeMinutesPerUnit': step.standardTimeMinutesPerUnit,
              'operationLabel': step.displayLabel,
            },
          ),
        );
        machineNext[mid] = end;
      }

      if (orderFailed) {
        scheduled.removeRange(schedIdx0, scheduled.length);
        machineNext
          ..clear()
          ..addAll(beforeSnap);
        infeasible++;
        items.add(
          ProductionPlanItem(
            productionOrderId: o.id,
            productionOrderCode: o.productionOrderCode,
            feasible: false,
            reasonCodes: const ['routing_schedule_failed'],
          ),
        );
        continue;
      }

      if (lastEnd == null) {
        infeasible++;
        continue;
      }
      var orderLateness = 0;
      final due = o.requestedDeliveryDate;
      if (due != null && lastEnd.isAfter(due)) {
        orderLateness = lastEnd.difference(due).inMinutes;
        lateMinutesSum += orderLateness;
        conflicts.add(
          PlanningConflict(
            planId: planId,
            productionOrderId: o.id,
            type: PlanningConflictType.dueDateRisk,
            message:
                'Nalog ${o.productionOrderCode} (više koraka) završava poslije roka (+$orderLateness min).',
            suggestion: 'Povećajte kapacitet, promijenite routings ili rok.',
          ),
        );
      } else {
        onTime++;
      }
      feasible++;
      items.add(
        ProductionPlanItem(
          productionOrderId: o.id,
          productionOrderCode: o.productionOrderCode,
          priority: 0,
          plannedStart: firstStart,
          plannedEnd: lastEnd,
          feasible: true,
          latenessMinutes: orderLateness,
          reasonCodes:
              orderLateness > 0 ? const ['late_vs_due'] : const [],
        ),
      );
    }

    _recalculateMachineLoad(machineAssignedMin, scheduled);

    final totalPlanned = feasible + infeasible;
    final onTimeRate = feasible == 0
        ? null
        : (onTime / math.max(1, feasible)).toDouble();

    final horizonMin = horizonEnd.difference(horizonStart).inMinutes;
    String? bottleneck;
    var maxLoad = -1.0;
    final entries = <MachineLoadEntry>[];
    for (final e in machineAssignedMin.entries) {
      entries.add(
        MachineLoadEntry(
          machineId: e.key,
          assignedMinutes: e.value,
          horizonMinutes: horizonMin,
        ),
      );
      if (e.value > maxLoad) {
        maxLoad = e.value.toDouble();
        bottleneck = e.key;
      }
    }
    final avgU = machineAssignedMin.isEmpty
        ? 0.0
        : machineAssignedMin.values.fold<int>(0, (a, b) => a + b) /
            (math.max(1, machineAssignedMin.length * horizonMin));

    final strategy = usedRouting
        ? 'edd_finite_routing_multi_v1'
        : 'edd_finite_synthetic_v1';

    final plan = ProductionPlan(
      id: planId,
      companyId: companyId,
      plantKey: plantKey,
      planCode: planCode,
      status: ProductionPlanStatus.draft,
      createdAt: now,
      planningStart: horizonStart,
      planningEnd: horizonEnd,
      strategy: strategy,
      items: items,
      totalOrders: totalPlanned,
      totalConflicts: conflicts.length,
      onTimeRate01: onTimeRate,
      estimatedUtilization01: entries.isEmpty ? null : avgU.clamp(0, 1),
    );

    return PlanningEngineResult(
      plan: plan,
      scheduledOperations: scheduled,
      conflicts: conflicts,
      resourceSnapshot: PlanningResourceSnapshot(
        machineEntries: entries,
        bottleneckMachineId: bottleneck,
        horizonStart: horizonStart,
        horizonEnd: horizonEnd,
      ),
      kpi: PlanningEngineKpi(
        totalPlannedOrders: totalPlanned,
        feasibleOrders: feasible,
        infeasibleOrders: infeasible,
        onTimeRate01: onTimeRate,
        totalLatenessMinutes: lateMinutesSum,
        bottleneckMachineId: bottleneck,
      ),
    );
  }

  void _recalculateMachineLoad(
    Map<String, int> machineAssignedMin,
    List<ScheduledOperation> scheduled,
  ) {
    machineAssignedMin.clear();
    for (final op in scheduled) {
      final m = op.machineId;
      if (m.isEmpty) continue;
      final min = op.plannedEnd.difference(op.plannedStart).inMinutes;
      if (min < 0) continue;
      machineAssignedMin[m] = (machineAssignedMin[m] ?? 0) + min;
    }
  }

  void _sortForScheduling(List<ProductionOrderModel> list) {
    list.sort((a, b) {
      final da = a.requestedDeliveryDate;
      final db = b.requestedDeliveryDate;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  double _remainingQty(ProductionOrderModel o) {
    final p = o.plannedQty;
    final g = o.producedGoodQty;
    if (o.status.toLowerCase() == 'in_progress') {
      return math.max(0, p - g);
    }
    if (o.status.toLowerCase() == 'released') {
      return math.max(0, p - g);
    }
    return p;
  }
}
