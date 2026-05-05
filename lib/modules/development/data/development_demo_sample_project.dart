import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/development_project_model.dart';
import '../models/development_project_team_member.dart';
import '../utils/development_constants.dart';

/// Jedan red u listi dokumenata na demo ekranu (nije Firestore model).
class DevelopmentDemoDocumentRow {
  const DevelopmentDemoDocumentRow({
    required this.title,
    required this.docType,
    required this.status,
    this.linkedGate,
    this.externalRef,
  });

  final String title;
  final String docType;
  final String status;
  final String? linkedGate;
  final String? externalRef;
}

/// Ilustrativni popis dokumenata (crteži, specifikacije, zahtjevi kupca …) za demo.
List<DevelopmentDemoDocumentRow> buildDevelopmentDemoDocumentRows() {
  return const [
    DevelopmentDemoDocumentRow(
      title: 'Crtež sklopa — HOUS-440-REV-C (PDF/DXF)',
      docType: DevelopmentDocumentTypes.drawing,
      status: DevelopmentDocumentStatuses.approved,
      linkedGate: DevelopmentGateCodes.g3,
      externalRef: 'PDM://ACME/HOUS-440/revC',
    ),
    DevelopmentDemoDocumentRow(
      title: 'Specifikacija materijala — EN AW-6061 T6, anodizacija',
      docType: DevelopmentDocumentTypes.spec,
      status: DevelopmentDocumentStatuses.approved,
      linkedGate: DevelopmentGateCodes.g2,
    ),
    DevelopmentDemoDocumentRow(
      title: 'Zahtjev kupca (CSR) ACME-2026-014 — tolerancije i funkcija',
      docType: DevelopmentDocumentTypes.report,
      status: DevelopmentDocumentStatuses.submitted,
      linkedGate: DevelopmentGateCodes.g1,
      externalRef: 'SharePoint://CSR/ACME-2026-014',
    ),
    DevelopmentDemoDocumentRow(
      title: 'DFMEA / PFMEA — radna verzija',
      docType: DevelopmentDocumentTypes.report,
      status: DevelopmentDocumentStatuses.draft,
      linkedGate: DevelopmentGateCodes.g5,
    ),
    DevelopmentDemoDocumentRow(
      title: 'MSA plan — ključne dimenzije serije A',
      docType: DevelopmentDocumentTypes.protocol,
      status: DevelopmentDocumentStatuses.draft,
      linkedGate: DevelopmentGateCodes.g7,
    ),
    DevelopmentDemoDocumentRow(
      title: 'PPAP indeks i kontrolna lista (predajni paket)',
      docType: DevelopmentDocumentTypes.checklist,
      status: DevelopmentDocumentStatuses.draft,
      linkedGate: DevelopmentGateCodes.g7,
    ),
  ];
}

