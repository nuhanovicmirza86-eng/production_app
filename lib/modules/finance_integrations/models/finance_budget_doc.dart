import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan red u `companies/{companyId}/finance_budgets`.
class FinanceBudgetDoc {
  FinanceBudgetDoc({
    required this.id,
    required this.name,
    required this.costCenterId,
    required this.plantKey,
    required this.currency,
    required this.plannedAmount,
    required this.actualAmount,
    required this.variance,
  });

  final String id;
  final String name;
  final String costCenterId;
  final String plantKey;
  final String currency;
  final double? plannedAmount;
  final double? actualAmount;
  final double? variance;

  static FinanceBudgetDoc fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? <String, dynamic>{};
    return FinanceBudgetDoc(
      id: d.id,
      name: (m['name'] ?? '').toString().trim(),
      costCenterId: (m['costCenterId'] ?? '').toString().trim(),
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      currency: (m['currency'] ?? 'EUR').toString().trim().toUpperCase(),
      plannedAmount: _readDouble(m['plannedAmount']),
      actualAmount: _readDouble(m['actualAmount']),
      variance: _readDouble(m['variance']),
    );
  }

  static double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Varijanca iz dokumenta ili ostvareno − plan.
  double? get effectiveVariance {
    if (variance != null) return variance;
    if (plannedAmount == null && actualAmount == null) return null;
    return (actualAmount ?? 0) - (plannedAmount ?? 0);
  }
}

/// Zbrojevi za karticu „Budžet vs ostvarenje“ (samo stavke u [baseCurrency]).
class FinanceBudgetRollup {
  const FinanceBudgetRollup({
    required this.sumPlanned,
    required this.sumActual,
    required this.sumVariance,
    required this.includedCount,
    required this.excludedOtherCurrency,
  });

  final double sumPlanned;
  final double sumActual;
  final double sumVariance;
  final int includedCount;
  final int excludedOtherCurrency;

  static FinanceBudgetRollup summarize(
    List<FinanceBudgetDoc> list,
    String baseCurrency,
  ) {
    final bc = baseCurrency.trim().toUpperCase();
    var sp = 0.0;
    var sa = 0.0;
    var sv = 0.0;
    var inc = 0;
    var exc = 0;
    for (final b in list) {
      final c = b.currency.trim().toUpperCase();
      if (c.isNotEmpty && c != bc) {
        exc++;
        continue;
      }
      inc++;
      sp += b.plannedAmount ?? 0;
      sa += b.actualAmount ?? 0;
      final ev = b.effectiveVariance;
      sv += ev ?? ((b.actualAmount ?? 0) - (b.plannedAmount ?? 0));
    }
    return FinanceBudgetRollup(
      sumPlanned: sp,
      sumActual: sa,
      sumVariance: sv,
      includedCount: inc,
      excludedOtherCurrency: exc,
    );
  }
}
