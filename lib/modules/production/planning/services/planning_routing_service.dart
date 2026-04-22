import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/planning_routing_step.dart';

/// Učitavanje [routing_steps] za nalog (isti `routingId` kao na nalogu).
class PlanningRoutingService {
  PlanningRoutingService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String unspecifiedRouting = 'unspecified';

  static bool isRoutingIdUsable(String? id) {
    final s = (id ?? '').trim();
    if (s.isEmpty) return false;
    if (s == unspecifiedRouting) return false;
    return true;
  }

  /// Prazan rezultat ako nema dokumenata ili pristup nije moguć.
  Future<List<PlanningRoutingStep>> loadStepsForOrder({
    required String companyId,
    required String routingId,
  }) async {
    if (!isRoutingIdUsable(routingId)) return const [];
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    try {
      final q = await _db
          .collection('routing_steps')
          .where('companyId', isEqualTo: cid)
          .where('routingId', isEqualTo: routingId.trim())
          .limit(200)
          .get();
      if (q.docs.isEmpty) return const [];
      final list = q.docs
          .map(
            (d) => PlanningRoutingStep.fromMap(d.id, d.data()),
          )
          .toList();
      list.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
      return list;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || e.code == 'permission-denied') {
        return await _loadFallback(companyId: cid, routingId: routingId.trim());
      }
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlanningRoutingStep>> _loadFallback({
    required String companyId,
    required String routingId,
  }) async {
    final wide = await _db
        .collection('routing_steps')
        .where('companyId', isEqualTo: companyId)
        .limit(300)
        .get();
    final list = wide.docs
        .where(
          (d) =>
              (d.data()['routingId'] as String? ?? '').trim() == routingId,
        )
        .map(
          (d) => PlanningRoutingStep.fromMap(d.id, d.data()),
        )
        .toList();
    list.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return list;
  }
}
