import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/execution_variance_record.dart';

/// Čitanje varijanci iz `production_plans/{planId}/execution_variances/`; upis preko Callable.
class PlanningExecutionVarianceService {
  PlanningExecutionVarianceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<List<ExecutionVarianceRecord>> listForPlan({
    required String planId,
    required String companyId,
    required String plantKey,
  }) async {
    if (planId.isEmpty) {
      return const [];
    }
    final q = _db
        .collection('production_plans')
        .doc(planId)
        .collection('execution_variances');
    final snap = await q.get();
    final out = <ExecutionVarianceRecord>[];
    for (final d in snap.docs) {
      final m = d.data();
      if (_s(m['companyId']) != companyId || _s(m['plantKey']) != plantKey) {
        continue;
      }
      final e = ExecutionVarianceRecord.fromMap(d.id, m);
      if (e != null) {
        out.add(e);
      }
    }
    return out;
  }

  Future<void> upsertForOperation({
    required String planId,
    required String companyId,
    required String plantKey,
    required String clientOperationId,
    required String productionOrderId,
    required String orderCode,
    required String machineId,
    required DateTime plannedStart,
    required DateTime plannedEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    required String rootCauseCode,
    String? notes,
  }) async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Nema prijave / auth.');
    }
    if (planId.isEmpty) {
      throw StateError('planId je prazan (spremite nacrt).');
    }
    String isoOrNull(DateTime? t) => t == null ? '' : t.toIso8601String();
    final callable = _functions.httpsCallable('upsertExecutionPlanVariance');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'planId': planId,
      'clientOperationId': _s(clientOperationId),
      'productionOrderId': _s(productionOrderId),
      'orderCode': _s(orderCode),
      'machineId': _s(machineId),
      'plannedStart': plannedStart.toIso8601String(),
      'plannedEnd': plannedEnd.toIso8601String(),
      'actualStart': isoOrNull(actualStart),
      'actualEnd': isoOrNull(actualEnd),
      'rootCauseCode': _s(rootCauseCode).isEmpty ? 'unknown' : _s(rootCauseCode),
      'notes': _s(notes),
    });
  }
}
