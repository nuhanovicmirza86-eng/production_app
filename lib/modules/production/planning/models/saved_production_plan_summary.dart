import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Pojedinačan plan u listi (bez cijele podkolekcije operacija).
@immutable
class SavedProductionPlanSummary {
  const SavedProductionPlanSummary({
    required this.id,
    required this.planCode,
    this.status = 'draft',
    this.strategy = '',
    this.createdAt,
    this.feasibleOrderCount = 0,
    this.infeasibleOrderCount = 0,
    this.totalConflicts = 0,
    this.scheduledOperationCount = 0,
  });

  final String id;
  final String planCode;
  final String status;
  /// Isti string kao u dokumentu; za prikaz: [PlanningUiFormatters.engineStrategy].
  final String strategy;
  final DateTime? createdAt;
  final int feasibleOrderCount;
  final int infeasibleOrderCount;
  final int totalConflicts;
  final int scheduledOperationCount;

  static SavedProductionPlanSummary fromMap(String id, Map<String, dynamic> m) {
    DateTime? at;
    final c = m['createdAt'];
    if (c is Timestamp) at = c.toDate();

    return SavedProductionPlanSummary(
      id: id,
      planCode: (m['planCode'] as String?)?.trim() ?? id,
      status: (m['status'] as String?)?.trim() ?? 'draft',
      strategy: (m['strategy'] as String?)?.trim() ?? '',
      createdAt: at,
      feasibleOrderCount: (m['feasibleOrderCount'] is num)
          ? (m['feasibleOrderCount']! as num).round()
          : 0,
      infeasibleOrderCount: (m['infeasibleOrderCount'] is num)
          ? (m['infeasibleOrderCount']! as num).round()
          : 0,
      totalConflicts: (m['totalConflicts'] is num)
          ? (m['totalConflicts']! as num).round()
          : 0,
      scheduledOperationCount: (m['scheduledOperationCount'] is num)
          ? (m['scheduledOperationCount']! as num).round()
          : 0,
    );
  }
}
