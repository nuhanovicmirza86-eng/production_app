import '../models/carbon_models.dart';

class CarbonCalculationService {
  const CarbonCalculationService._();

  static double lineKgCo2e(
    CarbonActivityLine line,
    Map<String, CarbonEmissionFactor> factorsByKey,
  ) {
    if (!line.include || line.quantity <= 0) return 0;
    final f = factorsByKey[line.factorKey];
    if (f == null) return 0;
    return line.quantity * f.factorKgCo2ePerUnit;
  }

  static CarbonDashboardSummary summarize({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    var s1 = 0.0;
    var s2 = 0.0;
    var s3 = 0.0;
    var included = 0;
    var withQty = 0;

    for (final a in activities) {
      if (!a.include) continue;
      included++;
      if (a.quantity > 0) withQty++;
      final kg = lineKgCo2e(a, factorsByKey);
      if (kg <= 0) continue;
      final sc = factorsByKey[a.factorKey]?.scope ?? '3';
      if (sc == '1') {
        s1 += kg;
      } else if (sc == '2') {
        s2 += kg;
      } else {
        s3 += kg;
      }
    }

    final totalKg = s1 + s2 + s3;
    final totalT = totalKg / 1000;

    final emp = setup.employeeCount;
    final perEmpT = emp > 0 ? totalT / emp : 0.0;

    final units = setup.unitsProduced;
    final perUnitKg = units > 0 ? totalKg / units : 0.0;

    final rev = setup.revenue;
    final per1000Rev =
        rev > 0 ? (totalT / rev) * 1000.0 : 0.0;

    return CarbonDashboardSummary(
      totalKgCo2e: totalKg,
      scope1Kg: s1,
      scope2Kg: s2,
      scope3Kg: s3,
      totalTCO2e: totalT,
      perEmployeeTCO2e: perEmpT,
      perUnitKgCo2e: perUnitKg,
      per1000RevenueTCO2e: per1000Rev,
      includedActivityCount: included,
      rowsWithQuantity: withQty,
    );
  }

  /// Cilj iz % smanjenja u odnosu na baznu godinu (tCO2e).
  static double targetFromReductionTCO2e(CarbonQuotaSettings q) {
    if (q.baselineEmissionsTCO2e <= 0 || q.reductionTargetPercent <= 0) {
      return 0;
    }
    final f = 1.0 - (q.reductionTargetPercent / 100.0);
    return q.baselineEmissionsTCO2e * f;
  }

  static double effectiveQuotaTCO2e(CarbonQuotaSettings q) {
    if (q.absoluteQuotaTCO2e > 0) return q.absoluteQuotaTCO2e;
    return targetFromReductionTCO2e(q);
  }
}