/// Ilustrativni projekt za **demo puni ekran** (bez Firestorea).
DevelopmentProjectModel buildDevelopmentDemoSampleProject({
  required String companyId,
  required String plantKey,
}) {
  final now = DateTime.now();
  final y0 = DateTime(now.year, 1, 1);
  final y1 = DateTime(now.year, 12, 31);
  final startM = now.month > 2 ? now.month - 2 : 1;
  final endM = now.month < 10 ? now.month + 3 : 12;

  return DevelopmentProjectModel(
    id: '_demo_fullscreen',
    companyId: companyId.isEmpty ? 'demo-tenant' : companyId,
    plantKey: plantKey.isEmpty ? 'demo-plant' : plantKey,
    businessYearId: 'fy-${now.year}',
    businessYearLabel: '${now.year}',
    businessYearStart: Timestamp.fromDate(y0),
    businessYearEnd: Timestamp.fromDate(y1),
    businessQuarter: 'Q${((now.month - 1) ~/ 3) + 1}',
    businessMonth: '${now.month}',
    projectCode: 'NPI-DEMO-2026',
    projectName: 'Housing NPI — serija A (demonstracija)',
    projectType: DevelopmentProjectTypes.customerNewProduct,
    customerId: 'cust-demo-1',
    customerName: 'ACME Automotive GmbH',
    productId: 'prod-demo-housing',
    productCode: 'HOUS-440-ANO',
    productName: 'Alu housing 440 / anodizirano',
    projectManagerId: 'pm-demo',
    projectManagerName: 'Ana Horvat (demo)',
    team: [
      const DevelopmentProjectTeamMember(
        userId: 'u1',
        displayName: 'Ivan Konstrukcija',
        projectRole: 'technical_owner',
        systemRole: 'development_engineer',
        canEditTasks: true,
        canUploadDocuments: true,
        canApproveGate: false,
      ),
      const DevelopmentProjectTeamMember(
        userId: 'u2',
        displayName: 'Marko Kvaliteta',
        projectRole: 'quality_representative',
        systemRole: 'quality_control',
        canEditTasks: true,
        canUploadDocuments: true,
        canApproveGate: true,
      ),
    ],
    teamMemberIds: const ['pm-demo', 'u1', 'u2'],
    status: DevelopmentProjectStatuses.active,
    currentGate: DevelopmentGateCodes.g7,
    currentStage: 'industrialization_readiness',
    priority: DevelopmentPriorities.high,
    riskLevel: DevelopmentRiskLevels.medium,
    plannedStartDate: DateTime(now.year, startM, 1),
    plannedEndDate: DateTime(now.year, endM, 15),
    actualStartDate: DateTime(now.year, startM, 3),
    budgetPlanned: 185000,
    budgetActual: 162400,
    currency: 'EUR',
    estimatedRevenue: 420000,
    estimatedMargin: 22.5,
    strategicImportance: 'high',
    progressPercent: 68,
    kpi: const DevelopmentProjectKpi(
      schedulePerformance: 82,
      costPerformance: 76,
      qualityReadiness: 88,
      gatePassRate: 91,
      riskScore: 74,
      overallHealthScore: 81,
    ),
    ai: const DevelopmentProjectAi(
      riskPrediction:
          'Probna serija G5 zatvorena; fokus na stabilizaciju u G7 prije PPAP.',
      delayProbability: 0.18,
      recommendedActionCount: 4,
    ),
    createdAt: DateTime(now.year, 1, 10),
    createdBy: 'system-demo',
    createdByName: 'Sistem (demo)',
    updatedAt: now,
    updatedBy: 'pm-demo',
    releasedToProductionAt: null,
  );
}

/// Lokalna ekstenzija za brze varijante demo projekata (grafovi).
extension DevelopmentProjectModelDemoOverrides on DevelopmentProjectModel {
  DevelopmentProjectModel withDemoOverrides({
    String? id,
    String? projectCode,
    String? projectName,
    String? status,
    String? currentGate,
    String? currentStage,
    String? riskLevel,
    int? progressPercent,
    DevelopmentProjectKpi? kpi,
    DateTime? releasedToProductionAt,
  }) {
    return DevelopmentProjectModel(
      id: id ?? this.id,
      companyId: companyId,
      plantKey: plantKey,
      businessYearId: businessYearId,
      businessYearLabel: businessYearLabel,
      businessYearStart: businessYearStart,
      businessYearEnd: businessYearEnd,
      businessQuarter: businessQuarter,
      businessMonth: businessMonth,
      isCarriedOver: isCarriedOver,
      carriedOverFromBusinessYearId: carriedOverFromBusinessYearId,
      carriedOverToBusinessYearId: carriedOverToBusinessYearId,
      projectCode: projectCode ?? this.projectCode,
      projectName: projectName ?? this.projectName,
      projectType: projectType,
      customerId: customerId,
      customerName: customerName,
      productId: productId,
      productCode: productCode,
      productName: productName,
      projectManagerId: projectManagerId,
      projectManagerName: projectManagerName,
      team: team,
      teamMemberIds: teamMemberIds,
      status: status ?? this.status,
      currentGate: currentGate ?? this.currentGate,
      currentStage: currentStage ?? this.currentStage,
      priority: priority,
      riskLevel: riskLevel ?? this.riskLevel,
      plannedStartDate: plannedStartDate,
      plannedEndDate: plannedEndDate,
      actualStartDate: actualStartDate,
      actualEndDate: actualEndDate,
      budgetPlanned: budgetPlanned,
      budgetActual: budgetActual,
      currency: currency,
      estimatedRevenue: estimatedRevenue,
      estimatedMargin: estimatedMargin,
      strategicImportance: strategicImportance,
      progressPercent: progressPercent ?? this.progressPercent,
      kpi: kpi ?? this.kpi,
      ai: ai,
      createdAt: createdAt,
      createdBy: createdBy,
      createdByName: createdByName,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      closedAt: closedAt,
      closedBy: closedBy,
      closedByName: closedByName,
      releasedToProductionAt:
          releasedToProductionAt ?? this.releasedToProductionAt,
      releasedToProductionBy: releasedToProductionBy,
      releasedToProductionByName: releasedToProductionByName,
      releasedToProductionGate: releasedToProductionGate,
    );
  }
}

