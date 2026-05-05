/// Parsiranje `companies.financeControllingDefaults` za prikaz valute (baza vs. zaslon).
class FinanceControllingDefaultsView {
  const FinanceControllingDefaultsView({
    required this.baseCurrency,
    required this.displayCurrency,
    this.machineHourlyRate,
    this.copqScrapUnitCostInBase,
    this.copqReworkUnitCostInBase,
    this.copqClosedNcrEstimateInBase,
    this.maintenanceCostPerClosedFaultInBase,
    this.plantEnergyCostBudgetMonthlyInBase = const {},
  });

  /// Valuta u kojoj engine i Firestore agregati drže iznose (mora biti jedna).
  final String baseCurrency;

  /// Valuta koju korisnik vidi u UI (konverzija u Flutter sloju).
  final String displayCurrency;

  /// Satnica mašine u [baseCurrency] (KPI gubitak zastoja); opcionalno ako još nije u dokumentu.
  final double? machineHourlyRate;

  /// Jedinični trošak scrappa (bazna valuta / kom) za KPI COPQ iz `production_orders`.
  final double? copqScrapUnitCostInBase;

  /// Jedinični trošak reworka; ako je null, engine koristi cijenu scrappa.
  final double? copqReworkUnitCostInBase;

  /// Procjena troška po zatvorenom NCR-u (bazna valuta).
  final double? copqClosedNcrEstimateInBase;

  /// Procjena intervencije po zatvorenom kvaru (`faults`, bazna valuta).
  final double? maintenanceCostPerClosedFaultInBase;

  /// Mjesečni budžet / trošak energije po pogonu (`plantKey` → iznos u baznoj valuti).
  final Map<String, double> plantEnergyCostBudgetMonthlyInBase;

  double? plantEnergyBudgetMonthlyFor(String plantKey) {
    final k = plantKey.trim();
    if (k.isEmpty) return null;
    return plantEnergyCostBudgetMonthlyInBase[k];
  }

  static FinanceControllingDefaultsView fromCompanyData(
    Map<String, dynamic>? companyData,
  ) {
    final raw = companyData?['financeControllingDefaults'];
    if (raw is! Map) {
      return const FinanceControllingDefaultsView(
        baseCurrency: 'EUR',
        displayCurrency: 'EUR',
      );
    }
    final m = Map<String, dynamic>.from(raw);
    var base =
        (m['baseCurrency'] ?? m['currency'] ?? 'EUR')
            .toString()
            .trim()
            .toUpperCase();
    if (base.isEmpty) base = 'EUR';
    var disp = (m['displayCurrency'] ?? base).toString().trim().toUpperCase();
    if (disp.isEmpty) disp = base;
    final mhrRaw = m['machineHourlyRate'] ?? m['machineHourlyRateEur'];
    double? mhr;
    if (mhrRaw is num) {
      final v = mhrRaw.toDouble();
      if (v.isFinite && v >= 0) mhr = v;
    }
    double? optCost(String k) {
      final r = m[k];
      if (r is num) {
        final v = r.toDouble();
        if (v.isFinite && v >= 0 && v <= 10000000) return v;
      }
      return null;
    }

    final plantEnergy = <String, double>{};
    final rawPe = m['plantEnergyCostBudgetMonthlyInBase'];
    if (rawPe is Map) {
      for (final e in rawPe.entries) {
        final key = e.key.toString().trim();
        if (key.isEmpty) continue;
        final rv = e.value;
        if (rv is num) {
          final v = rv.toDouble();
          if (v.isFinite && v > 0 && v <= 10000000) plantEnergy[key] = v;
        }
      }
    }

    return FinanceControllingDefaultsView(
      baseCurrency: base,
      displayCurrency: disp,
      machineHourlyRate: mhr,
      copqScrapUnitCostInBase: optCost('copqScrapUnitCostInBase'),
      copqReworkUnitCostInBase: optCost('copqReworkUnitCostInBase'),
      copqClosedNcrEstimateInBase: optCost('copqClosedNcrEstimateInBase'),
      maintenanceCostPerClosedFaultInBase:
          optCost('maintenanceCostPerClosedFaultInBase'),
      plantEnergyCostBudgetMonthlyInBase: plantEnergy,
    );
  }
}
