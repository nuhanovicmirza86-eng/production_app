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

  ScheduledOperation copyWith({
    String? id,
    String? planId,
    String? productionOrderId,
    String? routingOperationId,
    int? operationSequence,
    String? machineId,
    String? workCenterId,
    String? toolId,
    List<String>? operatorIds,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    DateTime? setupStart,
    DateTime? runStart,
    DateTime? runEnd,
    String? status,
    double? expectedQty,
    double? expectedCycleSec,
    double? expectedRuntimeMin,
    Map<String, dynamic>? sourceFactors,
  }) {
    return ScheduledOperation(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      productionOrderId: productionOrderId ?? this.productionOrderId,
      routingOperationId: routingOperationId ?? this.routingOperationId,
      operationSequence: operationSequence ?? this.operationSequence,
      machineId: machineId ?? this.machineId,
      workCenterId: workCenterId ?? this.workCenterId,
      toolId: toolId ?? this.toolId,
      operatorIds: operatorIds ?? this.operatorIds,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      setupStart: setupStart ?? this.setupStart,
      runStart: runStart ?? this.runStart,
      runEnd: runEnd ?? this.runEnd,
      status: status ?? this.status,
      expectedQty: expectedQty ?? this.expectedQty,
      expectedCycleSec: expectedCycleSec ?? this.expectedCycleSec,
      expectedRuntimeMin: expectedRuntimeMin ?? this.expectedRuntimeMin,
      sourceFactors: sourceFactors ?? this.sourceFactors,
    );
  }
}
