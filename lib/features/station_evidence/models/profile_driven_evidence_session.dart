class ProfileDrivenEvidenceSummaryFields {
  const ProfileDrivenEvidenceSummaryFields({
    this.workBathName,
    this.chemicalName,
    this.quantity,
    this.unit,
    this.processAreaName,
    this.reactorNumber,
    this.treatmentPointName,
    this.heavyMetalsPresent,
    this.phValue,
    this.limeQuantity,
    this.sodiumMetabisulfiteQuantity,
    this.sodiumHydroxideQuantity,
    this.temperatureC,
    this.concentrationSnapshot,
    this.chemicalLot,
    this.dosingReason,
    this.operationType,
    this.workAreaNameSnapshot,
    this.resultStatus,
    this.durationMinutes,
    this.processedTotalQty,
    this.okTotalQty,
    this.scrapTotalQty,
    this.reworkAgainTotalQty,
    this.materialSummary,
    this.operatorSummary,
  });

  final String? workBathName;
  final String? chemicalName;
  final double? quantity;
  final String? unit;
  final String? processAreaName;
  final String? reactorNumber;
  final String? treatmentPointName;
  final String? heavyMetalsPresent;
  final double? phValue;
  final double? limeQuantity;
  final double? sodiumMetabisulfiteQuantity;
  final double? sodiumHydroxideQuantity;
  final double? temperatureC;
  final String? concentrationSnapshot;
  final String? chemicalLot;
  final String? dosingReason;
  final String? operationType;
  final String? workAreaNameSnapshot;
  final String? resultStatus;
  final double? durationMinutes;
  final double? processedTotalQty;
  final double? okTotalQty;
  final double? scrapTotalQty;
  final double? reworkAgainTotalQty;
  final String? materialSummary;
  final String? operatorSummary;

  factory ProfileDrivenEvidenceSummaryFields.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    double? n(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    return ProfileDrivenEvidenceSummaryFields(
      workBathName: _s(m['workBathName']),
      chemicalName: _s(m['chemicalName']),
      quantity: n(m['quantity']),
      unit: _s(m['unit']),
      processAreaName: _s(m['processAreaName']),
      reactorNumber: _s(m['reactorNumber']),
      treatmentPointName: _s(m['treatmentPointName']),
      heavyMetalsPresent: _s(m['heavyMetalsPresent']),
      phValue: n(m['phValue']),
      limeQuantity: n(m['limeQuantity']),
      sodiumMetabisulfiteQuantity: n(m['sodiumMetabisulfiteQuantity']),
      sodiumHydroxideQuantity: n(m['sodiumHydroxideQuantity']),
      temperatureC: n(m['temperatureC']),
      concentrationSnapshot: _s(m['concentrationSnapshot']),
      chemicalLot: _s(m['chemicalLot']),
      dosingReason: _s(m['dosingReason']),
      operationType: _s(m['operationType']),
      workAreaNameSnapshot: _s(m['workAreaNameSnapshot']),
      resultStatus: _s(m['resultStatus']),
      durationMinutes: n(m['durationMinutes']),
      processedTotalQty: n(m['processedTotalQty']),
      okTotalQty: n(m['okTotalQty']),
      scrapTotalQty: n(m['scrapTotalQty']),
      reworkAgainTotalQty: n(m['reworkAgainTotalQty']),
      materialSummary: _s(m['materialSummary']),
      operatorSummary: _s(m['operatorSummary']),
    );
  }

  static String? _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }
}

class ProfileDrivenEvidenceListItem {
  const ProfileDrivenEvidenceListItem({
    required this.sessionId,
    this.endedAt,
    this.startedAt,
    required this.processProfileType,
    required this.profileDisplayName,
    required this.stationConfigId,
    this.stationSlot,
    this.stationDisplayName,
    required this.plantKey,
    this.operatorId,
    this.operatorDisplayName,
    this.operatorEmail,
    required this.status,
    required this.summaryFields,
  });

  final String sessionId;
  final DateTime? endedAt;
  final DateTime? startedAt;
  final String processProfileType;
  final String profileDisplayName;
  final String stationConfigId;
  final int? stationSlot;
  final String? stationDisplayName;
  final String plantKey;
  final String? operatorId;
  final String? operatorDisplayName;
  final String? operatorEmail;
  final String status;
  final ProfileDrivenEvidenceSummaryFields summaryFields;

