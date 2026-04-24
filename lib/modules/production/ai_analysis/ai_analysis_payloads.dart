/// Pomoć za građenje [payload] mape za [AiAnalysisService.run].
///
/// UI sloj puni ova polja iz stvarnih modela (Firestore dokumenti, state, DTO).
/// Ključevi su konvencija radi čitljivosti u promptu; backend prihvaća bilo koji JSON objekt.
class AiAnalysisPayloads {
  AiAnalysisPayloads._();

  /// SCADA / live: snimak telemetrije, uređaja, stanja.
  static Map<String, dynamic> scadaSnapshot({
    required String source,
    Map<String, dynamic>? deviceStates,
    List<Map<String, dynamic>>? telemetryPoints,
    Map<String, dynamic>? alarms,
    String? windowLabel,
    DateTime? capturedAt,
  }) {
    return <String, dynamic>{
      'kind': 'scada_snapshot',
      'source': source,
      'window': ?windowLabel,
      if (capturedAt != null) 'capturedAt': capturedAt.toUtc().toIso8601String(),
      'deviceStates': ?deviceStates,
      'telemetryPoints': ?telemetryPoints,
      'alarms': ?alarms,
    };
  }

  /// OEE / KPI blok (postoci, gubici, zastoji).
  static Map<String, dynamic> oeeBlock({
    double? availabilityPct,
    double? performancePct,
    double? qualityPct,
    double? oeePct,
    Map<String, dynamic>? losses,
    Map<String, dynamic>? downtimeSummary,
    String? periodLabel,
  }) {
    return <String, dynamic>{
      'kind': 'oee_block',
      'period': ?periodLabel,
      'availabilityPct': ?availabilityPct,
      'performancePct': ?performancePct,
      'qualityPct': ?qualityPct,
      'oeePct': ?oeePct,
      'losses': ?losses,
      'downtimeSummary': ?downtimeSummary,
    };
  }

  /// Tok proizvodnje: nalozi, faze, količine (proizvoljan oblik liste koraka).
  static Map<String, dynamic> productionFlow({
    required String label,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? phases,
    Map<String, dynamic>? totals,
  }) {
    return <String, dynamic>{
      'kind': 'production_flow',
      'label': label,
      'orders': ?orders,
      'phases': ?phases,
      'totals': ?totals,
    };
  }

  /// Generički: spoji vlastite ključeve (npr. iz `toJson()` modela).
  static Map<String, dynamic> generic(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data);
}
