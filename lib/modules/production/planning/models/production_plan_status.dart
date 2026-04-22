/// Status generiranog plana (client-side / kasnije Firestore).
enum ProductionPlanStatus {
  /// Tek izračun, nije spremljen u `production_plans`.
  draft,
  simulated,
  confirmed,
  released,
}

String productionPlanStatusCode(ProductionPlanStatus s) {
  switch (s) {
    case ProductionPlanStatus.draft:
      return 'draft';
    case ProductionPlanStatus.simulated:
      return 'simulated';
    case ProductionPlanStatus.confirmed:
      return 'confirmed';
    case ProductionPlanStatus.released:
      return 'released';
  }
}

ProductionPlanStatus? productionPlanStatusFromCode(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'draft':
      return ProductionPlanStatus.draft;
    case 'simulated':
      return ProductionPlanStatus.simulated;
    case 'confirmed':
      return ProductionPlanStatus.confirmed;
    case 'released':
      return ProductionPlanStatus.released;
    default:
      return null;
  }
}
