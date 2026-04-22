import 'package:flutter/foundation.dart';

/// Veza generirani plan ↔ proizvodni nalog.
@immutable
class ProductionPlanItem {
  const ProductionPlanItem({
    required this.productionOrderId,
    this.productionOrderCode,
    this.priority = 0,
    this.plannedStart,
    this.plannedEnd,
    this.feasible = true,
    this.latenessMinutes = 0,
    this.reasonCodes = const [],
  });

  final String productionOrderId;
  final String? productionOrderCode;
  final int priority;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final bool feasible;
  final int latenessMinutes;
  final List<String> reasonCodes;
}
