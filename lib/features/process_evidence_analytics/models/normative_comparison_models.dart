import 'process_evidence_analytics_models.dart';

class MatchedNormativeSummary {
  const MatchedNormativeSummary({
    this.normId,
    this.normGroupId,
    this.version,
    this.displayName,
  });

  final String? normId;
  final String? normGroupId;
  final int? version;
  final String? displayName;

  factory MatchedNormativeSummary.fromMap(Map<String, dynamic> m) {
    return MatchedNormativeSummary(
      normId: _normStr(m['normId']),
      normGroupId: _normStr(m['normGroupId']),
      version: m['version'] is int
          ? m['version'] as int
          : int.tryParse('${m['version']}'),
      displayName: _normStr(m['displayName']),
    );
  }
}

class NormativeComparisonData {
  const NormativeComparisonData({
    required this.normativeReady,
    required this.normativeStatus,
    this.matchedNorm,
    this.normGroupId,
    this.normVersion,
    this.targetPiecesPerHour,
    this.standardMinutesPerPiece,
    this.allowedScrapRate,
    this.difficulty,
    this.actualPiecesPerHour,
    this.actualMinutesPerPiece,
    this.actualScrapRate,
    this.speedVariancePercent,
    this.scrapVariancePercent,
    this.withinSpeedTolerance,
    this.withinScrapTolerance,
  });

  final bool normativeReady;
  final String normativeStatus;
  final MatchedNormativeSummary? matchedNorm;
  final String? normGroupId;
  final int? normVersion;
  final num? targetPiecesPerHour;
  final num? standardMinutesPerPiece;
  final num? allowedScrapRate;
  final String? difficulty;
  final num? actualPiecesPerHour;
  final num? actualMinutesPerPiece;
  final num? actualScrapRate;
  final num? speedVariancePercent;
  final num? scrapVariancePercent;
  final bool? withinSpeedTolerance;
  final bool? withinScrapTolerance;

  factory NormativeComparisonData.fromMap(Map<String, dynamic> m) {
    MatchedNormativeSummary? matched;
    final rawMatched = m['matchedNorm'];
    if (rawMatched is Map) {
      matched = MatchedNormativeSummary.fromMap(
        Map<String, dynamic>.from(rawMatched),
      );
    }

    return NormativeComparisonData(
      normativeReady: m['normativeReady'] == true,
      normativeStatus: _normStr(m['normativeStatus']) ?? 'no_norm',
      matchedNorm: matched,
      normGroupId: _normStr(m['normGroupId']) ?? matched?.normGroupId,
      normVersion: m['normVersion'] is int
          ? m['normVersion'] as int
          : int.tryParse('${m['normVersion'] ?? matched?.version ?? ''}'),
      targetPiecesPerHour: _normNum(m['targetPiecesPerHour']),
      standardMinutesPerPiece: _normNum(m['standardMinutesPerPiece']),
      allowedScrapRate: _normNum(m['allowedScrapRate']),
      difficulty: _normStr(m['difficulty'] ?? m['operationDifficulty']),
      actualPiecesPerHour: _normNum(m['actualPiecesPerHour']),
      actualMinutesPerPiece: _normNum(m['actualMinutesPerPiece']),
      actualScrapRate: _normNum(m['actualScrapRate']),
      speedVariancePercent: _normNum(m['speedVariancePercent']),
      scrapVariancePercent: _normNum(m['scrapVariancePercent']),
      withinSpeedTolerance: m['withinSpeedTolerance'] is bool
          ? m['withinSpeedTolerance'] as bool
          : null,
      withinScrapTolerance: m['withinScrapTolerance'] is bool
          ? m['withinScrapTolerance'] as bool
          : null,
    );
  }

  static const empty = NormativeComparisonData(
    normativeReady: false,
    normativeStatus: 'no_norm',
  );

  String get headlineMessage => normativeReady
      ? 'Poređenje s normativom aktivno'
      : 'Normativ nije pronađen';

  String get statusLabel => normativeStatusLabel(normativeStatus);

  String get matchedNormLabel {
    if (!normativeReady) return '—';
    final name = (matchedNorm?.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    if (normVersion != null) return 'Normativ v$normVersion';
    return 'Aktivni normativ';
  }
}

String normativeStatusLabel(String status) {
  switch (status.trim()) {
    case 'within_norm':
      return 'U normativu';
    case 'below_speed_norm':
      return 'Ispod norme brzine';
    case 'above_scrap_norm':
      return 'Iznad dozvoljenog škarta';
    case 'mixed_warning':
      return 'Kombinovano upozorenje';
    case 'no_norm':
      return 'Nema normativa';
    default:
      return status;
  }
}

String normativeDifficultyLabel(String? difficulty) {
  switch ((difficulty ?? '').trim()) {
    case 'low':
      return 'Niska';
    case 'medium':
      return 'Srednja';
    case 'high':
      return 'Visoka';
    case 'very_high':
      return 'Vrlo visoka';
    default:
      return (difficulty ?? '').trim().isEmpty ? '—' : difficulty!.trim();
  }
}

String formatToleranceLabel(bool? value) {
  if (value == null) return '—';
  return value ? 'Da' : 'Ne';
}

String formatVariancePercent(num? value) {
  if (value == null) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${formatAnalyticsNumber(value)} %';
}

String formatVariancePoints(num? value) {
  if (value == null) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${formatAnalyticsNumber(value, fractionDigits: 2)} pp';
}

String? _normStr(dynamic v) {
  final t = (v ?? '').toString().trim();
  return t.isEmpty ? null : t;
}

num? _normNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString().replaceAll(',', '.'));
}