  String get summaryLine {
    final s = summaryFields;
    if (processProfileType == 'chemical_dosing') {
      final parts = <String>[
        if (s.workBathName != null) 'Kada: ${s.workBathName}',
        if (s.chemicalName != null) 'Hemikalija: ${s.chemicalName}',
        if (s.quantity != null) 'Količina: ${s.quantity}${s.unit != null ? ' ${s.unit}' : ''}',
        if (s.processAreaName != null) 'Područje: ${s.processAreaName}',
      ];
      return parts.join(' · ');
    }
    if (processProfileType == 'wastewater_treatment') {
      final parts = <String>[
        if (s.reactorNumber != null) 'Reaktor: ${s.reactorNumber}',
        if (s.treatmentPointName != null) 'Tačka: ${s.treatmentPointName}',
        if (s.quantity != null) 'Količina: ${s.quantity}${s.unit != null ? ' ${s.unit}' : ''}',
        if (s.heavyMetalsPresent != null) 'Teški metali: ${s.heavyMetalsPresent}',
        if (s.phValue != null) 'pH: ${s.phValue}',
      ];
      return parts.join(' · ');
    }
    if (processProfileType == 'rework_and_painting') {
      final station = (stationDisplayName ?? '').trim();
      final parts = <String>[
        if (s.operationType != null) 'Tip: ${s.operationType}',
        if (station.isNotEmpty) 'Stanica: $station',
        if (s.processedTotalQty != null) 'Obrađeno: ${formatFieldValue(s.processedTotalQty)}',
        if (s.resultStatus != null) 'Rezultat: ${s.resultStatus}',
      ];
      return parts.join(' · ');
    }
    return '';
  }

  factory ProfileDrivenEvidenceListItem.fromMap(Map<String, dynamic> m) {
    return ProfileDrivenEvidenceListItem(
      sessionId: (m['sessionId'] ?? '').toString().trim(),
      endedAt: _ts(m['endedAt']),
      startedAt: _ts(m['startedAt']),
      processProfileType: (m['processProfileType'] ?? '').toString().trim(),
      profileDisplayName: (m['profileDisplayName'] ?? '').toString().trim(),
      stationConfigId: (m['stationConfigId'] ?? '').toString().trim(),
      stationSlot: (m['stationSlot'] as num?)?.toInt(),
      stationDisplayName: _opt(m['stationDisplayName']),
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      operatorId: _opt(m['operatorId']),
      operatorDisplayName: _opt(m['operatorDisplayName']),
      operatorEmail: _opt(m['operatorEmail']),
      status: (m['status'] ?? '').toString().trim(),
      summaryFields: ProfileDrivenEvidenceSummaryFields.fromMap(
        m['summaryFields'] is Map
            ? Map<String, dynamic>.from(m['summaryFields'] as Map)
            : null,
      ),
    );
  }
}

class ProfileDrivenEvidenceSessionDetail {
  const ProfileDrivenEvidenceSessionDetail({
    required this.sessionId,
    required this.companyId,
    required this.stationConfigId,
    this.stationSlot,
    required this.plantKey,
    required this.processProfileType,
    required this.status,
    this.stationDisplayName,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.operatorId,
    this.operatorEmail,
    this.operatorDisplayName,
    this.createdByUid,
    this.createdByEmail,
    this.createdByDisplayName,
    this.profileSnapshot,
    required this.fieldValues,
    required this.summaryFields,
    this.controlledInputWarning,
    this.processedItems = const [],
    this.materialConsumptions = const [],
    this.operatorWorkLogs = const [],
    this.scrapItems = const [],
  });

  final String sessionId;
  final String companyId;
  final String stationConfigId;
  final int? stationSlot;
  final String plantKey;
  final String processProfileType;
  final String status;
  final String? stationDisplayName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final String? operatorId;
  final String? operatorEmail;
  final String? operatorDisplayName;
  final String? createdByUid;
  final String? createdByEmail;
  final String? createdByDisplayName;
  final Map<String, dynamic>? profileSnapshot;
  final Map<String, dynamic> fieldValues;
  final ProfileDrivenEvidenceSummaryFields summaryFields;
  final Map<String, dynamic>? controlledInputWarning;
  final List<Map<String, dynamic>> processedItems;
  final List<Map<String, dynamic>> materialConsumptions;
  final List<Map<String, dynamic>> operatorWorkLogs;
  final List<Map<String, dynamic>> scrapItems;

