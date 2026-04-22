import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Jedan zapis konflikta / upozorenja iz [production_plans.conflicts].
@immutable
class SavedPlanConflictItem {
  const SavedPlanConflictItem({
    required this.type,
    required this.message,
    this.suggestion,
    this.severity = 1,
  });

  final String type;
  final String message;
  final String? suggestion;
  final int severity;

  static SavedPlanConflictItem? fromMap(dynamic v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    return SavedPlanConflictItem(
      type: (m['type'] as String?)?.trim() ?? 'other',
      message: (m['message'] as String?)?.trim() ?? '—',
      suggestion: m['suggestion'] as String?,
      severity: (m['severity'] is num) ? (m['severity']! as num).round() : 1,
    );
  }
}

/// Puni sadržaj dokumenta u [production_plans] za ekran detalja.
@immutable
class SavedProductionPlanDetails {
  const SavedProductionPlanDetails({
    required this.id,
    required this.planCode,
    this.status = 'draft',
    this.strategy = '',
    this.source = '',
    this.createdAt,
    this.planningHorizonStart,
    this.planningHorizonEnd,
    this.totalOrders = 0,
    this.totalConflicts = 0,
    this.feasibleOrderCount = 0,
    this.infeasibleOrderCount = 0,
    this.scheduledOperationCount = 0,
    this.onTimeRate01,
    this.totalLatenessMinutes = 0,
    this.hasBottleneckHint = false,
    this.bottleneckMachineId,
    this.estimatedUtilization01,
    this.conflicts = const [],
  });

  final String id;
  final String planCode;
  final String status;
  final String strategy;
  final String source;
  final DateTime? createdAt;
  final DateTime? planningHorizonStart;
  final DateTime? planningHorizonEnd;
  final int totalOrders;
  final int totalConflicts;
  final int feasibleOrderCount;
  final int infeasibleOrderCount;
  final int scheduledOperationCount;
  final double? onTimeRate01;
  final int totalLatenessMinutes;
  final bool hasBottleneckHint;
  /// Ako postoji, ID stroja/asseta u `assets` (za prikaz kroz šifarnik, ne sirov u UI).
  final String? bottleneckMachineId;
  final double? estimatedUtilization01;
  final List<SavedPlanConflictItem> conflicts;

  static SavedProductionPlanDetails fromMap(String id, Map<String, dynamic> m) {
    DateTime? tAt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final rawBottleneck = m['bottleneckMachineId'];
    final bmid = (rawBottleneck is String && rawBottleneck.trim().isNotEmpty)
        ? rawBottleneck.trim()
        : null;
    final hasBottleneck = bmid != null;

    final cl = m['conflicts'];
    final conflicts = <SavedPlanConflictItem>[];
    if (cl is List) {
      for (final e in cl) {
        final c = SavedPlanConflictItem.fromMap(e);
        if (c != null) conflicts.add(c);
      }
    }

    return SavedProductionPlanDetails(
      id: id,
      planCode: (m['planCode'] as String?)?.trim() ?? id,
      status: (m['status'] as String?)?.trim() ?? 'draft',
      strategy: (m['strategy'] as String?)?.trim() ?? '',
      source: (m['source'] as String?)?.trim() ?? '',
      createdAt: tAt(m['createdAt']),
      planningHorizonStart: tAt(m['planningHorizonStart']),
      planningHorizonEnd: tAt(m['planningHorizonEnd']),
      totalOrders: (m['totalOrders'] is num) ? (m['totalOrders']! as num).round() : 0,
      totalConflicts: (m['totalConflicts'] is num) ? (m['totalConflicts']! as num).round() : 0,
      feasibleOrderCount: (m['feasibleOrderCount'] is num)
          ? (m['feasibleOrderCount']! as num).round()
          : 0,
      infeasibleOrderCount: (m['infeasibleOrderCount'] is num)
          ? (m['infeasibleOrderCount']! as num).round()
          : 0,
      scheduledOperationCount: (m['scheduledOperationCount'] is num)
          ? (m['scheduledOperationCount']! as num).round()
          : 0,
      onTimeRate01: m['onTimeRate01'] is num ? (m['onTimeRate01']! as num).toDouble() : null,
      totalLatenessMinutes: (m['totalLatenessMinutes'] is num)
          ? (m['totalLatenessMinutes']! as num).round()
          : 0,
      hasBottleneckHint: hasBottleneck,
      bottleneckMachineId: bmid,
      estimatedUtilization01: m['estimatedUtilization01'] is num
          ? (m['estimatedUtilization01']! as num).toDouble()
          : null,
      conflicts: conflicts,
    );
  }
}
