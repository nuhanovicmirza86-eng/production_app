import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Jedan zapis o uzroku odstupanja (Faza 3) u `production_plans/{planId}/execution_variances/`.
@immutable
class ExecutionVarianceRecord {
  const ExecutionVarianceRecord({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.planId,
    required this.clientOperationId,
    required this.productionOrderId,
    required this.orderCode,
    required this.machineId,
    required this.plannedStart,
    required this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    required this.rootCauseCode,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.updatedByUid,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String planId;
  final String clientOperationId;
  final String productionOrderId;
  final String orderCode;
  final String machineId;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String rootCauseCode;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? updatedByUid;

  static ExecutionVarianceRecord? fromMap(String id, Map<String, dynamic> m) {
    final c = m['companyId']?.toString() ?? '';
    if (c.isEmpty) {
      return null;
    }
    final ps = m['plannedStart'];
    final pe = m['plannedEnd'];
    if (ps is! Timestamp || pe is! Timestamp) {
      return null;
    }
    return ExecutionVarianceRecord(
      id: id,
      companyId: c,
      plantKey: m['plantKey']?.toString() ?? '',
      planId: m['planId']?.toString() ?? '',
      clientOperationId: m['clientOperationId']?.toString() ?? '',
      productionOrderId: m['productionOrderId']?.toString() ?? '',
      orderCode: m['orderCode']?.toString() ?? '',
      machineId: m['machineId']?.toString() ?? '',
      plannedStart: ps.toDate(),
      plannedEnd: pe.toDate(),
      actualStart: (m['actualStart'] as Timestamp?)?.toDate(),
      actualEnd: (m['actualEnd'] as Timestamp?)?.toDate(),
      rootCauseCode: m['rootCauseCode']?.toString() ?? 'unknown',
      notes: m['notes'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      createdByUid: m['createdByUid'] as String?,
      updatedByUid: m['updatedByUid'] as String?,
    );
  }
}