/// Više ilustrativnih projekata da stubičasti graf i trake životnog ciklusa imaju smisla kad Firestore vraća prazno.
List<DevelopmentProjectModel> buildDevelopmentDemoPortfolioForAnalytics({
  required String companyId,
  required String plantKey,
}) {
  final base = buildDevelopmentDemoSampleProject(
    companyId: companyId,
    plantKey: plantKey,
  );
  final now = DateTime.now();
  return [
    base,
    base.withDemoOverrides(
      id: '_demo_port_g3',
      projectCode: 'NPI-SENS-12',
      projectName: 'Senzor položaja — interni NPI',
      status: DevelopmentProjectStatuses.active,
      currentGate: DevelopmentGateCodes.g3,
      currentStage: 'design_validation',
      riskLevel: DevelopmentRiskLevels.low,
      progressPercent: 35,
      kpi: const DevelopmentProjectKpi(
        schedulePerformance: 70,
        costPerformance: 65,
        qualityReadiness: 74,
        gatePassRate: 80,
        riskScore: 88,
        overallHealthScore: 72,
      ),
    ),
    base.withDemoOverrides(
      id: '_demo_port_risk',
      projectCode: 'NPI-BRAKE-03',
      projectName: 'Kočiona čeljust — kupac CRX',
      status: DevelopmentProjectStatuses.atRisk,
      currentGate: DevelopmentGateCodes.g5,
      currentStage: 'pilot_run',
      riskLevel: DevelopmentRiskLevels.high,
      progressPercent: 52,
      kpi: const DevelopmentProjectKpi(
        schedulePerformance: 48,
        costPerformance: 55,
        qualityReadiness: 60,
        gatePassRate: 62,
        riskScore: 44,
        overallHealthScore: 52,
      ),
    ),
    base.withDemoOverrides(
      id: '_demo_port_done',
      projectCode: 'NPI-LEGACY-99',
      projectName: 'Zatvoren projekat (arhiva)',
      status: DevelopmentProjectStatuses.completed,
      currentGate: DevelopmentGateCodes.g9,
      currentStage: 'lesson_learned',
      riskLevel: DevelopmentRiskLevels.low,
      progressPercent: 100,
      kpi: const DevelopmentProjectKpi(
        schedulePerformance: 92,
        costPerformance: 90,
        qualityReadiness: 91,
        gatePassRate: 95,
        riskScore: 90,
        overallHealthScore: 91,
      ),
      releasedToProductionAt: now.subtract(const Duration(days: 40)),
    ),
    base.withDemoOverrides(
      id: '_demo_port_g1',
      projectCode: 'NPI-PLAST-07',
      projectName: 'Kućište injektora — quotation',
      status: DevelopmentProjectStatuses.proposed,
      currentGate: DevelopmentGateCodes.g1,
      currentStage: 'idea_request',
      riskLevel: DevelopmentRiskLevels.medium,
      progressPercent: 12,
      kpi: const DevelopmentProjectKpi(
        schedulePerformance: 78,
        costPerformance: 72,
        qualityReadiness: 70,
        gatePassRate: 75,
        riskScore: 70,
        overallHealthScore: 66,
      ),
    ),
  ];
}
