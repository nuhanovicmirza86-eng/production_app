import 'package:cloud_firestore/cloud_firestore.dart';

/// Kontrolni snimak / reconciliacija (`finance_control_snapshots`).
class FinanceControlSnapshotModel {
  const FinanceControlSnapshotModel({
    required this.id,
    required this.companyId,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    this.plantKey = '',
    this.controlSnapshotKind = '',
    this.linkedFinanceDocPath = '',
    this.baseCurrency = '',
    this.operationalRevenue,
    this.operationalTotalCost,
    this.operationalGrossMargin,
    this.reconciliationState = '',
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String controlSnapshotKind;
  final String linkedFinanceDocPath;
  final String baseCurrency;
  final double? operationalRevenue;
  final double? operationalTotalCost;
  final double? operationalGrossMargin;
  final String reconciliationState;
  final DateTime? updatedAt;

  factory FinanceControlSnapshotModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceControlSnapshotModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      controlSnapshotKind: (data['controlSnapshotKind'] ?? '').toString(),
      linkedFinanceDocPath: (data['linkedFinanceDocPath'] ?? '').toString(),
      baseCurrency: (data['baseCurrency'] ?? '').toString(),
      operationalRevenue: _d(data['operationalRevenue']),
      operationalTotalCost: _d(data['operationalTotalCost']),
      operationalGrossMargin: _d(data['operationalGrossMargin']),
      reconciliationState: (data['reconciliationState'] ?? '').toString(),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
