import 'package:cloud_firestore/cloud_firestore.dart';

import 'development_project_team_member.dart';

/// Glavni dokument `development_projects/{projectId}` — NPI / Stage-Gate / portfolio.
class DevelopmentProjectModel {
  final String id;

  final String companyId;
  final String plantKey;

  final String businessYearId;
  final String businessYearLabel;
  final Timestamp? businessYearStart;
  final Timestamp? businessYearEnd;
  final String businessQuarter;
  final String businessMonth;

  final bool isCarriedOver;
  final String? carriedOverFromBusinessYearId;
  final String? carriedOverToBusinessYearId;

  final String projectCode;
  final String projectName;
  final String projectType;

  final String? customerId;
  final String? customerName;

  final String? productId;
  final String? productCode;
  final String? productName;

  final String projectManagerId;
  final String projectManagerName;

  /// Bogat strukturirani tim (`team` u Firestoreu); prazan ako još nije migran / legacy zapis.
  final List<DevelopmentProjectTeamMember> team;

  /// Agregat UID-ova (Firestore + lokalno spojeno s članovima [team] i PM).
  final List<String> teamMemberIds;

  final String status;
  final String currentGate;
  final String currentStage;

  final String priority;
  final String riskLevel;

  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;

  final double? budgetPlanned;
  final double? budgetActual;
  final String currency;

  final double? estimatedRevenue;
  final double? estimatedMargin;
  final String strategicImportance;

  final int progressPercent;

  final DevelopmentProjectKpi kpi;
  final DevelopmentProjectAi ai;

  final DateTime createdAt;
  final String createdBy;
  final String createdByName;

  final DateTime updatedAt;
  final String updatedBy;

  final DateTime? closedAt;
  final String? closedBy;
  final String? closedByName;

  final DateTime? releasedToProductionAt;
  final String? releasedToProductionBy;
  final String? releasedToProductionByName;
  final String? releasedToProductionGate;

