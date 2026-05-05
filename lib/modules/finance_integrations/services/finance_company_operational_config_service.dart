import 'package:cloud_functions/cloud_functions.dart';

/// Callable [updateCompanyOperationalConfig] — samo granula `financeControllingDefaults`.
class FinanceCompanyOperationalConfigService {
  FinanceCompanyOperationalConfigService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<void> updateFinanceControllingDefaults({
    required String companyId,
    required String baseCurrency,
    required String displayCurrency,
    required double machineHourlyRate,
    double? copqScrapUnitCostInBase,
    double? copqReworkUnitCostInBase,
    double? copqClosedNcrEstimateInBase,
    double? maintenanceCostPerClosedFaultInBase,
    Map<String, dynamic>? plantEnergyCostBudgetMonthlyInBasePatch,
  }) async {
    final fd = <String, dynamic>{
      'baseCurrency': baseCurrency.trim().toUpperCase(),
      'displayCurrency': displayCurrency.trim().toUpperCase(),
      'machineHourlyRate': machineHourlyRate,
    };
    if (copqScrapUnitCostInBase != null) {
      fd['copqScrapUnitCostInBase'] = copqScrapUnitCostInBase;
    }
    if (copqReworkUnitCostInBase != null) {
      fd['copqReworkUnitCostInBase'] = copqReworkUnitCostInBase;
    }
    if (copqClosedNcrEstimateInBase != null) {
      fd['copqClosedNcrEstimateInBase'] = copqClosedNcrEstimateInBase;
    }
    if (maintenanceCostPerClosedFaultInBase != null) {
      fd['maintenanceCostPerClosedFaultInBase'] =
          maintenanceCostPerClosedFaultInBase;
    }
    if (plantEnergyCostBudgetMonthlyInBasePatch != null &&
        plantEnergyCostBudgetMonthlyInBasePatch.isNotEmpty) {
      fd['plantEnergyCostBudgetMonthlyInBase'] =
          plantEnergyCostBudgetMonthlyInBasePatch;
    }
    final res = await _functions
        .httpsCallable('updateCompanyOperationalConfig')
        .call(<String, dynamic>{
      'companyId': companyId.trim(),
      'financeControllingDefaults': fd,
    });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Spremanje financijskih postavki nije uspjelo.');
    }
  }
}
