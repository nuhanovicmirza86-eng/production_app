import 'package:cloud_firestore/cloud_firestore.dart';

/// F3 — evidencija ocjena (ponder: osnove 25%, kvalitet rada 75%).
/// Kolekcija: `workforce_evaluation_records/{docId}`.
class WorkforceEvaluationRecord {
  final String id;
  final String companyId;
  final String plantKey;
  final String employeeDocId;
  final String periodKey;

  final int houseRulesScore;
  final int safetyComplianceScore;
  final int workEffectivenessScore;
  final int workEfficiencyScore;

  final int basicPointsSum;
  final int qualityPointsSum;
  final double totalScorePct;

  final String notesShort;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkforceEvaluationRecord({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
    required this.periodKey,
    required this.houseRulesScore,
    required this.safetyComplianceScore,
    required this.workEffectivenessScore,
    required this.workEfficiencyScore,
    required this.basicPointsSum,
    required this.qualityPointsSum,
    required this.totalScorePct,
    this.notesShort = '',
    this.createdAt,
    this.updatedAt,
  });

  factory WorkforceEvaluationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    DateTime? c;
    final ca = d['createdAt'];
    if (ca is Timestamp) c = ca.toDate();
    DateTime? u;
    final ua = d['updatedAt'];
    if (ua is Timestamp) u = ua.toDate();

    final tsp = d['totalScorePct'];
    double pct = 0;
    if (tsp is num) pct = tsp.toDouble();

    final h = _intInRange(d['houseRulesScore'], 1, 3);
    final s = _intInRange(d['safetyComplianceScore'], 1, 3);
    final we = _intInRange(d['workEffectivenessScore'], 1, 5);
    final wi = _intInRange(d['workEfficiencyScore'], 1, 5);
    final bp = d['basicPointsSum'];
    final qp = d['qualityPointsSum'];
    final basicSum = bp is num ? bp.round() : h + s;
    final qualSum = qp is num ? qp.round() : we + wi;

    return WorkforceEvaluationRecord(
      id: doc.id,
      companyId: (d['companyId'] ?? '').toString(),
      plantKey: (d['plantKey'] ?? '').toString(),
      employeeDocId: (d['employeeDocId'] ?? '').toString(),
      periodKey: (d['periodKey'] ?? '').toString(),
      houseRulesScore: h,
      safetyComplianceScore: s,
      workEffectivenessScore: we,
      workEfficiencyScore: wi,
      basicPointsSum: basicSum.clamp(2, 6),
      qualityPointsSum: qualSum.clamp(2, 10),
      totalScorePct: pct,
      notesShort: (d['notesShort'] ?? '').toString(),
      createdAt: c,
      updatedAt: u,
    );
  }

  static int _intInRange(dynamic v, int min, int max) {
    final n = v is num ? v.round() : int.tryParse('$v') ?? min;
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }
}
