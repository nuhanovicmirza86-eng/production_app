import 'package:cloud_firestore/cloud_firestore.dart';

/// Sažetak iskorištenja: planirana proizvodnja u odnosu na kalendar (Utilization).
///
/// Upisuje backend; klijent čita.
class UtilizationSummary {
  final String id;
  final String companyId;
  final String plantKey;
  final String scopeType;
  final String scopeId;

  /// `day` | `week` | `month`
  final String periodType;
  final DateTime periodDate;

  final int calendarTimeSeconds;
  final int operatingTimeSeconds;
  final int plannedProductionTimeSeconds;

  /// plannedProduction / calendar
  final double utilization;
  final DateTime lastCalculatedAt;

  const UtilizationSummary({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.scopeType,
    required this.scopeId,
    required this.periodType,
    required this.periodDate,
    required this.calendarTimeSeconds,
    required this.operatingTimeSeconds,
    required this.plannedProductionTimeSeconds,
    required this.utilization,
    required this.lastCalculatedAt,
  });

  factory UtilizationSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) {
      final now = DateTime.now();
      return UtilizationSummary(
        id: doc.id,
        companyId: '',
        plantKey: '',
        scopeType: 'plant',
        scopeId: '',
        periodType: 'day',
        periodDate: now,
        calendarTimeSeconds: 0,
        operatingTimeSeconds: 0,
        plannedProductionTimeSeconds: 0,
        utilization: 0,
        lastCalculatedAt: now,
      );
    }
    return UtilizationSummary.fromMap(doc.id, m);
  }

  factory UtilizationSummary.fromMap(String id, Map<String, dynamic> map) {
    DateTime pd = DateTime.now();
    final rawPd = map['periodDate'];
    if (rawPd is Timestamp) pd = rawPd.toDate();

    return UtilizationSummary(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      scopeType: (map['scopeType'] ?? '').toString(),
      scopeId: (map['scopeId'] ?? '').toString(),
      periodType: (map['periodType'] ?? 'day').toString(),
      periodDate: pd,
      calendarTimeSeconds: (map['calendarTimeSeconds'] as num?)?.toInt() ?? 0,
      operatingTimeSeconds: (map['operatingTimeSeconds'] as num?)?.toInt() ?? 0,
      plannedProductionTimeSeconds:
          (map['plannedProductionTimeSeconds'] as num?)?.toInt() ?? 0,
      utilization: (map['utilization'] as num?)?.toDouble() ?? 0,
      lastCalculatedAt:
          (map['lastCalculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
