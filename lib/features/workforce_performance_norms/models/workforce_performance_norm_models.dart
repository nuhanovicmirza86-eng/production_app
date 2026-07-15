class WorkforcePerformanceNorm {
  const WorkforcePerformanceNorm({
    required this.normId,
    required this.normGroupId,
    required this.version,
    required this.status,
    this.displayName,
    this.notes,
    this.plantKey,
    this.processProfileType,
    this.stationConfigId,
    this.operationType,
    this.productId,
    this.productCode,
    this.pieceType,
    this.targetPiecesPerHour,
    this.standardMinutesPerPiece,
    this.allowedScrapRatePercent,
    this.targetOkRatePercent,
    this.operationDifficulty,
    this.difficultyWeight,
    this.validFrom,
    this.validTo,
    this.changeReason,
  });

  final String normId;
  final String normGroupId;
  final int version;
  final String status;
  final String? displayName;
  final String? notes;
  final String? plantKey;
  final String? processProfileType;
  final String? stationConfigId;
  final String? operationType;
  final String? productId;
  final String? productCode;
  final String? pieceType;
  final num? targetPiecesPerHour;
  final num? standardMinutesPerPiece;
  final num? allowedScrapRatePercent;
  final num? targetOkRatePercent;
  final String? operationDifficulty;
  final num? difficultyWeight;
  final String? validFrom;
  final String? validTo;
  final String? changeReason;

  bool get isDraft => status == 'draft';
  bool get isActive => status == 'active';
  bool get canEdit => isDraft;

  factory WorkforcePerformanceNorm.fromMap(Map<String, dynamic> m) {
    return WorkforcePerformanceNorm(
      normId: _str(m['normId']) ?? '',
      normGroupId: _str(m['normGroupId']) ?? '',
      version: m['version'] is int
          ? m['version'] as int
          : int.tryParse('${m['version']}') ?? 0,
      status: _str(m['status']) ?? 'draft',
      displayName: _str(m['displayName']),
      notes: _str(m['notes']),
      plantKey: _str(m['plantKey']),
      processProfileType: _str(m['processProfileType']),
      stationConfigId: _str(m['stationConfigId']),
      operationType: _str(m['operationType']),
      productId: _str(m['productId']),
      productCode: _str(m['productCode']),
      pieceType: _str(m['pieceType']),
      targetPiecesPerHour: _num(m['targetPiecesPerHour']),
      standardMinutesPerPiece: _num(m['standardMinutesPerPiece']),
      allowedScrapRatePercent: _num(m['allowedScrapRatePercent']),
      targetOkRatePercent: _num(m['targetOkRatePercent']),
      operationDifficulty: _str(m['operationDifficulty']),
      difficultyWeight: _num(m['difficultyWeight']),
      validFrom: _str(m['validFrom']),
      validTo: _str(m['validTo']),
      changeReason: _str(m['changeReason']),
    );
  }

  Map<String, dynamic> toDraftPayload() {
    final payload = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      payload[key] = value;
    }

    put('displayName', displayName);
    put('notes', notes);
    put('plantKey', plantKey);
    put('processProfileType', processProfileType);
    put('stationConfigId', stationConfigId);
    put('operationType', operationType);
    put('productId', productId);
    put('productCode', productCode);
    put('pieceType', pieceType);
    if (targetPiecesPerHour != null) {
      put('targetPiecesPerHour', targetPiecesPerHour);
    }
    if (standardMinutesPerPiece != null) {
      put('standardMinutesPerPiece', standardMinutesPerPiece);
    }
    if (allowedScrapRatePercent != null) {
      put('allowedScrapRatePercent', allowedScrapRatePercent);
    }
    if (targetOkRatePercent != null) {
      put('targetOkRatePercent', targetOkRatePercent);
    }
    put('operationDifficulty', operationDifficulty);
    if (difficultyWeight != null) put('difficultyWeight', difficultyWeight);
    put('validFrom', validFrom);
    put('validTo', validTo);
    put('changeReason', changeReason);
    return payload;
  }
}

class WorkforcePerformanceNormMatchResult {
  const WorkforcePerformanceNormMatchResult({
    required this.normativeReady,
    this.matchedNorm,
    this.matchLevel,
  });

  final bool normativeReady;
  final MatchedWorkforcePerformanceNorm? matchedNorm;
  final int? matchLevel;

  factory WorkforcePerformanceNormMatchResult.fromMap(Map<String, dynamic> m) {
    MatchedWorkforcePerformanceNorm? matched;
    final raw = m['matchedNorm'];
    if (raw is Map) {
      matched = MatchedWorkforcePerformanceNorm.fromMap(
        Map<String, dynamic>.from(raw),
      );
    }
    return WorkforcePerformanceNormMatchResult(
      normativeReady: m['normativeReady'] == true,
      matchedNorm: matched,
      matchLevel: m['matchLevel'] is int
          ? m['matchLevel'] as int
          : int.tryParse('${m['matchLevel']}'),
    );
  }
}

class MatchedWorkforcePerformanceNorm {
  const MatchedWorkforcePerformanceNorm({
    this.normId,
    this.normGroupId,
    this.version,
    this.displayName,
    this.plantKey,
    this.processProfileType,
    this.operationType,
    this.targetPiecesPerHour,
    this.allowedScrapRatePercent,
    this.operationDifficulty,
    this.matchLevel,
  });

  final String? normId;
  final String? normGroupId;
  final int? version;
  final String? displayName;
  final String? plantKey;
  final String? processProfileType;
  final String? operationType;
  final num? targetPiecesPerHour;
  final num? allowedScrapRatePercent;
  final String? operationDifficulty;
  final int? matchLevel;

  factory MatchedWorkforcePerformanceNorm.fromMap(Map<String, dynamic> m) {
    return MatchedWorkforcePerformanceNorm(
      normId: _str(m['normId']),
      normGroupId: _str(m['normGroupId']),
      version: m['version'] is int
          ? m['version'] as int
          : int.tryParse('${m['version']}'),
      displayName: _str(m['displayName']),
      plantKey: _str(m['plantKey']),
      processProfileType: _str(m['processProfileType']),
      operationType: _str(m['operationType']),
      targetPiecesPerHour: _num(m['targetPiecesPerHour']),
      allowedScrapRatePercent: _num(m['allowedScrapRatePercent']),
      operationDifficulty: _str(m['operationDifficulty']),
      matchLevel: m['matchLevel'] is int
          ? m['matchLevel'] as int
          : int.tryParse('${m['matchLevel']}'),
    );
  }
}

class WorkforcePerformanceNormMutationResult {
  const WorkforcePerformanceNormMutationResult({
    required this.norm,
    this.auditLogId,
  });

  final WorkforcePerformanceNorm norm;
  final String? auditLogId;
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

const workforceNormStatuses = <String>[
  'draft',
  'active',
  'superseded',
  'archived',
];

const workforceNormDifficulties = <String, String>{
  'low': 'Niska',
  'medium': 'Srednja',
  'high': 'Visoka',
  'very_high': 'Vrlo visoka',
};

const workforceNormProfileLabels = <String, String>{
  'chemical_dosing': 'Doziranje hemikalija',
  'wastewater_treatment': 'Obrada otpadnih voda',
  'rework_and_painting': 'Dorada i površinska obrada',
};

String workforceNormStatusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'Nacrt';
    case 'active':
      return 'Aktivan';
    case 'superseded':
      return 'Zamijenjen';
    case 'archived':
      return 'Arhiviran';
    default:
      return status;
  }
}
