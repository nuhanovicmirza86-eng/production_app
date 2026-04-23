import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/planning_engine_result.dart';
import '../models/saved_plan_scheduled_row.dart';
import '../models/saved_production_plan_details.dart';
import '../models/saved_production_plan_summary.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import 'planning_gantt_dto.dart';
import 'planning_engine_service.dart';

/// Upis nacrt plana (FCS) u Firestore — tenanta štitimo preko `companyId` / [sameCompany*] u pravilima.
class ProductionPlanPersistenceService {
  ProductionPlanPersistenceService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int _maxConflictDocs = 80;

  /// Vraća ID dokumenta u [production_plans] nakon uspješnog batcha.
  ///
  /// [localGanttAdjusted]: ručno pomicanje u Gantt-u (audit / kasnija analitika).
  Future<String> saveDraftFromEngineResult({
    required PlanningEngineResult result,
    required String companyId,
    required String plantKey,
    bool localGanttAdjusted = false,
  }) async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Morate biti prijavljeni da biste spremili plan.');
    }
    if (result.scheduledOperations.length > PlanningEngineService.maxOrdersPerRun) {
      throw ArgumentError('Previše operacija za jedan upis (interni limit).');
    }

    final planRef = _db.collection('production_plans').doc();
    final plan = result.plan;
    final kpi = result.kpi;
    final batch = _db.batch();

    final orderCodeById = <String, String>{
      for (final it in plan.items) it.productionOrderId: it.productionOrderCode ?? '',
    };

    final conflicts = result.conflicts
        .take(_maxConflictDocs)
        .map((c) {
          return {
            'type': c.type.name,
            'message': c.message,
            if (c.suggestion != null) 'suggestion': c.suggestion,
            if (c.productionOrderId != null) 'productionOrderId': c.productionOrderId,
            if (c.relatedMachineId != null) 'relatedMachineId': c.relatedMachineId,
            'severity': c.severity,
          };
        })
        .toList();

    batch.set(planRef, {
      'companyId': companyId,
      'plantKey': plantKey,
      'planCode': plan.planCode,
      'status': 'draft',
      'strategy': plan.strategy,
      'planningHorizonStart': plan.planningStart != null
          ? Timestamp.fromDate(plan.planningStart!)
          : null,
      'planningHorizonEnd':
          plan.planningEnd != null ? Timestamp.fromDate(plan.planningEnd!) : null,
      'source': 'fcs_mvp_1',
      'localGanttAdjusted': localGanttAdjusted,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': u.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': u.uid,
      'totalOrders': plan.totalOrders,
      'totalConflicts': result.conflicts.length,
      'feasibleOrderCount': kpi?.feasibleOrders ?? 0,
      'infeasibleOrderCount': kpi?.infeasibleOrders ?? 0,
      'onTimeRate01': kpi?.onTimeRate01,
      'totalLatenessMinutes': kpi?.totalLatenessMinutes ?? 0,
      'bottleneckMachineId': kpi?.bottleneckMachineId,
      'estimatedUtilization01': plan.estimatedUtilization01,
      'scheduledOperationCount': result.scheduledOperations.length,
      'conflicts': conflicts,
    });

    for (final op in result.scheduledOperations) {
      final opRef = planRef.collection('scheduled_operations').doc();
      final code = orderCodeById[op.productionOrderId] ?? '';
      batch.set(opRef, {
        'planId': planRef.id,
        'companyId': companyId,
        'plantKey': plantKey,
        'clientOperationId': op.id,
        'productionOrderId': op.productionOrderId,
        'productionOrderCode': code,
        'routingOperationId': op.routingOperationId,
        'operationSequence': op.operationSequence,
        'machineId': op.machineId,
        'workCenterId': op.workCenterId,
        'toolId': op.toolId,
        'operatorIds': op.operatorIds,
        'plannedStart': Timestamp.fromDate(op.plannedStart),
        'plannedEnd': Timestamp.fromDate(op.plannedEnd),
        'setupStart': op.setupStart != null ? Timestamp.fromDate(op.setupStart!) : null,
        'runStart': op.runStart != null ? Timestamp.fromDate(op.runStart!) : null,
        'runEnd': op.runEnd != null ? Timestamp.fromDate(op.runEnd!) : null,
        'status': op.status,
        'expectedQty': op.expectedQty,
        'expectedCycleSec': op.expectedCycleSec,
        'expectedRuntimeMin': op.expectedRuntimeMin,
        'sourceFactors': op.sourceFactors,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': u.uid,
      });
    }

    await batch.commit();
    return planRef.id;
  }

  /// Učitavanje plana s operacijama (npr. nakon upisa) za Gantt.
  Future<PlanningGanttDto> loadGantt({
    required String planId,
    required String companyId,
    required String plantKey,
  }) async {
    final doc = await _db.collection('production_plans').doc(planId).get();
    if (!doc.exists) {
      throw StateError('Plan nije pronađen.');
    }
    final p = doc.data() ?? {};
    if ((p['companyId'] as String? ?? '') != companyId) {
      throw StateError('Plan ne pripada ovoj kompaniji.');
    }
    if ((p['plantKey'] as String? ?? '') != plantKey) {
      throw StateError('Plan ne pripada ovom pogonu.');
    }

    final code = (p['planCode'] as String?) ?? planId;
    final snap = await _db
        .collection('production_plans')
        .doc(planId)
        .collection('scheduled_operations')
        .get();

    final ops = <PlanningGanttOp>[];
    for (final d in snap.docs) {
      final m = d.data();
      final ps = m['plannedStart'];
      final pe = m['plannedEnd'];
      if (ps is! Timestamp || pe is! Timestamp) continue;
      final runS = m['runStart'] is Timestamp
          ? (m['runStart'] as Timestamp).toDate()
          : null;
      final runE = m['runEnd'] is Timestamp
          ? (m['runEnd'] as Timestamp).toDate()
          : null;
      String? opLabel;
      final sf = m['sourceFactors'];
      if (sf is Map) {
        final ol = sf['operationLabel'];
        if (ol is String && ol.trim().isNotEmpty) opLabel = ol.trim();
      }
      ops.add(
        PlanningGanttOp(
          orderCode: (m['productionOrderCode'] as String?)?.trim() ?? '—',
          machineId: (m['machineId'] as String?) ?? '',
          plannedStart: ps.toDate(),
          plannedEnd: pe.toDate(),
          productionOrderId: (m['productionOrderId'] as String?)?.trim(),
          scheduledOperationId: d.id,
          runStart: runS,
          runEnd: runE,
          operationLabel: opLabel,
          blockKind: PlanningGanttBlockKind.plannedFcs,
        ),
      );
    }
    if (ops.isEmpty) {
      return PlanningGanttDto(
        planId: planId,
        planCode: code,
        operations: const [],
        windowStart: DateTime.now(),
        windowEnd: DateTime.now(),
      );
    }
    var w0 = ops.first.plannedStart;
    var w1 = ops.first.plannedEnd;
    for (final o in ops) {
      if (o.plannedStart.isBefore(w0)) w0 = o.plannedStart;
      if (o.plannedEnd.isAfter(w1)) w1 = o.plannedEnd;
    }
    return PlanningGanttDto(
      planId: planId,
      planCode: code,
      operations: ops,
      windowStart: w0,
      windowEnd: w1,
    );
  }

  /// Puni sadržaj jednog [production_plans] dokumenta (detalj ekran).
  Future<SavedProductionPlanDetails> loadPlanDetails({
    required String planId,
    required String companyId,
    required String plantKey,
  }) async {
    final doc = await _db.collection('production_plans').doc(planId).get();
    if (!doc.exists) {
      throw StateError('Plan nije pronađen.');
    }
    final p = doc.data() ?? {};
    if ((p['companyId'] as String? ?? '') != companyId) {
      throw StateError('Plan ne pripada ovoj kompaniji.');
    }
    if ((p['plantKey'] as String? ?? '') != plantKey) {
      throw StateError('Plan ne pripada ovom pogonu.');
    }
    return SavedProductionPlanDetails.fromMap(doc.id, p);
  }

  /// Jadan korak unaprijed: draft → simulated → confirmed → released.
  Future<void> updatePlanStatus({
    required String planId,
    required String companyId,
    required String plantKey,
    required String newStatus,
  }) async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Morate biti prijavljeni.');
    }
    const forward = {'simulated', 'confirmed', 'released'};
    if (!forward.contains(newStatus)) {
      throw ArgumentError('Nevažeći sljedeći status.');
    }
    final ref = _db.collection('production_plans').doc(planId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Plan nije pronađen.');
    }
    final p = snap.data() ?? {};
    if ((p['companyId'] as String? ?? '') != companyId) {
      throw StateError('Plan ne pripada ovoj kompaniji.');
    }
    if ((p['plantKey'] as String? ?? '') != plantKey) {
      throw StateError('Plan ne pripada ovom pogonu.');
    }
    final current = (p['status'] as String? ?? 'draft').trim().toLowerCase();
    if (!_isPlanStatusTransitionAllowed(current, newStatus)) {
      throw StateError('Nedopušen prijelaz statusa.');
    }
    await ref.update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': u.uid,
    });
  }

  static bool _isPlanStatusTransitionAllowed(String from, String to) {
    if (from == to) return true;
    const order = <String>['draft', 'simulated', 'confirmed', 'released'];
    var f = from.isEmpty ? 'draft' : from;
    if (!order.contains(f)) {
      f = 'draft';
    }
    final fi = order.indexOf(f);
    final ti = order.indexOf(to);
    if (ti < 0) return false;
    return ti == fi + 1;
  }

  /// Zakazane operacije nacrta — sort: vrijeme početka, zatim red. broj u routingsu.
  /// Nazivi strojeva rješavaju se preko šifrarnika [assets] (nema golih ID-eva u podacima za UI).
  Future<List<SavedPlanScheduledRow>> loadScheduledOperationRows({
    required String planId,
    required String companyId,
    required String plantKey,
    int limit = 500,
  }) async {
    final l = limit.clamp(1, 2000);
    final planSnap = await _db.collection('production_plans').doc(planId).get();
    if (!planSnap.exists) {
      throw StateError('Plan nije pronađen.');
    }
    final p = planSnap.data() ?? {};
    if ((p['companyId'] as String? ?? '') != companyId) {
      throw StateError('Plan ne pripada ovoj kompaniji.');
    }
    if ((p['plantKey'] as String? ?? '') != plantKey) {
      throw StateError('Plan ne pripada ovom pogonu.');
    }

    final sub = await _db
        .collection('production_plans')
        .doc(planId)
        .collection('scheduled_operations')
        .limit(l)
        .get();

    final lookup = await ProductionAssetDisplayLookup.loadForPlant(
      companyId: companyId,
      plantKey: plantKey,
      limit: 500,
    );

    final rows = <SavedPlanScheduledRow>[];
    for (final d in sub.docs) {
      final m = d.data();
      final ps = m['plannedStart'];
      final pe = m['plannedEnd'];
      if (ps is! Timestamp || pe is! Timestamp) continue;

      String? opLabel;
      final sf = m['sourceFactors'];
      if (sf is Map) {
        final ol = sf['operationLabel'];
        if (ol is String && ol.trim().isNotEmpty) opLabel = ol.trim();
      }
      final mid = (m['machineId'] as String?)?.trim() ?? '';
      var seq = 10;
      final so = m['operationSequence'];
      if (so is num) seq = so.round();

      final code = (m['productionOrderCode'] as String?)?.trim() ?? '—';
      final resource = mid.isEmpty
          ? 'Nije dodijeljen stroj'
          : lookup.resolve(mid);
      rows.add(
        SavedPlanScheduledRow(
          productionOrderCode: code,
          operationLabel: opLabel,
          operationSequence: seq,
          plannedStart: ps.toDate(),
          plannedEnd: pe.toDate(),
          resourceDisplayName: resource,
        ),
      );
    }
    rows.sort((a, b) {
      final t = a.plannedStart.compareTo(b.plannedStart);
      if (t != 0) return t;
      return a.operationSequence.compareTo(b.operationSequence);
    });
    return rows;
  }

  /// Pregled zadnjih nacrta za pogon. Sort: novije prvo (u memoriji).
  ///
  /// Ako sastav upita `companyId` + `plantKey` traži sastavni indeks, fallback je
  /// upit po `companyId` i filtriranje u memoriji.
  Future<List<SavedProductionPlanSummary>> listRecentPlans({
    required String companyId,
    required String plantKey,
    int limit = 50,
  }) async {
    if (limit < 1) return const [];
    final docList = await _loadPlanDocumentsForList(
      companyId: companyId,
      plantKey: plantKey,
    );
    final list = <SavedProductionPlanSummary>[];
    for (final d in docList) {
      list.add(SavedProductionPlanSummary.fromMap(d.id, d.data()));
    }
    _sortPlansByCreatedDesc(list);
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadPlanDocumentsForList({
    required String companyId,
    required String plantKey,
  }) async {
    try {
      final snap = await _db
          .collection('production_plans')
          .where('companyId', isEqualTo: companyId)
          .where('plantKey', isEqualTo: plantKey)
          .limit(120)
          .get();
      return snap.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition' && e.code != 'unimplemented') rethrow;
      final wide = await _db
          .collection('production_plans')
          .where('companyId', isEqualTo: companyId)
          .limit(200)
          .get();
      return wide.docs
          .where(
            (d) => (d.data()['plantKey'] as String? ?? '') == plantKey,
          )
          .toList();
    }
  }

  void _sortPlansByCreatedDesc(List<SavedProductionPlanSummary> list) {
    int compare(SavedProductionPlanSummary a, SavedProductionPlanSummary b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    }
    list.sort(compare);
  }
}
