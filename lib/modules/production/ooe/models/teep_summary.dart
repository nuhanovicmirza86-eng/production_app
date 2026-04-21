import 'package:cloud_firestore/cloud_firestore.dart';

/// Proširen sažetak: OEE (planirana proizvodnja), OOE (operativno), TEEP (kalendar).
///
/// **Poslovno pravilo:** OEE i OOE dijele iste P i Q; Availability ima različitu bazu vremena.
/// **TEEP** = OEE × Utilization, gdje je **Utilization** = plannedProduction / calendar.
/// Upisuje Callable; klijent čita.
class TeepSummary {
  final String id;
  final String companyId;
  final String plantKey;
  final String scopeType;
  final String scopeId;
  final String periodType;
  final DateTime periodDate;

  final int calendarTimeSeconds;
  final int operatingTimeSeconds;
  final int plannedProductionTimeSeconds;
  final int runTimeSeconds;

  final double totalCount;
  final double goodCount;
  final double scrapCount;

  /// A/P/Q na sloju plana (OEE) — Availability = run / planned production time.
  final double availabilityOee;
  final double performance;
  final double quality;

  /// Availability na operativnom sloju (OOE) = run / operating time.
  final double availabilityOoe;

  final double utilization;

  final double oee;
  final double ooe;
  final double teep;

  final List<Map<String, dynamic>> topLosses;
  final DateTime lastCalculatedAt;
  final String calculationVersion;

  const TeepSummary({
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
    required this.runTimeSeconds,
    required this.totalCount,
    required this.goodCount,
    required this.scrapCount,
    required this.availabilityOee,
    required this.performance,
    required this.quality,
    required this.availabilityOoe,
    required this.utilization,
    required this.oee,
    required this.ooe,
    required this.teep,
    required this.topLosses,
    required this.lastCalculatedAt,
    required this.calculationVersion,
  });

  static const String defaultVersion = '2026-04-22-teep-v2';

  factory TeepSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) return TeepSummary._empty(doc.id);
    return TeepSummary.fromMap(doc.id, m);
  }

  factory TeepSummary._empty(String id) {
    final now = DateTime.now();
    return TeepSummary(
      id: id,
      companyId: '',
      plantKey: '',
      scopeType: 'plant',
      scopeId: '',
      periodType: 'day',
      periodDate: now,
      calendarTimeSeconds: 0,
      operatingTimeSeconds: 0,
      plannedProductionTimeSeconds: 0,
      runTimeSeconds: 0,
      totalCount: 0,
      goodCount: 0,
      scrapCount: 0,
      availabilityOee: 0,
      performance: 0,
      quality: 0,
      availabilityOoe: 0,
      utilization: 0,
      oee: 0,
      ooe: 0,
      teep: 0,
      topLosses: const [],
      lastCalculatedAt: now,
      calculationVersion: defaultVersion,
    );
  }

  factory TeepSummary.fromMap(String id, Map<String, dynamic> map) {
    DateTime pd = DateTime.now();
    final rawPd = map['periodDate'];
    if (rawPd is Timestamp) pd = rawPd.toDate();

    List<Map<String, dynamic>> topLosses = const [];
    final raw = map['topLosses'];
    if (raw is List) {
      topLosses = raw.map((e) {
        if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }

    return TeepSummary(
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
      runTimeSeconds: (map['runTimeSeconds'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toDouble() ?? 0,
      goodCount: (map['goodCount'] as num?)?.toDouble() ?? 0,
      scrapCount: (map['scrapCount'] as num?)?.toDouble() ?? 0,
      availabilityOee: (map['availabilityOee'] as num?)?.toDouble() ?? 0,
      performance: (map['performance'] as num?)?.toDouble() ?? 0,
      quality: (map['quality'] as num?)?.toDouble() ?? 0,
      availabilityOoe: (map['availabilityOoe'] as num?)?.toDouble() ?? 0,
      utilization: (map['utilization'] as num?)?.toDouble() ?? 0,
      oee: (map['oee'] as num?)?.toDouble() ?? 0,
      ooe: (map['ooe'] as num?)?.toDouble() ?? 0,
      teep: (map['teep'] as num?)?.toDouble() ?? 0,
      topLosses: topLosses,
      lastCalculatedAt:
          (map['lastCalculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      calculationVersion: (map['calculationVersion'] ?? defaultVersion).toString(),
    );
  }
}
