import 'package:flutter/foundation.dart';

/// Jedna operacija u rasporedu (finite slot na resursu).
@immutable
class ScheduledOperation {
  const ScheduledOperation({
    required this.id,
    this.planId,
    required this.productionOrderId,
    this.routingOperationId,
    this.operationSequence = 10,
    required this.machineId,
    this.workCenterId,
    this.toolId,
    this.operatorIds = const [],
    required this.plannedStart,
    required this.plannedEnd,
    this.setupStart,
    this.runStart,
    this.runEnd,
    this.status = 'planned',
    this.expectedQty = 0,
    this.expectedCycleSec,
    this.expectedRuntimeMin,
    this.sourceFactors = const {},
  });

  final String id;
  final String? planId;
  final String productionOrderId;
  final String? routingOperationId;
  final int operationSequence;
  final String machineId;
  final String? workCenterId;
  final String? toolId;
  final List<String> operatorIds;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? setupStart;
  final DateTime? runStart;
  final DateTime? runEnd;
  final String status;
  final double expectedQty;
  final double? expectedCycleSec;
  final double? expectedRuntimeMin;
  final Map<String, dynamic> sourceFactors;
}
