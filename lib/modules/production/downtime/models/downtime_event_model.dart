import 'package:cloud_firestore/cloud_firestore.dart';

/// Kanonski ključevi kategorije (Firestore `downtimeCategory`).
abstract final class DowntimeCategoryKeys {
  static const String machineEquipment = 'machine_equipment';
  static const String tool = 'tool';
  static const String material = 'material';
  static const String quality = 'quality';
  static const String setup = 'setup';
  static const String waitingOperator = 'waiting_operator';
  static const String waitingLogistics = 'waiting_logistics';
  static const String waitingMaintenance = 'waiting_maintenance';
  static const String planned = 'planned';
  static const String micro = 'micro';
  static const String energy = 'energy';
  static const String itScada = 'it_scada_sensor';
  static const String safety = 'safety';
  static const String other = 'other';

  static const List<String> all = <String>[
    machineEquipment,
    tool,
    material,
    quality,
    setup,
    waitingOperator,
    waitingLogistics,
    waitingMaintenance,
    planned,
    micro,
    energy,
    itScada,
    safety,
    other,
  ];

  static String labelHr(String key) {
    switch (key) {
      case machineEquipment:
        return 'Mašina / oprema';
      case tool:
        return 'Alat';
      case material:
        return 'Materijal';
      case quality:
        return 'Kvalitet';
      case setup:
        return 'Podešavanje / set-up';
      case waitingOperator:
        return 'Čekanje operatera';
      case waitingLogistics:
        return 'Čekanje logistike';
      case waitingMaintenance:
        return 'Čekanje održavanja';
      case planned:
        return 'Planirani zastoj';
      case micro:
        return 'Mikro zastoj';
      case energy:
        return 'Energetski problem';
      case itScada:
        return 'IT / SCADA / senzor';
      case safety:
        return 'Sigurnosni razlog';
      case other:
        return 'Ostalo';
      default:
        return key;
    }
  }
}

abstract final class DowntimeEventStatus {
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String resolved = 'resolved';
  static const String verified = 'verified';
  static const String rejected = 'rejected';
  static const String archived = 'archived';

  static const List<String> all = <String>[
    open,
    inProgress,
    resolved,
    verified,
    rejected,
    archived,
  ];

  static String labelHr(String s) {
    switch (s) {
      case open:
        return 'Otvoren';
      case inProgress:
        return 'U tijeku';
      case resolved:
        return 'Riješen';
      case verified:
        return 'Verificiran';
      case rejected:
        return 'Odbijen';
      case archived:
        return 'Arhiviran';
      default:
        return s;
    }
  }

  static bool isOpenLike(String status) {
    final s = status.trim().toLowerCase();
    return s == open || s == inProgress;
  }
}

abstract final class DowntimeSeverity {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String critical = 'critical';

  static const List<String> all = <String>[low, medium, high, critical];

  static String labelHr(String s) {
    switch (s) {
      case low:
        return 'Nisko';
      case medium:
        return 'Srednje';
      case high:
        return 'Visoko';
      case critical:
        return 'Kritično';
      default:
        return s;
    }
  }
}

/// Jedan zapis zastoja — kolekcija `downtime_events`.
class DowntimeEventModel {
  final String id;
  final String companyId;
  final String plantKey;
  final String downtimeCode;

  final String productionOrderId;
  final String productionOrderCode;

  final String workCenterId;
  final String workCenterCode;
  final String workCenterName;

  final String processId;
  final String processCode;
  final String processName;

  final String shiftId;
  final String shiftName;

  final String downtimeCategory;
  final String downtimeReason;
  final String description;

  final String status;
  final String severity;

  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;

  final bool isPlanned;
  final bool affectsOee;
  final bool affectsOoe;
  final bool affectsTeep;

  final String operatorId;
  final String reportedBy;
  final String reportedByName;

  final String resolvedBy;
  final String resolvedByName;

  final String verifiedBy;
  final String verifiedByName;

  final bool correctiveActionRequired;
  final String correctiveActionId;

  final List<Map<String, dynamic>> attachments;

  final DateTime? createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;

