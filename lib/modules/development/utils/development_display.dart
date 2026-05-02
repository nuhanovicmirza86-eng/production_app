import 'development_constants.dart';

/// Lokalizirani prikazi za module keys (ne prikazivati sirove kodove iz Firestorea).
abstract final class DevelopmentDisplay {
  static String projectTypeLabel(String code) {
    switch (code.trim()) {
      case DevelopmentProjectTypes.customerNewProduct:
        return 'Novi proizvod za kupca';
      case DevelopmentProjectTypes.customerChangeProject:
        return 'Izmjena za kupca';
      case DevelopmentProjectTypes.internalProductDevelopment:
        return 'Interni novi proizvod';
      case DevelopmentProjectTypes.internalProcessDevelopment:
        return 'Razvoj / poboljšanje procesa';
      case DevelopmentProjectTypes.industrializationProject:
        return 'Industrijalizacija';
      case DevelopmentProjectTypes.costReductionProject:
        return 'Smanjenje troškova';
      case DevelopmentProjectTypes.qualityImprovementProject:
        return 'Poboljšanje kvaliteta';
      case DevelopmentProjectTypes.toolingDevelopment:
        return 'Alati / naprave / oprema';
      case DevelopmentProjectTypes.digitalizationProject:
        return 'Digitalizacija / IT / automatizacija';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String projectStatusLabel(String code) {
    switch (code.trim()) {
      case DevelopmentProjectStatuses.draft:
        return 'Nacrt';
      case DevelopmentProjectStatuses.proposed:
        return 'Predložen';
      case DevelopmentProjectStatuses.approved:
        return 'Odobren';
      case DevelopmentProjectStatuses.active:
        return 'Aktivan';
      case DevelopmentProjectStatuses.onHold:
        return 'Pauza';
      case DevelopmentProjectStatuses.atRisk:
        return 'U riziku';
      case DevelopmentProjectStatuses.delayed:
        return 'Kašnjenje';
      case DevelopmentProjectStatuses.completed:
        return 'Završen (aktivnosti)';
      case DevelopmentProjectStatuses.cancelled:
        return 'Otkazan';
      case DevelopmentProjectStatuses.closed:
        return 'Zatvoren';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String taskStatusLabel(String code) {
    switch (code.trim()) {
      case DevelopmentTaskStatuses.open:
        return 'Otvoren';
      case DevelopmentTaskStatuses.inProgress:
        return 'U tijeku';
      case DevelopmentTaskStatuses.done:
        return 'Gotov';
      case DevelopmentTaskStatuses.cancelled:
        return 'Otkazan';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String stageStatusLabel(String code) {
    switch (code.trim()) {
      case DevelopmentStageStatuses.pending:
        return 'Na čekanju';
      case DevelopmentStageStatuses.inProgress:
        return 'U tijeku';
      case DevelopmentStageStatuses.completed:
        return 'Završeno';
      case DevelopmentStageStatuses.skipped:
        return 'Preskočeno';
      case DevelopmentStageStatuses.blocked:
        return 'Blokirano';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String riskStatusLabel(String code) {
    switch (code.trim()) {
      case DevelopmentRiskStatuses.open:
        return 'Otvoren';
      case DevelopmentRiskStatuses.mitigating:
        return 'U ublažavanju';
      case DevelopmentRiskStatuses.mitigated:
        return 'Ublažen';
      case DevelopmentRiskStatuses.accepted:
        return 'Prihvaćen';
      case DevelopmentRiskStatuses.closed:
        return 'Zatvoren';
      case DevelopmentRiskStatuses.cancelled:
        return 'Otkazan';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String riskSeverityLabel(String code) {
    switch (code.trim()) {
      case DevelopmentRiskLevels.low:
        return 'Nizak';
      case DevelopmentRiskLevels.medium:
        return 'Srednji';
      case DevelopmentRiskLevels.high:
        return 'Visok';
      case DevelopmentRiskLevels.critical:
        return 'Kritičan';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String riskCategoryLabel(String code) {
    switch (code.trim()) {
      case DevelopmentRiskCategories.technical:
        return 'Tehnički';
      case DevelopmentRiskCategories.quality:
        return 'Kvaliteta';
      case DevelopmentRiskCategories.supplier:
        return 'Dobavljač';
      case DevelopmentRiskCategories.capacity:
        return 'Kapacitet';
      case DevelopmentRiskCategories.cost:
        return 'Trošak';
      case DevelopmentRiskCategories.deadline:
        return 'Rok';
      case DevelopmentRiskCategories.customer:
        return 'Kupac';
      case DevelopmentRiskCategories.tooling:
        return 'Alat / oprema';
      case DevelopmentRiskCategories.production:
        return 'Proizvodnja';
      case DevelopmentRiskCategories.logistics:
        return 'Logistika';
      case DevelopmentRiskCategories.regulatory:
        return 'Regulatorno';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String documentTypeLabel(String code) {
    switch (code.trim()) {
      case DevelopmentDocumentTypes.spec:
        return 'Specifikacija';
      case DevelopmentDocumentTypes.drawing:
        return 'Crtež';
      case DevelopmentDocumentTypes.protocol:
        return 'Protokol';
      case DevelopmentDocumentTypes.certificate:
        return 'Certifikat';
      case DevelopmentDocumentTypes.checklist:
        return 'Kontrolna lista';
      case DevelopmentDocumentTypes.report:
        return 'Izvještaj';
      case DevelopmentDocumentTypes.other:
        return 'Ostalo';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String documentStatusLabel(String code) {
    switch (code.trim()) {
      case DevelopmentDocumentStatuses.draft:
        return 'Nacrt';
      case DevelopmentDocumentStatuses.submitted:
        return 'Predan';
      case DevelopmentDocumentStatuses.approved:
        return 'Odobren';
      case DevelopmentDocumentStatuses.obsolete:
        return 'Zastario';
      case DevelopmentDocumentStatuses.rejected:
        return 'Odbijen';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  static String teamProjectRoleLabel(String code) {
    switch (code.trim()) {
      case DevelopmentTeamProjectRoles.projectManager:
        return 'Voditelj projekta';
      case DevelopmentTeamProjectRoles.technicalOwner:
        return 'Tehnički vlasnik';
      case DevelopmentTeamProjectRoles.qualityReviewer:
        return 'Kvaliteta (review)';
      case DevelopmentTeamProjectRoles.productionReviewer:
        return 'Proizvodnja (review)';
      case DevelopmentTeamProjectRoles.logisticsReviewer:
        return 'Logistika (review)';
      case DevelopmentTeamProjectRoles.maintenanceReviewer:
        return 'Održavanje (review)';
      case DevelopmentTeamProjectRoles.sponsor:
        return 'Sponsor';
      default:
        return code.isEmpty ? '—' : code;
    }
  }
}
