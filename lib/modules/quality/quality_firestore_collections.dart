/// Kanonska imena Firestore kolekcija za QMS (vidi `QUALITY_SCHEMA.md` §9).
abstract final class QualityFirestoreCollections {
  static const controlPlans = 'control_plans';
  static const inspectionPlans = 'inspection_plans';
  static const inspectionResults = 'inspection_results';
  static const nonConformances = 'non_conformances';
  static const actionPlans = 'action_plans';
  static const qualityHolds = 'quality_holds';
  static const qualityEvents = 'quality_events';
}
