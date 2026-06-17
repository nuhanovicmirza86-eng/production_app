import '../../shared/finance_callable_utils.dart';
import 'finance_cash_flow_scenario_assumptions.dart';
import 'finance_cash_flow_scenario_result.dart';

/// Cash Flow scenarij (P5-M1) — iz Callable read/write odgovora.
class FinanceCashFlowScenario {
  const FinanceCashFlowScenario({
    required this.scenarioId,
    required this.companyId,
    this.plantKey,
    required this.name,
    this.description,
    required this.scenarioType,
    required this.status,
    this.periodFrom,
    this.periodTo,
    required this.revision,
    this.calculationVersion,
    required this.assumptions,
    required this.baseForecastSnapshot,
    this.calculatedSnapshot,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.updatedByEmail,
  });

  final String scenarioId;
  final String companyId;
  final String? plantKey;
  final String name;
  final String? description;
  final String scenarioType;
  final String status;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int revision;
  final String? calculationVersion;
  final FinanceCashFlowScenarioAssumptions assumptions;
  final FinanceCashFlowScenarioSnapshot baseForecastSnapshot;
  final FinanceCashFlowScenarioSnapshot? calculatedSnapshot;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? updatedByEmail;

  bool get isDraft => status == 'draft';
  bool get isCalculated => status == 'calculated';
  bool get isApproved => status == 'approved';
  bool get isArchived => status == 'archived';

  bool get isWhatIf => scenarioType == 'what_if';

  FinanceCashFlowScenarioSnapshot? get effectiveResult =>
      calculatedSnapshot ?? (isCalculated ? calculatedSnapshot : null);

  FinanceCashFlowScenarioSnapshot get displaySnapshot {
    if (calculatedSnapshot != null) return calculatedSnapshot!;
    return baseForecastSnapshot;
  }

  factory FinanceCashFlowScenario.fromCallableMap(Map<String, dynamic> raw) {
    final item = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(item, [
      'periodFrom',
      'periodTo',
      'createdAt',
      'updatedAt',
    ]);
    final assumptionsRaw = item['assumptions'];
    final baseRaw = item['baseForecastSnapshot'];
    final calcRaw = item['calculatedSnapshot'];
    return FinanceCashFlowScenario(
      scenarioId: (item['scenarioId'] ?? '').toString(),
      companyId: (item['companyId'] ?? '').toString(),
      plantKey: item['plantKey']?.toString(),
      name: (item['name'] ?? '').toString(),
      description: item['description']?.toString(),
      scenarioType: (item['scenarioType'] ?? '').toString(),
      status: (item['status'] ?? '').toString(),
      periodFrom: item['periodFrom'] as DateTime?,
      periodTo: item['periodTo'] as DateTime?,
      revision: item['revision'] is num
          ? (item['revision'] as num).toInt()
          : int.tryParse(item['revision']?.toString() ?? '') ?? 1,
      calculationVersion: item['calculationVersion']?.toString(),
      assumptions: FinanceCashFlowScenarioAssumptions.fromCallableMap(
        assumptionsRaw is Map
            ? Map<String, dynamic>.from(assumptionsRaw)
            : null,
      ),
      baseForecastSnapshot: FinanceCashFlowScenarioSnapshot.fromCallableMap(
        baseRaw is Map ? Map<String, dynamic>.from(baseRaw) : null,
      ),
      calculatedSnapshot: calcRaw is Map
          ? FinanceCashFlowScenarioSnapshot.fromCallableMap(
              Map<String, dynamic>.from(calcRaw),
            )
          : null,
      createdBy: item['createdBy']?.toString(),
      createdAt: item['createdAt'] as DateTime?,
      updatedBy: item['updatedBy']?.toString(),
      updatedAt: item['updatedAt'] as DateTime?,
      updatedByEmail: item['updatedByEmail']?.toString(),
    );
  }
}