  const DowntimeEventModel({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.downtimeCode,
    required this.productionOrderId,
    required this.productionOrderCode,
    required this.workCenterId,
    required this.workCenterCode,
    required this.workCenterName,
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.shiftId,
    required this.shiftName,
    required this.downtimeCategory,
    required this.downtimeReason,
    required this.description,
    required this.status,
    required this.severity,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.isPlanned,
    required this.affectsOee,
    required this.affectsOoe,
    required this.affectsTeep,
    required this.operatorId,
    required this.reportedBy,
    required this.reportedByName,
    required this.resolvedBy,
    required this.resolvedByName,
    required this.verifiedBy,
    required this.verifiedByName,
    required this.correctiveActionRequired,
    required this.correctiveActionId,
    required this.attachments,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static int? _iNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(_s(v));
  }

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  static List<Map<String, dynamic>> _attachments(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e.map((k, val) => MapEntry('$k', val))));
      }
    }
    return out;
  }

  factory DowntimeEventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return DowntimeEventModel(
        id: doc.id,
        companyId: '',
        plantKey: '',
        downtimeCode: '',
        productionOrderId: '',
        productionOrderCode: '',
        workCenterId: '',
        workCenterCode: '',
        workCenterName: '',
        processId: '',
        processCode: '',
        processName: '',
        shiftId: '',
        shiftName: '',
        downtimeCategory: '',
        downtimeReason: '',
        description: '',
        status: DowntimeEventStatus.open,
        severity: DowntimeSeverity.medium,
        startedAt: DateTime.fromMillisecondsSinceEpoch(0),
        endedAt: null,
        durationMinutes: null,
        isPlanned: false,
        affectsOee: true,
        affectsOoe: true,
        affectsTeep: true,
        operatorId: '',
        reportedBy: '',
        reportedByName: '',
        resolvedBy: '',
        resolvedByName: '',
        verifiedBy: '',
        verifiedByName: '',
        correctiveActionRequired: false,
        correctiveActionId: '',
        attachments: const [],
        createdAt: null,
        createdBy: '',
        updatedAt: null,
        updatedBy: '',
      );
    }

    return DowntimeEventModel(
      id: doc.id,
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      downtimeCode: _s(data['downtimeCode']),
      productionOrderId: _s(data['productionOrderId']),
      productionOrderCode: _s(data['productionOrderCode']),
      workCenterId: _s(data['workCenterId']),
      workCenterCode: _s(data['workCenterCode']),
      workCenterName: _s(data['workCenterName']),
      processId: _s(data['processId']),
      processCode: _s(data['processCode']),
      processName: _s(data['processName']),
      shiftId: _s(data['shiftId']),
      shiftName: _s(data['shiftName']),
      downtimeCategory: _s(data['downtimeCategory']),
      downtimeReason: _s(data['downtimeReason']),
      description: _s(data['description']),
      status: _s(data['status']).isEmpty
          ? DowntimeEventStatus.open
          : _s(data['status']),
      severity: _s(data['severity']).isEmpty
          ? DowntimeSeverity.medium
          : _s(data['severity']),
      startedAt: _ts(data['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: _ts(data['endedAt']),
      durationMinutes: _iNullable(data['durationMinutes']),
      isPlanned: _b(data['isPlanned']),
      affectsOee: _b(data['affectsOee'], fallback: true),
      affectsOoe: _b(data['affectsOoe'], fallback: true),
      affectsTeep: _b(data['affectsTeep'], fallback: true),
      operatorId: _s(data['operatorId']),
      reportedBy: _s(data['reportedBy']),
      reportedByName: _s(data['reportedByName']),
      resolvedBy: _s(data['resolvedBy']),
      resolvedByName: _s(data['resolvedByName']),
      verifiedBy: _s(data['verifiedBy']),
      verifiedByName: _s(data['verifiedByName']),
      correctiveActionRequired: _b(data['correctiveActionRequired']),
      correctiveActionId: _s(data['correctiveActionId']),
      attachments: _attachments(data['attachments']),
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }

  /// Trajanje za prikaz: zatvoreni koriste [durationMinutes], otvoreni live od [startedAt].
  int? effectiveDurationMinutesNow(DateTime now) {
    if (durationMinutes != null && durationMinutes! >= 0) {
      return durationMinutes;
    }
    if (endedAt != null) {
      final m = endedAt!.difference(startedAt).inMinutes;
      return m < 0 ? 0 : m;
    }
    if (!DowntimeEventStatus.isOpenLike(status)) {
      return durationMinutes;
    }
    final m = now.difference(startedAt).inMinutes;
    return m < 0 ? 0 : m;
  }

  bool get isClosedVerified => status == DowntimeEventStatus.verified;
}

/// KPI iz trenutno učitane liste (filtrirano po danu u UI).
class DowntimeKpiSummary {
  final int countToday;
  final int downtimeMinutesToday;
  final int openCount;
  final double avgDurationMinutesToday;
  final String topWorkCenterLabel;
  final String topReasonLabel;

  const DowntimeKpiSummary({
    required this.countToday,
    required this.downtimeMinutesToday,
    required this.openCount,
    required this.avgDurationMinutesToday,
    required this.topWorkCenterLabel,
    required this.topReasonLabel,
  });

  static DowntimeKpiSummary compute({
    required List<DowntimeEventModel> events,
    required DateTime nowLocal,
  }) {
    final startDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final endDay = startDay.add(const Duration(days: 1));

    final today = <DowntimeEventModel>[];
    for (final e in events) {
      if (!e.startedAt.isBefore(startDay) && e.startedAt.isBefore(endDay)) {
        today.add(e);
      }
    }

    var minutesSum = 0;
    for (final e in today) {
      final m = e.effectiveDurationMinutesNow(nowLocal) ?? 0;
      minutesSum += m;
    }

    final open = events.where((e) => DowntimeEventStatus.isOpenLike(e.status)).length;

    final avg = today.isEmpty ? 0.0 : minutesSum / today.length;

    final wcHits = <String, int>{};
    final reasonHits = <String, int>{};
    for (final e in today) {
      final wc = e.workCenterCode.isNotEmpty
          ? e.workCenterCode
          : (e.workCenterName.isNotEmpty ? e.workCenterName : '—');
      wcHits[wc] = (wcHits[wc] ?? 0) + 1;
      final r = e.downtimeReason.isNotEmpty ? e.downtimeReason : e.downtimeCategory;
      reasonHits[r] = (reasonHits[r] ?? 0) + 1;
    }

    String topKey(Map<String, int> m) {
      if (m.isEmpty) return '—';
      var bestK = '';
      var bestV = -1;
      m.forEach((k, v) {
        if (v > bestV) {
          bestV = v;
          bestK = k;
        }
      });
      return bestK;
    }

    return DowntimeKpiSummary(
      countToday: today.length,
      downtimeMinutesToday: minutesSum,
      openCount: open,
      avgDurationMinutesToday: avg,
      topWorkCenterLabel: topKey(wcHits),
      topReasonLabel: topKey(reasonHits),
    );
  }
}
