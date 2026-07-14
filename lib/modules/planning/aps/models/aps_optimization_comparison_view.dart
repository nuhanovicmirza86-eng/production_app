/// Usporedba početnog rasporeda i prijedloga optimizacije (P5 Callable odgovor).
class ApsOptimizationComparisonView {
  const ApsOptimizationComparisonView({
    required this.baselineScheduleRunId,
    required this.candidateScheduleRunId,
    required this.isImprovement,
    required this.baselineObjectiveScore,
    required this.candidateObjectiveScore,
    this.deltaMetrics = const {},
  });

  final String baselineScheduleRunId;
  final String candidateScheduleRunId;
  final bool isImprovement;
  final num baselineObjectiveScore;
  final num candidateObjectiveScore;
  final Map<String, dynamic> deltaMetrics;

  num? get deltaObjectiveScore =>
      _numOrNull(deltaMetrics['objectiveScore']);

  int? get deltaMakespanMinutes =>
      _intOrNull(deltaMetrics['makespanMinutes']);

  int? get operationsMovedCount =>
      _intOrNull(deltaMetrics['operationsMovedCount']);

  int? get hardViolationCount =>
      _intOrNull(deltaMetrics['hardViolationCount']);

  factory ApsOptimizationComparisonView.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    final delta = m['deltaMetrics'];
    return ApsOptimizationComparisonView(
      baselineScheduleRunId:
          (m['baselineScheduleRunId'] ?? '').toString().trim(),
      candidateScheduleRunId:
          (m['candidateScheduleRunId'] ?? '').toString().trim(),
      isImprovement: m['isImprovement'] == true,
      baselineObjectiveScore: _numOrZero(m['baselineObjectiveScore']),
      candidateObjectiveScore: _numOrZero(m['candidateObjectiveScore']),
      deltaMetrics: delta is Map
          ? Map<String, dynamic>.from(delta)
          : const {},
    );
  }

  static num _numOrZero(dynamic v) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? 0;
  }

  static num? _numOrNull(dynamic v) {
    if (v is num) return v;
    return num.tryParse('${v ?? ''}');
  }

  static int? _intOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}');
  }
}
