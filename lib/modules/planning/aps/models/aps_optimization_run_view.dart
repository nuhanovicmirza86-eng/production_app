import '../helpers/aps_callable_timestamp.dart';
import 'aps_optimization_comparison_view.dart';

/// Jedan prijedlog optimizacije (P5 run dokument iz Callable odgovora).
class ApsOptimizationRunView {
  const ApsOptimizationRunView({
    required this.id,
    required this.scenarioId,
    required this.status,
    this.solverType = '',
    this.baselineScheduleRunId = '',
    this.candidateScheduleRunId = '',
    this.objectiveProfileId = '',
    this.objectiveScore,
    this.baselineObjectiveScore,
    this.comparison,
    this.startedAt,
    this.completedAt,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String scenarioId;
  final String status;
  final String solverType;
  final String baselineScheduleRunId;
  final String candidateScheduleRunId;
  final String objectiveProfileId;
  final num? objectiveScore;
  final num? baselineObjectiveScore;
  final ApsOptimizationComparisonView? comparison;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorCode;
  final String? errorMessage;

  bool get isCompleted => status == 'completed';

  bool get isApplied => status == 'applied';

  bool get isDiscarded => status == 'discarded';

  bool get isFailed => status == 'failed' || status == 'infeasible';

  bool get canApply => isCompleted;

  bool get canDiscard => isCompleted;

  bool get hasComparison => comparison != null;

  String get statusLabel {
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return 'Prijedlog spreman';
      case 'applied':
        return 'Primijenjen';
      case 'discarded':
        return 'Odbačen';
      case 'failed':
        return 'Neuspjeh';
      case 'infeasible':
        return 'Nije izvedivo';
      case 'running':
        return 'U tijeku';
      case 'queued':
        return 'U redu';
      default:
        return status.trim().isEmpty ? '—' : status.trim();
    }
  }

  factory ApsOptimizationRunView.fromMap(Map<String, dynamic> map) {
    final comparisonRaw = map['comparisonResult'];
    return ApsOptimizationRunView(
      id: (map['id'] ?? '').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim(),
      solverType: (map['solverType'] ?? '').toString().trim(),
      baselineScheduleRunId:
          (map['baselineScheduleRunId'] ?? '').toString().trim(),
      candidateScheduleRunId:
          (map['candidateScheduleRunId'] ?? '').toString().trim(),
      objectiveProfileId:
          (map['objectiveProfileId'] ?? '').toString().trim(),
      objectiveScore: _optionalNum(map['objectiveScore']),
      baselineObjectiveScore: _optionalNum(map['baselineObjectiveScore']),
      comparison: comparisonRaw is Map
          ? ApsOptimizationComparisonView.fromMap(
              Map<String, dynamic>.from(comparisonRaw),
            )
          : null,
      startedAt: parseApsCallableTimestamp(map['startedAt']),
      completedAt: parseApsCallableTimestamp(map['completedAt']),
      errorCode: _optionalString(map['errorCode']),
      errorMessage: _optionalString(map['errorMessage']),
    );
  }

  static String? _optionalString(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static num? _optionalNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
