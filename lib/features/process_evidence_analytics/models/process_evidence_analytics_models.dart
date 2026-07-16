import 'normative_comparison_models.dart';

class ProcessEvidenceAnalyticsFilters {
  const ProcessEvidenceAnalyticsFilters({
    required this.dateFrom,
    required this.dateTo,
    this.plantKey,
    this.processProfileType,
    this.stationConfigId,
    this.operatorId,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final String? plantKey;
  final String? processProfileType;
  final String? stationConfigId;
  final String? operatorId;

  String formatApiDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toCallablePayload(String companyId) {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'dateFrom': formatApiDate(dateFrom),
      'dateTo': formatApiDate(dateTo),
    };
    void put(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) payload[key] = v;
    }

    put('plantKey', plantKey);
    put('processProfileType', processProfileType);
    put('stationConfigId', stationConfigId);
    put('operatorId', operatorId);
    return payload;
  }
}

class ProcessEvidenceMaterialConsumptionRow {
  const ProcessEvidenceMaterialConsumptionRow({
    this.materialType,
    this.materialName,
    this.quantity,
    this.unit,
  });

  final String? materialType;
  final String? materialName;
  final num? quantity;
  final String? unit;

  factory ProcessEvidenceMaterialConsumptionRow.fromMap(Map<String, dynamic> m) {
    return ProcessEvidenceMaterialConsumptionRow(
      materialType: _str(m['materialType']),
      materialName: _str(m['materialName']),
      quantity: _num(m['quantity']),
      unit: _str(m['unit']),
    );
  }
}

class ProcessEvidenceAnalyticsSummary {
  const ProcessEvidenceAnalyticsSummary({
    required this.evidenceCount,
    required this.processedTotalQty,
    required this.okTotalQty,
    required this.scrapTotalQty,
    required this.reworkAgainTotalQty,
    required this.durationMinutesTotal,
    required this.averagePiecesPerHour,
    required this.materialConsumption,
    required this.activitySourcesIncluded,
    required this.normativeComparison,
    this.scrapRatePercent,
    this.reworkRatePercent,
    this.truncated = false,
    this.sessionCountAnalyzed,
  });

  final int evidenceCount;
  final num? processedTotalQty;
  final num? okTotalQty;
  final num? scrapTotalQty;
  final num? reworkAgainTotalQty;
  final num? durationMinutesTotal;
  final num? averagePiecesPerHour;
  final List<ProcessEvidenceMaterialConsumptionRow> materialConsumption;
  final List<String> activitySourcesIncluded;
  final NormativeComparisonData normativeComparison;
  final num? scrapRatePercent;
  final num? reworkRatePercent;
  final bool truncated;
  final int? sessionCountAnalyzed;

  bool get normativeReady => normativeComparison.normativeReady;

