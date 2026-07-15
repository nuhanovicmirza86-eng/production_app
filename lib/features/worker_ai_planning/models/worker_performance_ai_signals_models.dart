class WorkerPerformanceAiEvidenceRef {
  const WorkerPerformanceAiEvidenceRef({
    this.source,
    this.metric,
    this.value,
    this.period,
    this.breakdownKey,
  });

  final String? source;
  final String? metric;
  final num? value;
  final Map<String, dynamic>? period;
  final String? breakdownKey;

  factory WorkerPerformanceAiEvidenceRef.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiEvidenceRef(
      source: _str(m['source']),
      metric: _str(m['metric']),
      value: _num(m['value']),
      period: m['period'] is Map
          ? Map<String, dynamic>.from(m['period'] as Map)
          : null,
      breakdownKey: _str(m['breakdownKey']),
    );
  }
}

class WorkerPerformanceAiRecommendation {
  const WorkerPerformanceAiRecommendation({
    this.type,
    this.summary,
    this.operatorDisplayName,
    this.operationType,
    this.confidence,
    this.evidenceRefs = const [],
  });

  final String? type;
  final String? summary;
  final String? operatorDisplayName;
  final String? operationType;
  final String? confidence;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiRecommendation.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiRecommendation(
      type: _str(m['type']),
      summary: _str(m['summary']),
      operatorDisplayName: _str(m['operatorDisplayName']),
      operationType: _str(m['operationType']),
      confidence: _str(m['confidence']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiWarning {
  const WorkerPerformanceAiWarning({
    this.severity,
    this.summary,
    this.evidenceRefs = const [],
  });

  final String? severity;
  final String? summary;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiWarning.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiWarning(
      severity: _str(m['severity']),
      summary: _str(m['summary']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiRisk {
  const WorkerPerformanceAiRisk({
    this.riskType,
    this.summary,
    this.evidenceRefs = const [],
  });

  final String? riskType;
  final String? summary;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiRisk.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiRisk(
      riskType: _str(m['riskType']),
      summary: _str(m['summary']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiWorkerSuitability {
  const WorkerPerformanceAiWorkerSuitability({
    this.operatorDisplayName,
    this.operationTypes = const [],
    this.fitLevel,
    this.summary,
    this.evidenceRefs = const [],
  });

  final String? operatorDisplayName;
  final List<String> operationTypes;
  final String? fitLevel;
  final String? summary;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiWorkerSuitability.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiWorkerSuitability(
      operatorDisplayName: _str(m['operatorDisplayName']),
      operationTypes: _strList(m['operationTypes']),
      fitLevel: _str(m['fitLevel']),
      summary: _str(m['summary']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiOperationFit {
  const WorkerPerformanceAiOperationFit({
    this.operatorDisplayName,
    this.operationType,
    this.fitLevel,
    this.summary,
    this.evidenceRefs = const [],
  });

  final String? operatorDisplayName;
  final String? operationType;
  final String? fitLevel;
  final String? summary;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiOperationFit.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiOperationFit(
      operatorDisplayName: _str(m['operatorDisplayName']),
      operationType: _str(m['operationType']),
      fitLevel: _str(m['fitLevel']),
      summary: _str(m['summary']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiTrainingSuggestion {
  const WorkerPerformanceAiTrainingSuggestion({
    this.summary,
    this.operatorDisplayName,
    this.operationTypes = const [],
    this.evidenceRefs = const [],
  });

  final String? summary;
  final String? operatorDisplayName;
  final List<String> operationTypes;
  final List<WorkerPerformanceAiEvidenceRef> evidenceRefs;

  factory WorkerPerformanceAiTrainingSuggestion.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiTrainingSuggestion(
      summary: _str(m['summary']),
      operatorDisplayName: _str(m['operatorDisplayName']),
      operationTypes: _strList(m['operationTypes']),
      evidenceRefs: _refs(m['evidenceRefs']),
    );
  }
}

class WorkerPerformanceAiSignalsResult {
  const WorkerPerformanceAiSignalsResult({
    required this.disclaimer,
    required this.normativeReady,
    required this.activitySourcesIncluded,
    required this.recommendations,
    required this.warnings,
    required this.risks,
    required this.workerSuitability,
    required this.operationFit,
    required this.trainingSuggestions,
    this.dataQualityNotes = const [],
    this.aiUsed = false,
    this.signalSource,
    this.sessionCountAnalyzed,
  });

  final String disclaimer;
  final bool normativeReady;
  final List<String> activitySourcesIncluded;
  final List<WorkerPerformanceAiRecommendation> recommendations;
  final List<WorkerPerformanceAiWarning> warnings;
  final List<WorkerPerformanceAiRisk> risks;
  final List<WorkerPerformanceAiWorkerSuitability> workerSuitability;
  final List<WorkerPerformanceAiOperationFit> operationFit;
  final List<WorkerPerformanceAiTrainingSuggestion> trainingSuggestions;
  final List<String> dataQualityNotes;
  final bool aiUsed;
  final String? signalSource;
  final int? sessionCountAnalyzed;

  factory WorkerPerformanceAiSignalsResult.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceAiSignalsResult(
      disclaimer: _str(m['disclaimer']) ?? '',
      normativeReady: m['normativeReady'] == true,
      activitySourcesIncluded: _strList(m['activitySourcesIncluded']),
      recommendations: _list(m['recommendations'], WorkerPerformanceAiRecommendation.fromMap),
      warnings: _list(m['warnings'], WorkerPerformanceAiWarning.fromMap),
      risks: _list(m['risks'], WorkerPerformanceAiRisk.fromMap),
      workerSuitability:
          _list(m['workerSuitability'], WorkerPerformanceAiWorkerSuitability.fromMap),
      operationFit: _list(m['operationFit'], WorkerPerformanceAiOperationFit.fromMap),
      trainingSuggestions:
          _list(m['trainingSuggestions'], WorkerPerformanceAiTrainingSuggestion.fromMap),
      dataQualityNotes: _strList(m['dataQualityNotes']),
      aiUsed: m['aiUsed'] == true,
      signalSource: _str(m['signalSource']),
      sessionCountAnalyzed: m['sessionCountAnalyzed'] is int
          ? m['sessionCountAnalyzed'] as int
          : int.tryParse('${m['sessionCountAnalyzed']}'),
    );
  }
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

num? _num(Object? v) {
  if (v is num) return v;
  return num.tryParse('${v ?? ''}'.replaceAll(',', '.'));
}

List<String> _strList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
}

List<WorkerPerformanceAiEvidenceRef> _refs(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => WorkerPerformanceAiEvidenceRef.fromMap(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<T> _list<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromMap,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromMap(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}
