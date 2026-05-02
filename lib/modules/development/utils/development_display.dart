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