  factory ProcessEvidenceAnalyticsSummary.fromMap(Map<String, dynamic> m) {
    final rawMaterials = m['materialConsumption'];
    final materials = <ProcessEvidenceMaterialConsumptionRow>[];
    if (rawMaterials is List) {
      for (final item in rawMaterials) {
        if (item is Map) {
          materials.add(
            ProcessEvidenceMaterialConsumptionRow.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final rawSources = m['activitySourcesIncluded'];
    final sources = <String>[];
    if (rawSources is List) {
      for (final s in rawSources) {
        final t = (s ?? '').toString().trim();
        if (t.isNotEmpty) sources.add(t);
      }
    }

    return ProcessEvidenceAnalyticsSummary(
      evidenceCount: _int(m['evidenceCount']),
      processedTotalQty: _num(m['processedTotalQty']),
      okTotalQty: _num(m['okTotalQty']),
      scrapTotalQty: _num(m['scrapTotalQty']),
      reworkAgainTotalQty: _num(m['reworkAgainTotalQty']),
      durationMinutesTotal: _num(m['durationMinutesTotal']),
      averagePiecesPerHour: _num(m['averagePiecesPerHour']),
      materialConsumption: materials,
      activitySourcesIncluded: sources,
      normativeComparison: NormativeComparisonData.fromMap(m),
      scrapRatePercent: _num(m['scrapRatePercent']),
      reworkRatePercent: _num(m['reworkRatePercent']),
      truncated: m['truncated'] == true,
      sessionCountAnalyzed: _intOrNull(m['sessionCountAnalyzed']),
    );
  }
}

class ProcessEvidenceBreakdownRow {
  const ProcessEvidenceBreakdownRow({
    required this.key,
    required this.label,
    this.evidenceCount,
    this.processedTotalQty,
    this.okTotalQty,
    this.scrapTotalQty,
    this.reworkAgainTotalQty,
    this.durationMinutesTotal,
    this.averagePiecesPerHour,
    this.scrapRatePercent,
  });

  final String key;
  final String label;
  final int? evidenceCount;
  final num? processedTotalQty;
  final num? okTotalQty;
  final num? scrapTotalQty;
  final num? reworkAgainTotalQty;
  final num? durationMinutesTotal;
  final num? averagePiecesPerHour;
  final num? scrapRatePercent;

  factory ProcessEvidenceBreakdownRow.fromMap(Map<String, dynamic> m) {
    return ProcessEvidenceBreakdownRow(
      key: _str(m['key']) ?? '—',
      label: _str(m['label']) ?? _str(m['key']) ?? '—',
      evidenceCount: _intOrNull(m['evidenceCount']),
      processedTotalQty: _num(m['processedTotalQty']),
      okTotalQty: _num(m['okTotalQty']),
      scrapTotalQty: _num(m['scrapTotalQty']),
      reworkAgainTotalQty: _num(m['reworkAgainTotalQty']),
      durationMinutesTotal: _num(m['durationMinutesTotal']),
      averagePiecesPerHour: _num(m['averagePiecesPerHour']),
      scrapRatePercent: _num(m['scrapRatePercent']),
    );
  }
}

class WorkerPerformanceKpiRow {
  const WorkerPerformanceKpiRow({
    required this.operatorId,
    required this.operatorDisplayName,
    required this.normativeComparison,
    this.processedQty,
    this.okQty,
    this.scrapQty,
    this.reworkAgainQty,
    this.durationMinutes,
    this.piecesPerHour,
    this.scrapRate,
    this.reworkRate,
    this.bestOperationTypes = const [],
    this.riskOperationTypes = const [],
    this.activitySource,
  });

  final String operatorId;
  final String operatorDisplayName;
  final NormativeComparisonData normativeComparison;
  final num? processedQty;
  final num? okQty;
  final num? scrapQty;
  final num? reworkAgainQty;
  final num? durationMinutes;
  final num? piecesPerHour;
  final num? scrapRate;
  final num? reworkRate;
  final List<String> bestOperationTypes;
  final List<String> riskOperationTypes;
  final String? activitySource;

  bool get normativeReady => normativeComparison.normativeReady;

  factory WorkerPerformanceKpiRow.fromMap(Map<String, dynamic> m) {
    return WorkerPerformanceKpiRow(
      operatorId: _str(m['operatorId']) ?? '—',
      operatorDisplayName: _str(m['operatorDisplayName']) ?? '—',
      normativeComparison: NormativeComparisonData.fromMap(m),
      processedQty: _num(m['processedQty']),
      okQty: _num(m['okQty']),
      scrapQty: _num(m['scrapQty']),
      reworkAgainQty: _num(m['reworkAgainQty']),
      durationMinutes: _num(m['durationMinutes']),
      piecesPerHour: _num(m['piecesPerHour']),
      scrapRate: _num(m['scrapRate']),
      reworkRate: _num(m['reworkRate']),
      bestOperationTypes: _strList(m['bestOperationTypes']),
      riskOperationTypes: _strList(m['riskOperationTypes']),
      activitySource: _str(m['activitySource']),
    );
  }
}

class ProcessEvidenceAnalyticsLoadResult {
  const ProcessEvidenceAnalyticsLoadResult({
    required this.summary,
    required this.breakdowns,
    required this.operators,
    this.summaryTruncated = false,
  });

  final ProcessEvidenceAnalyticsSummary summary;
  final Map<String, List<ProcessEvidenceBreakdownRow>> breakdowns;
  final List<WorkerPerformanceKpiRow> operators;
  final bool summaryTruncated;
}

String? _str(dynamic v) {
  final t = (v ?? '').toString().trim();
  return t.isEmpty ? null : t;
}

num? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  final n = num.tryParse(v.toString().replaceAll(',', '.'));
  return n;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

int? _intOrNull(dynamic v) {
  if (v == null) return null;
  return _int(v);
}

List<String> _strList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => (e ?? '').toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

String formatProcessEvidenceProfileLabel(String? profileKey) {
  switch ((profileKey ?? '').trim()) {
    case 'chemical_dosing':
      return 'Doziranje hemikalija';
    case 'wastewater_treatment':
      return 'Obrada otpadnih voda';
    case 'rework_and_painting':
      return 'Dorada i površinska obrada';
    default:
      final t = (profileKey ?? '').trim();
      return t.isEmpty ? '—' : t;
  }
}

String formatActivitySourceLabel(String source) {
  switch (source.trim()) {
    case 'profile_driven_evidence':
      return 'Evidencije procesa';
    default:
      return source;
  }
}

String formatAnalyticsNumber(num? value, {int fractionDigits = 1}) {
  if (value == null) return '—';
  if (value is int || value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(fractionDigits);
}

String formatAnalyticsPercent(num? value) {
  if (value == null) return '—';
  return '${value.toStringAsFixed(1)} %';
}

String formatDurationMinutes(num? minutes) {
  if (minutes == null) return '—';
  final n = minutes is int ? minutes : minutes.round();
  return '$n min';
}
