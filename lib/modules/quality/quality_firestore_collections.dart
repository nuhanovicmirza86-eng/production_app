/// Kanonska imena Firestore kolekcija za QMS (vidi `QUALITY_SCHEMA.md` §9).
///
/// **NCR / incident:** operativni zapis nesukladnosti je [nonConformances] (`ncrCode`,
/// `sourceModule`, `fiveWhySteps`, veza na `action_plans`). Širi „quality_incidents“
/// koncept mapira se ovdje — zasebna kolekcija nije obavezna za zatvoreni IATF krug.
abstract final class QualityFirestoreCollections {
  static const controlPlans = 'control_plans';
  static const inspectionPlans = 'inspection_plans';
  static const inspectionResults = 'inspection_results';
  static const nonConformances = 'non_conformances';
  static const actionPlans = 'action_plans';
  static const qualityHolds = 'quality_holds';
  static const qualityEvents = 'quality_events';

  /// PFMEA redovi (proces / proizvod) — samo Callable; vidi `quality_qms_writes.js`.
  static const qmsPfmeaRows = 'qms_pfmea_rows';
}