  bool get isReworkAndPainting => processProfileType == 'rework_and_painting';

  int? get catalogVersion {
    final v = profileSnapshot?['catalogVersion'];
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  String get profileDisplayName {
    final fromSnap = (profileSnapshot?['displayName'] ?? '').toString().trim();
    if (fromSnap.isNotEmpty) return fromSnap;
    return processProfileType;
  }

  List<Map<String, dynamic>> get profileFieldDefs {
    final raw = profileSnapshot?['fields'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  factory ProfileDrivenEvidenceSessionDetail.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> fv = const {};
    if (m['fieldValues'] is Map) {
      fv = Map<String, dynamic>.from(m['fieldValues'] as Map);
    }
    Map<String, dynamic>? profileSnapshot;
    if (m['profileSnapshot'] is Map) {
      profileSnapshot = Map<String, dynamic>.from(m['profileSnapshot'] as Map);
    }
    Map<String, dynamic>? warning;
    if (m['controlledInputWarning'] is Map) {
      warning = Map<String, dynamic>.from(m['controlledInputWarning'] as Map);
    }

    return ProfileDrivenEvidenceSessionDetail(
      sessionId: (m['sessionId'] ?? '').toString().trim(),
      companyId: (m['companyId'] ?? '').toString().trim(),
      stationConfigId: (m['stationConfigId'] ?? '').toString().trim(),
      stationSlot: (m['stationSlot'] as num?)?.toInt(),
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      processProfileType: (m['processProfileType'] ?? '').toString().trim(),
      status: (m['status'] ?? '').toString().trim(),
      stationDisplayName: _opt(m['stationDisplayName']),
      startedAt: _ts(m['startedAt']),
      endedAt: _ts(m['endedAt']),
      createdAt: _ts(m['createdAt']),
      operatorId: _opt(m['operatorId']),
      operatorEmail: _opt(m['operatorEmail']),
      operatorDisplayName: _opt(m['operatorDisplayName']),
      createdByUid: _opt(m['createdByUid']),
      createdByEmail: _opt(m['createdByEmail']),
      createdByDisplayName: _opt(m['createdByDisplayName']),
      profileSnapshot: profileSnapshot,
      fieldValues: fv,
      summaryFields: ProfileDrivenEvidenceSummaryFields.fromMap(
        m['summaryFields'] is Map
            ? Map<String, dynamic>.from(m['summaryFields'] as Map)
            : null,
      ),
      controlledInputWarning: warning,
      processedItems: _parseRowList(m['processed_items']),
      materialConsumptions: _parseRowList(m['material_consumptions']),
      operatorWorkLogs: _parseRowList(m['operator_work_logs']),
      scrapItems: _parseRowList(m['scrap_items']),
    );
  }
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is Map) {
    final seconds = v['seconds'] ?? v['_seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
  }
  if (v is String && v.trim().isNotEmpty) {
    return DateTime.tryParse(v.trim())?.toLocal();
  }
  return null;
}

String? _opt(dynamic v) {
  final t = (v ?? '').toString().trim();
  return t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _parseRowList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

String formatEvidenceDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final d =
      '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  final t =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$d $t';
}

String formatEvidenceDateShort(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final y = local.year % 100;
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${y.toString().padLeft(2, '0')}';
}

String formatEvidenceTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String formatHeavyMetalsLabel(String? raw) {
  if (raw == null) return '—';
  final v = raw.trim().toLowerCase();
  if (v == 'yes' || v == 'true' || v == 'da') return 'DA';
  if (v == 'no' || v == 'false' || v == 'ne') return 'NE';
  return raw;
}

String formatEvidenceDateOnly(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

String formatFieldValue(dynamic v) {
  if (v == null) return '—';
  if (v is num) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
  final s = v.toString().trim();
  return s.isEmpty ? '—' : s;
}
