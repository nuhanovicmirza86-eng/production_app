/// Kanonski stringovi za modul **development** (Firestore + izvještaji).
/// UI prikaz statusa/tipova: [DevelopmentDisplay] — ne prikazivati sirove kodove korisniku.
abstract final class DevelopmentProjectTypes {
  static const String customerNewProduct = 'customer_new_product';
  static const String customerChangeProject = 'customer_change_project';
  static const String internalProductDevelopment = 'internal_product_development';
  static const String internalProcessDevelopment = 'internal_process_development';
  static const String industrializationProject = 'industrialization_project';
  static const String costReductionProject = 'cost_reduction_project';
  static const String qualityImprovementProject = 'quality_improvement_project';
  static const String toolingDevelopment = 'tooling_development';
  static const String digitalizationProject = 'digitalization_project';

  static const List<String> all = [
    customerNewProduct,
    customerChangeProject,
    internalProductDevelopment,
    internalProcessDevelopment,
    industrializationProject,
    costReductionProject,
    qualityImprovementProject,
    toolingDevelopment,
    digitalizationProject,
  ];
}

abstract final class DevelopmentProjectStatuses {
  static const String draft = 'draft';
  static const String proposed = 'proposed';
  static const String approved = 'approved';
  static const String active = 'active';
  static const String onHold = 'on_hold';
  static const String atRisk = 'at_risk';
  static const String delayed = 'delayed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String closed = 'closed';

  static const List<String> all = [
    draft,
    proposed,
    approved,
    active,
    onHold,
    atRisk,
    delayed,
    completed,
    cancelled,
    closed,
  ];
}

/// Stage-Gate kodovi (G0–G9).
/// Slugovi faze (mapiraju se na [DevelopmentGateCodes] u dokumentu).
abstract final class DevelopmentStageKeys {
  /// G0 — Idea / Request
  static const String ideaRequest = 'idea_request';
}

abstract final class DevelopmentGateCodes {
  static const String g0 = 'G0';
  static const String g1 = 'G1';
  static const String g2 = 'G2';
  static const String g3 = 'G3';
  static const String g4 = 'G4';
  static const String g5 = 'G5';
  static const String g6 = 'G6';
  static const String g7 = 'G7';
  static const String g8 = 'G8';
  static const String g9 = 'G9';

  static const List<String> ordered = [
    g0,
    g1,
    g2,
    g3,
    g4,
    g5,
    g6,
    g7,
    g8,
    g9,
  ];
}

abstract final class DevelopmentPriorities {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String critical = 'critical';
}

abstract final class DevelopmentRiskLevels {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String critical = 'critical';
}

/// Statusi zadatka u `development_projects/.../tasks`.
abstract final class DevelopmentTaskStatuses {
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String done = 'done';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    open,
    inProgress,
    done,
    cancelled,
  ];
}

/// Status Gate faze u `development_projects/.../stages`.
abstract final class DevelopmentStageStatuses {
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String skipped = 'skipped';
  static const String blocked = 'blocked';

  static const List<String> all = [
    pending,
    inProgress,
    completed,
    skipped,
    blocked,
  ];
}

/// Status rizika u `development_projects/.../risks`.
abstract final class DevelopmentRiskStatuses {
  static const String open = 'open';
  static const String mitigating = 'mitigating';
  static const String mitigated = 'mitigated';
  static const String accepted = 'accepted';
  static const String closed = 'closed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    open,
    mitigating,
    mitigated,
    accepted,
    closed,
    cancelled,
  ];
}

/// Uloga na projektu (`team[].projectRole`) — ne miješati s globalnim `users.role`.
abstract final class DevelopmentTeamProjectRoles {
  static const String projectManager = 'project_manager';
  static const String technicalOwner = 'technical_owner';
  static const String qualityReviewer = 'quality_reviewer';
  static const String productionReviewer = 'production_reviewer';
  static const String logisticsReviewer = 'logistics_reviewer';
  static const String maintenanceReviewer = 'maintenance_reviewer';
  static const String sponsor = 'sponsor';

  static const List<String> all = [
    projectManager,
    technicalOwner,
    qualityReviewer,
    productionReviewer,
    logisticsReviewer,
    maintenanceReviewer,
    sponsor,
  ];
}

abstract final class DevelopmentRiskCategories {
  static const String technical = 'technical';
  static const String quality = 'quality';
  static const String supplier = 'supplier';
  static const String capacity = 'capacity';
  static const String cost = 'cost';
  static const String deadline = 'deadline';
  static const String customer = 'customer';
  static const String tooling = 'tooling';
  static const String production = 'production';
  static const String logistics = 'logistics';
  static const String regulatory = 'regulatory';

  static const List<String> all = [
    technical,
    quality,
    supplier,
    capacity,
    cost,
    deadline,
    customer,
    tooling,
    production,
    logistics,
    regulatory,
  ];
}
