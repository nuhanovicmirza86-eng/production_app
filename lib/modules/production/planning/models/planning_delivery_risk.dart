import 'package:flutter/foundation.dart';

import 'planning_engine_result.dart';

/// F4.5 — heuristika agregatnog rizika isporuke nakon FCS (bez posebnog API-ja).
@immutable
class PlanningDeliveryRisk {
  const PlanningDeliveryRisk({
    required this.risk01,
    required this.labelHr,
  });

  final double risk01;
  final String labelHr;

  /// [poolUrgentCount] = npr. [PlanningSessionController.countRiskOrders];
  /// [poolSize] = broj naloga u poolu (istom kontekstu kao pre-check).
  static PlanningDeliveryRisk? fromEngineResult(
    PlanningEngineResult r, {
    int poolUrgentCount = 0,
    int poolSize = 1,
  }) {
    final k = r.kpi;
    if (k == null) {
      return null;
    }
    final total = k.totalPlannedOrders;
    if (total <= 0) {
      return null;
    }
    final pInf = (k.infeasibleOrders / total).clamp(0.0, 1.0);
    final pLate = (k.totalLatenessMinutes / 10080.0).clamp(0.0, 1.0);
    final denom = poolSize < 1 ? 1 : poolSize;
    final pUrg = (poolUrgentCount / denom).clamp(0.0, 1.0);
    final risk = (0.45 * pInf + 0.35 * pLate + 0.20 * pUrg).clamp(0.0, 1.0);
    String label;
    if (risk < 0.25) {
      label = 'Nisko';
    } else if (risk < 0.55) {
      label = 'Umjereno';
    } else {
      label = 'Visoko';
    }
    return PlanningDeliveryRisk(risk01: risk, labelHr: label);
  }
}
