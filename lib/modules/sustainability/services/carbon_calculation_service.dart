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
    final per1000Rev = rev > 0 ? (totalT / rev) * 1000.0 : 0.0;

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

  /// Zbroj uključenih redova po `plantKey` (isti obračun kao [lineKgCo2e]).
  static List<CarbonPlantRollup> rollupsByPlant({
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final kgByPlant = <String, double>{};
    final countByPlant = <String, int>{};

    for (final a in activities) {
      if (!a.include) continue;
      final kg = lineKgCo2e(a, factorsByKey);
      if (kg <= 0) continue;
      final pk = a.plantKey.trim();
      kgByPlant[pk] = (kgByPlant[pk] ?? 0) + kg;
      countByPlant[pk] = (countByPlant[pk] ?? 0) + 1;
    }

    final keys = kgByPlant.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty && b.isNotEmpty) return 1;
        if (a.isNotEmpty && b.isEmpty) return -1;
        return a.compareTo(b);
      });

    return keys
        .map(
          (k) => CarbonPlantRollup(
            plantKey: k,
            totalKgCo2e: kgByPlant[k]!,
            totalTCO2e: kgByPlant[k]! / 1000,
            lineCount: countByPlant[k] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// Zbroj samo redova s nepraznim `productId` (opcionalna dodjela proizvodu).
  static List<CarbonProductRollup> rollupsByProduct({
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final kgByKey = <String, double>{};
    final countByKey = <String, int>{};
    final labelByKey = <String, String>{};
    final codeByKey = <String, String>{};
    final outputQtyByKey = <String, double>{};

    for (final a in activities) {
      if (!a.include) continue;
      final pid = a.productId.trim();
      if (pid.isEmpty) continue;
      final kg = lineKgCo2e(a, factorsByKey);
      if (kg <= 0) continue;
      kgByKey[pid] = (kgByKey[pid] ?? 0) + kg;
      countByKey[pid] = (countByKey[pid] ?? 0) + 1;
      final lb = a.productLabel.trim();
      if (lb.isNotEmpty) labelByKey[pid] = lb;
      final pc = a.productCode.trim();
      if (pc.isNotEmpty) codeByKey[pid] = pc;
      final po = a.productOutputQty;
      if (po > 0) {
        outputQtyByKey[pid] = (outputQtyByKey[pid] ?? 0) + po;
      }
    }

    final keys = kgByKey.keys.toList()..sort();
    return keys
        .map(
          (k) => CarbonProductRollup(
            productId: k,
            productCode: codeByKey[k] ?? '',
            productLabel: labelByKey[k] ?? '',
            totalKgCo2e: kgByKey[k]!,
            totalTCO2e: kgByKey[k]! / 1000,
            lineCount: countByKey[k] ?? 0,
            totalProductOutputQty: outputQtyByKey[k] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// Cilj iz % smanjenja u odnosu na baznu godinu (tCO2e).
  static double targetFromReductionTCO2e(CarbonQuotaSettings q) {
    if (q.baselineEmissionsTCO2e <= 0 || q.reductionTargetPercent <= 0) {
      return 0;
    }
    var f = 1.0 - (q.reductionTargetPercent / 100.0);
    if (f < 0) f = 0;
    return q.baselineEmissionsTCO2e * f;
  }

  static double effectiveQuotaTCO2e(CarbonQuotaSettings q) {
    if (q.absoluteQuotaTCO2e > 0) return q.absoluteQuotaTCO2e;
    return targetFromReductionTCO2e(q);
  }

  /// Zbroj uključenih aktivnosti s nepraznim `productId` (za PDF „samo dodjela proizvodu”).
  static List<CarbonActivityLine> activitiesAttributedToProducts(
    List<CarbonActivityLine> activities,
  ) {
    return activities
        .where((a) => a.include && a.productId.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// Razrada po `plantKey` s kg CO2e po GHG scopeu.
  static List<CarbonPlantDetailedRollup> rollupsByPlantWithScopes({
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final s1 = <String, double>{};
    final s2 = <String, double>{};
    final s3 = <String, double>{};
    final cnt = <String, int>{};

    for (final a in activities) {
      if (!a.include) continue;
      final kg = lineKgCo2e(a, factorsByKey);
      if (kg <= 0) continue;
      final pk = a.plantKey.trim();
      final sc = (factorsByKey[a.factorKey]?.scope ?? '3').trim();
      cnt[pk] = (cnt[pk] ?? 0) + 1;
      if (sc == '1') {
        s1[pk] = (s1[pk] ?? 0) + kg;
      } else if (sc == '2') {
        s2[pk] = (s2[pk] ?? 0) + kg;
      } else {
        s3[pk] = (s3[pk] ?? 0) + kg;
      }
    }

    final keys = cnt.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty && b.isNotEmpty) return 1;
        if (a.isNotEmpty && b.isEmpty) return -1;
        return a.compareTo(b);
      });

    return keys
        .map(
          (k) => CarbonPlantDetailedRollup(
            plantKey: k,
            scope1Kg: s1[k] ?? 0,
            scope2Kg: s2[k] ?? 0,
            scope3Kg: s3[k] ?? 0,
            lineCount: cnt[k] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// Grupiranje: pogon → proizvod, s scope zbrojevima (samo redovi s productId).
  static List<CarbonProductPlantRollup> rollupsByPlantThenProduct({
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final s1 = <String, double>{};
    final s2 = <String, double>{};
    final s3 = <String, double>{};
    final cnt = <String, int>{};
    final out = <String, double>{};
    final code = <String, String>{};
    final label = <String, String>{};

    String composite(String plantKey, String productId) =>
        '$plantKey\u0001$productId';

    for (final a in activities) {
      if (!a.include) continue;
      final pid = a.productId.trim();
      if (pid.isEmpty) continue;
      final kg = lineKgCo2e(a, factorsByKey);
      if (kg <= 0) continue;
      final pk = a.plantKey.trim();
      final key = composite(pk, pid);
      final sc = (factorsByKey[a.factorKey]?.scope ?? '3').trim();
      cnt[key] = (cnt[key] ?? 0) + 1;
      if (sc == '1') {
        s1[key] = (s1[key] ?? 0) + kg;
      } else if (sc == '2') {
        s2[key] = (s2[key] ?? 0) + kg;
      } else {
        s3[key] = (s3[key] ?? 0) + kg;
      }
      final po = a.productOutputQty;
      if (po > 0) {
        out[key] = (out[key] ?? 0) + po;
      }
      final pc = a.productCode.trim();
      if (pc.isNotEmpty) code[key] = pc;
      final lb = a.productLabel.trim();
      if (lb.isNotEmpty) label[key] = lb;
    }

    final rows = <CarbonProductPlantRollup>[];
    for (final key in cnt.keys) {
      final parts = key.split('\u0001');
      if (parts.length != 2) continue;
      final pk = parts[0];
      final pid = parts[1];
      rows.add(
        CarbonProductPlantRollup(
          plantKey: pk,
          productId: pid,
          productCode: code[key] ?? '',
          productLabel: label[key] ?? '',
          scope1Kg: s1[key] ?? 0,
          scope2Kg: s2[key] ?? 0,
          scope3Kg: s3[key] ?? 0,
          lineCount: cnt[key] ?? 0,
          totalProductOutputQty: out[key] ?? 0,
        ),
      );
    }

    rows.sort((a, b) {
      final pa = a.displayPlant.toLowerCase();
      final pb = b.displayPlant.toLowerCase();
      if (pa != pb) {
        if (a.plantKey.isEmpty && b.plantKey.isNotEmpty) return 1;
        if (a.plantKey.isNotEmpty && b.plantKey.isEmpty) return -1;
        return pa.compareTo(pb);
      }
      return a.displayProductTitle.toLowerCase().compareTo(
            b.displayProductTitle.toLowerCase(),
          );
    });

    return rows;
  }
}