  const DevelopmentProjectModel({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.businessYearLabel,
    this.businessYearStart,
    this.businessYearEnd,
    required this.businessQuarter,
    required this.businessMonth,
    this.isCarriedOver = false,
    this.carriedOverFromBusinessYearId,
    this.carriedOverToBusinessYearId,
    required this.projectCode,
    required this.projectName,
    required this.projectType,
    this.customerId,
    this.customerName,
    this.productId,
    this.productCode,
    this.productName,
    required this.projectManagerId,
    required this.projectManagerName,
    this.team = const [],
    required this.teamMemberIds,
    required this.status,
    required this.currentGate,
    required this.currentStage,
    required this.priority,
    required this.riskLevel,
    this.plannedStartDate,
    this.plannedEndDate,
    this.actualStartDate,
    this.actualEndDate,
    this.budgetPlanned,
    this.budgetActual,
    required this.currency,
    this.estimatedRevenue,
    this.estimatedMargin,
    required this.strategicImportance,
    required this.progressPercent,
    required this.kpi,
    required this.ai,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    required this.updatedAt,
    required this.updatedBy,
    this.closedAt,
    this.closedBy,
    this.closedByName,
    this.releasedToProductionAt,
    this.releasedToProductionBy,
    this.releasedToProductionByName,
    this.releasedToProductionGate,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.'));
  }

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => _s(e)).where((e) => e.isNotEmpty).toList();
  }

  static DevelopmentProjectKpi _kpi(Map<String, dynamic> data) {
    final raw = data['kpi'];
    if (raw is! Map) return DevelopmentProjectKpi.empty();
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return DevelopmentProjectKpi(
      schedulePerformance: _dbl(m['schedulePerformance']),
      costPerformance: _dbl(m['costPerformance']),
      qualityReadiness: _dbl(m['qualityReadiness']),
      gatePassRate: _dbl(m['gatePassRate']),
      riskScore: _dbl(m['riskScore']),
      overallHealthScore: _dbl(m['overallHealthScore']),
    );
  }

  static DevelopmentProjectAi _ai(Map<String, dynamic> data) {
    final raw = data['ai'];
    if (raw is! Map) return DevelopmentProjectAi.empty();
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    return DevelopmentProjectAi(
      lastRiskAnalysisAt: _ts(m['lastRiskAnalysisAt']),
      lastSummaryAt: _ts(m['lastSummaryAt']),
      riskPrediction: _s(m['riskPrediction']),
      delayProbability: _dbl(m['delayProbability']),
      recommendedActionCount: () {
        final n = m['recommendedActionCount'];
        if (n is int) return n;
        if (n is num) return n.toInt();
        return int.tryParse(_s(n));
      }(),
    );
  }

  factory DevelopmentProjectModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final teamMembers = DevelopmentProjectTeamMember.listFromField(data['team']);
    final fromTeamIds = teamMembers.map((e) => e.userId).toList();
    final legacyIds = _strList(data['teamMemberIds']);
    final pmId = _s(data['projectManagerId']);
    final idSet = <String>{...fromTeamIds, ...legacyIds};
    if (pmId.isNotEmpty) idSet.add(pmId);
    final mergedMemberIds = idSet.toList();

    return DevelopmentProjectModel(
      id: doc.id,
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      businessYearId: _s(data['businessYearId']),
      businessYearLabel: _s(data['businessYearLabel']),
      businessYearStart: data['businessYearStart'] is Timestamp
          ? data['businessYearStart'] as Timestamp
          : null,
      businessYearEnd: data['businessYearEnd'] is Timestamp
          ? data['businessYearEnd'] as Timestamp
          : null,
      businessQuarter: _s(data['businessQuarter']),
      businessMonth: _s(data['businessMonth']),
      isCarriedOver: data['isCarriedOver'] == true,
      carriedOverFromBusinessYearId: () {
        final s = _s(data['carriedOverFromBusinessYearId']);
        return s.isEmpty ? null : s;
      }(),
      carriedOverToBusinessYearId: () {
        final s = _s(data['carriedOverToBusinessYearId']);
        return s.isEmpty ? null : s;
      }(),
      projectCode: _s(data['projectCode']),
      projectName: _s(data['projectName']),
      projectType: _s(data['projectType']),
      customerId: _s(data['customerId']).isEmpty ? null : _s(data['customerId']),
      customerName:
          _s(data['customerName']).isEmpty ? null : _s(data['customerName']),
      productId: _s(data['productId']).isEmpty ? null : _s(data['productId']),
      productCode: _s(data['productCode']).isEmpty ? null : _s(data['productCode']),
      productName: _s(data['productName']).isEmpty ? null : _s(data['productName']),
      projectManagerId: _s(data['projectManagerId']),
      projectManagerName: _s(data['projectManagerName']),
      team: teamMembers,
      teamMemberIds: mergedMemberIds,
      status: _s(data['status']),
      currentGate: _s(data['currentGate']),
      currentStage: _s(data['currentStage']),
      priority: _s(data['priority']),
      riskLevel: _s(data['riskLevel']),
      plannedStartDate: _ts(data['plannedStartDate']),
      plannedEndDate: _ts(data['plannedEndDate']),
      actualStartDate: _ts(data['actualStartDate']),
      actualEndDate: _ts(data['actualEndDate']),
      budgetPlanned: _dbl(data['budgetPlanned']),
      budgetActual: _dbl(data['budgetActual']),
      currency: _s(data['currency']).isEmpty ? 'EUR' : _s(data['currency']),
      estimatedRevenue: _dbl(data['estimatedRevenue']),
      estimatedMargin: _dbl(data['estimatedMargin']),
      strategicImportance: _s(data['strategicImportance']),
      progressPercent: () {
        final p = data['progressPercent'];
        if (p is int) return p.clamp(0, 100);
        if (p is num) return p.round().clamp(0, 100);
        return int.tryParse(_s(p)) ?? 0;
      }(),
      kpi: _kpi(data),
      ai: _ai(data),
      createdAt: _ts(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: _s(data['createdBy']),
      createdByName: _s(data['createdByName']),
      updatedAt: _ts(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedBy: _s(data['updatedBy']),
      closedAt: _ts(data['closedAt']),
      closedBy: _s(data['closedBy']).isEmpty ? null : _s(data['closedBy']),
      closedByName: () {
        final s = _s(data['closedByName']);
        return s.isEmpty ? null : s;
      }(),
      releasedToProductionAt: _ts(data['releasedToProductionAt']),
      releasedToProductionBy: () {
        final s = _s(data['releasedToProductionBy']);
        return s.isEmpty ? null : s;
      }(),
      releasedToProductionByName: () {
        final s = _s(data['releasedToProductionByName']);
        return s.isEmpty ? null : s;
      }(),
      releasedToProductionGate: () {
        final s = _s(data['releasedToProductionGate']);
        return s.isEmpty ? null : s;
      }(),
    );
  }
}

class DevelopmentProjectKpi {
  final double? schedulePerformance;
  final double? costPerformance;
  final double? qualityReadiness;
  final double? gatePassRate;
  final double? riskScore;
  final double? overallHealthScore;

  const DevelopmentProjectKpi({
    this.schedulePerformance,
    this.costPerformance,
    this.qualityReadiness,
    this.gatePassRate,
    this.riskScore,
    this.overallHealthScore,
  });

  factory DevelopmentProjectKpi.empty() => const DevelopmentProjectKpi();
}

class DevelopmentProjectAi {
  final DateTime? lastRiskAnalysisAt;
  final DateTime? lastSummaryAt;
  final String riskPrediction;
  final double? delayProbability;
  final int? recommendedActionCount;

  const DevelopmentProjectAi({
    this.lastRiskAnalysisAt,
    this.lastSummaryAt,
    this.riskPrediction = '',
    this.delayProbability,
    this.recommendedActionCount,
  });

  factory DevelopmentProjectAi.empty() => const DevelopmentProjectAi();
}
