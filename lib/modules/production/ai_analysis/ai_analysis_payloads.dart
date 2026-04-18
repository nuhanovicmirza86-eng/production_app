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
      if (windowLabel != null) 'window': windowLabel,
      if (capturedAt != null) 'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (deviceStates != null) 'deviceStates': deviceStates,
      if (telemetryPoints != null) 'telemetryPoints': telemetryPoints,
      if (alarms != null) 'alarms': alarms,
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
      if (periodLabel != null) 'period': periodLabel,
      if (availabilityPct != null) 'availabilityPct': availabilityPct,
      if (performancePct != null) 'performancePct': performancePct,
      if (qualityPct != null) 'qualityPct': qualityPct,
      if (oeePct != null) 'oeePct': oeePct,
      if (losses != null) 'losses': losses,
      if (downtimeSummary != null) 'downtimeSummary': downtimeSummary,
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
      if (orders != null) 'orders': orders,
      if (phases != null) 'phases': phases,
      if (totals != null) 'totals': totals,
    };
  }

  /// Generički: spoji vlastite ključeve (npr. iz `toJson()` modela).
  static Map<String, dynamic> generic(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data);
}
