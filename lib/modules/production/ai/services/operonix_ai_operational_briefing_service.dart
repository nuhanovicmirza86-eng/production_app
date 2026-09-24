import 'package:cloud_functions/cloud_functions.dart';

/// AI-M3-G4 — get / refresh / viewed / acknowledge daily operational briefing.
class OperonixAiOperationalBriefingService {
  OperonixAiOperationalBriefingService({
    FirebaseFunctions? functions,
  }) : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<OperonixAiOperationalBriefingSnapshot> getBriefing({
    required String companyId,
    required String plantKey,
    String? briefingDay,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (pk.isEmpty) {
      throw StateError('Odaberi pogon za prikaz briefinga.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
    };
    final day = (briefingDay ?? '').trim();
    if (day.isNotEmpty) payload['briefingDay'] = day;

    final callable =
        _functions.httpsCallable('getOperonixAiOperationalBriefing');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final b = data['briefing'];
    if (b is Map) {
      return OperonixAiOperationalBriefingSnapshot.fromMap(
        Map<String, dynamic>.from(b),
      );
    }
    return OperonixAiOperationalBriefingSnapshot.empty();
  }

  Future<OperonixAiOperationalBriefingSnapshot> refreshBriefing({
    required String companyId,
    required String plantKey,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (pk.isEmpty) {
      throw StateError('Odaberi pogon za osvježavanje briefinga.');
    }

    final callable =
        _functions.httpsCallable('refreshOperonixAiOperationalBriefing');
    final raw = await callable.call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
    });
    final data = raw.data;
    final b = data['briefing'];
    if (b is Map) {
      return OperonixAiOperationalBriefingSnapshot.fromMap(
        Map<String, dynamic>.from(b),
      );
    }
    final list = data['briefings'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      return OperonixAiOperationalBriefingSnapshot.fromMap(
        Map<String, dynamic>.from(list.first as Map),
      );
    }
    return getBriefing(companyId: cid, plantKey: pk);
  }

  Future<OperonixAiOperationalBriefingSnapshot> markViewed({
    required String companyId,
    required String briefingKey,
    String? plantKey,
  }) async {
    return _lifecycle(
      callableName: 'markOperonixAiOperationalBriefingViewed',
      companyId: companyId,
      briefingKey: briefingKey,
      plantKey: plantKey,
    );
  }

  Future<OperonixAiOperationalBriefingSnapshot> acknowledge({
    required String companyId,
    required String briefingKey,
    String? plantKey,
  }) async {
    return _lifecycle(
      callableName: 'acknowledgeOperonixAiOperationalBriefing',
      companyId: companyId,
      briefingKey: briefingKey,
      plantKey: plantKey,
    );
  }

  Future<OperonixAiOperationalBriefingSnapshot> _lifecycle({
    required String callableName,
    required String companyId,
    required String briefingKey,
    String? plantKey,
  }) async {
    final cid = companyId.trim();
    final key = briefingKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (key.isEmpty) {
      throw StateError('Nedostaje identifikator briefinga.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'briefingKey': key,
    };
    final pk = (plantKey ?? '').trim();
    if (pk.isNotEmpty) payload['plantKey'] = pk;

    final callable = _functions.httpsCallable(callableName);
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final b = data['briefing'];
    if (b is Map) {
      return OperonixAiOperationalBriefingSnapshot.fromMap(
        Map<String, dynamic>.from(b),
      );
    }
    throw StateError('Nepotpuni odgovor briefinga.');
  }
}

class OperonixAiOperationalBriefingSnapshot {
  const OperonixAiOperationalBriefingSnapshot({
    required this.found,
    required this.briefingKey,
    required this.companyDisplayName,
    required this.plantDisplayName,
    required this.briefingDayLabel,
    required this.status,
    required this.statusLabel,
    required this.summaryText,
    required this.recommendedFirstAction,
    required this.topRisks,
    required this.topOpportunities,
    required this.openAlerts,
    required this.changes,
    required this.periodFromLabel,
    required this.periodToLabel,
    required this.refreshSourceLabel,
    required this.riskCount,
    required this.opportunityCount,
    required this.openAlertCount,
  });

  final bool found;
  final String briefingKey;
  final String companyDisplayName;
  final String plantDisplayName;
  final String? briefingDayLabel;
  final String status;
  final String statusLabel;
  final String summaryText;
  final String recommendedFirstAction;
  final List<OperonixAiBriefingRiskItem> topRisks;
  final List<OperonixAiBriefingOpportunityItem> topOpportunities;
  final List<OperonixAiBriefingOpenAlertItem> openAlerts;
  final OperonixAiBriefingChanges changes;
  final String? periodFromLabel;
  final String? periodToLabel;
  final String? refreshSourceLabel;
  final int riskCount;
  final int opportunityCount;
  final int openAlertCount;

  bool get isAcknowledged => status == 'acknowledged';
  bool get isViewed => status == 'viewed' || isAcknowledged;
  bool get needsViewMark => found && briefingKey.isNotEmpty && status == 'generated';

  factory OperonixAiOperationalBriefingSnapshot.empty() =>
      const OperonixAiOperationalBriefingSnapshot(
        found: false,
        briefingKey: '',
        companyDisplayName: 'Tvrtka',
        plantDisplayName: 'Pogon',
        briefingDayLabel: null,
        status: 'generated',
        statusLabel: 'Generisan',
        summaryText: 'Nedovoljno podataka za sigurnu preporuku.',
        recommendedFirstAction: 'Nedovoljno podataka za sigurnu preporuku.',
        topRisks: [],
        topOpportunities: [],
        openAlerts: [],
        changes: OperonixAiBriefingChanges.empty,
        periodFromLabel: null,
        periodToLabel: null,
        refreshSourceLabel: null,
        riskCount: 0,
        opportunityCount: 0,
        openAlertCount: 0,
      );

  factory OperonixAiOperationalBriefingSnapshot.fromMap(
    Map<String, dynamic> m,
  ) {
    final period = m['period'];
    String? fromLabel;
    String? toLabel;
    if (period is Map) {
      final fl = (period['fromLabel'] ?? '').toString().trim();
      final tl = (period['toLabel'] ?? '').toString().trim();
      fromLabel = fl.isEmpty ? null : fl;
      toLabel = tl.isEmpty ? null : tl;
    }

    final src = (m['refreshSource'] ?? '').toString().trim();
    String? refreshLabel;
    if (src == 'scheduled') {
      refreshLabel = 'Osvježeno automatski';
    } else if (src == 'manual') {
      refreshLabel = 'Osvježeno ručno';
    }

    final risks = <OperonixAiBriefingRiskItem>[];
    final rawRisks = m['topRisks'];
    if (rawRisks is List) {
      for (final r in rawRisks) {
        if (r is Map) {
          risks.add(
            OperonixAiBriefingRiskItem.fromMap(Map<String, dynamic>.from(r)),
          );
        }
      }
    }

    final opps = <OperonixAiBriefingOpportunityItem>[];
    final rawOpps = m['topOpportunities'];
    if (rawOpps is List) {
      for (final o in rawOpps) {
        if (o is Map) {
          opps.add(
            OperonixAiBriefingOpportunityItem.fromMap(
              Map<String, dynamic>.from(o),
            ),
          );
        }
      }
    }

    final alerts = <OperonixAiBriefingOpenAlertItem>[];
    final rawAlerts = m['openAlerts'];
    if (rawAlerts is List) {
      for (final a in rawAlerts) {
        if (a is Map) {
          alerts.add(
            OperonixAiBriefingOpenAlertItem.fromMap(
              Map<String, dynamic>.from(a),
            ),
          );
        }
      }
    }

    final counts = m['counts'];
    var riskCount = risks.length;
    var opportunityCount = opps.length;
    var openAlertCount = alerts.length;
    if (counts is Map) {
      riskCount = (counts['riskCount'] as num?)?.toInt() ?? riskCount;
      opportunityCount =
          (counts['opportunityCount'] as num?)?.toInt() ?? opportunityCount;
      openAlertCount =
          (counts['openAlertCount'] as num?)?.toInt() ?? openAlertCount;
    }

    final dayLabel = (m['briefingDayLabel'] ?? '').toString().trim();
    final status = (m['status'] ?? 'generated').toString().trim();
    final statusLabel = (m['statusLabel'] ?? '').toString().trim();

    return OperonixAiOperationalBriefingSnapshot(
      found: m['found'] != false,
      briefingKey: (m['briefingKey'] ?? '').toString().trim(),
      companyDisplayName: _display(
        m['companyDisplayName'],
        fallback: 'Tvrtka',
      ),
      plantDisplayName: _display(m['plantDisplayName'], fallback: 'Pogon'),
      briefingDayLabel: dayLabel.isEmpty ? null : dayLabel,
      status: status.isEmpty ? 'generated' : status,
      statusLabel: statusLabel.isEmpty
          ? _statusLabelBcs(status)
          : statusLabel,
      summaryText: (m['summaryText'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      recommendedFirstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      topRisks: risks,
      topOpportunities: opps,
      openAlerts: alerts,
      changes: OperonixAiBriefingChanges.fromMap(
        m['changesFromPrevious'] is Map
            ? Map<String, dynamic>.from(m['changesFromPrevious'] as Map)
            : const {},
      ),
      periodFromLabel: fromLabel,
      periodToLabel: toLabel,
      refreshSourceLabel: refreshLabel,
      riskCount: riskCount,
      opportunityCount: opportunityCount,
      openAlertCount: openAlertCount,
    );
  }

  static String _display(dynamic raw, {required String fallback}) {
    final s = (raw ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String _statusLabelBcs(String status) {
    switch (status) {
      case 'viewed':
        return 'Pregledan';
      case 'acknowledged':
        return 'Potvrđen';
      default:
        return 'Generisan';
    }
  }
}

class OperonixAiBriefingChanges {
  const OperonixAiBriefingChanges({
    required this.hasPrevious,
    required this.summaryText,
    required this.lines,
  });

  final bool hasPrevious;
  final String summaryText;
  final List<String> lines;

  static const empty = OperonixAiBriefingChanges(
    hasPrevious: false,
    summaryText: 'Nema prethodnog briefinga za poređenje.',
    lines: ['Nema prethodnog briefinga za poređenje.'],
  );

  factory OperonixAiBriefingChanges.fromMap(Map<String, dynamic> m) {
    final lines = <String>[];
    final raw = m['lines'];
    if (raw is List) {
      for (final x in raw) {
        final s = x.toString().trim();
        if (s.isNotEmpty) lines.add(s);
      }
    }
    final summary = (m['summaryText'] ?? '').toString().trim();
    return OperonixAiBriefingChanges(
      hasPrevious: m['hasPrevious'] == true,
      summaryText: summary.isEmpty
          ? 'Nema prethodnog briefinga za poređenje.'
          : summary,
      lines: lines.isEmpty
          ? [
              summary.isEmpty
                  ? 'Nema prethodnog briefinga za poređenje.'
                  : summary,
            ]
          : lines,
    );
  }
}

class OperonixAiBriefingRiskItem {
  const OperonixAiBriefingRiskItem({
    required this.rank,
    required this.typeLabel,
    required this.score,
    required this.evidence,
    required this.firstAction,
    required this.products,
    required this.machines,
    this.riskLevel,
  });

  final int rank;
  final String typeLabel;
  final int score;
  final String evidence;
  final String firstAction;
  final List<String> products;
  final List<String> machines;
  final String? riskLevel;

  factory OperonixAiBriefingRiskItem.fromMap(Map<String, dynamic> m) {
    return OperonixAiBriefingRiskItem(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      typeLabel: (m['typeLabel'] ?? 'Operativni rizik').toString().trim(),
      score: (m['score'] as num?)?.toInt() ?? 0,
      evidence: (m['evidence'] ?? 'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      firstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      products: _labels(m['affectedProducts']),
      machines: _labels(m['affectedMachines']),
      riskLevel: _riskLevelBcs(m['riskLevel']?.toString()),
    );
  }
}

class OperonixAiBriefingOpportunityItem {
  const OperonixAiBriefingOpportunityItem({
    required this.rank,
    required this.typeLabel,
    required this.score,
    required this.evidence,
    required this.firstAction,
    required this.products,
    required this.machines,
  });

  final int rank;
  final String typeLabel;
  final int score;
  final String evidence;
  final String firstAction;
  final List<String> products;
  final List<String> machines;

  factory OperonixAiBriefingOpportunityItem.fromMap(Map<String, dynamic> m) {
    return OperonixAiBriefingOpportunityItem(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      typeLabel: (m['typeLabel'] ?? 'Prilika za poboljšanje').toString().trim(),
      score: (m['score'] as num?)?.toInt() ?? 0,
      evidence: (m['evidence'] ?? 'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      firstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      products: _labels(m['affectedProducts']),
      machines: _labels(m['affectedMachines']),
    );
  }
}

class OperonixAiBriefingOpenAlertItem {
  const OperonixAiBriefingOpenAlertItem({
    required this.kindLabel,
    required this.typeLabel,
    required this.statusLabel,
    required this.severityLabel,
    required this.plantDisplayName,
    required this.score,
  });

  final String kindLabel;
  final String typeLabel;
  final String statusLabel;
  final String severityLabel;
  final String plantDisplayName;
  final int score;

  factory OperonixAiBriefingOpenAlertItem.fromMap(Map<String, dynamic> m) {
    return OperonixAiBriefingOpenAlertItem(
      kindLabel: (m['kindLabel'] ?? 'Signal').toString().trim(),
      typeLabel: (m['typeLabel'] ?? '').toString().trim(),
      statusLabel: (m['statusLabel'] ?? 'Novo').toString().trim(),
      severityLabel: (m['severityLabel'] ?? 'Srednje').toString().trim(),
      plantDisplayName: (m['plantDisplayName'] ?? 'Pogon').toString().trim(),
      score: (m['score'] as num?)?.toInt() ?? 0,
    );
  }
}

List<String> _labels(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty && !s.startsWith('PLANT_'))
      .where((s) => !RegExp(r'^[0-9a-f]{20,}$', caseSensitive: false).hasMatch(s))
      .take(4)
      .toList();
}

String? _riskLevelBcs(String? raw) {
  final x = (raw ?? '').trim().toLowerCase();
  if (x.isEmpty) return null;
  if (x == 'high' || x == 'visok' || x == 'visoka') return 'Visok';
  if (x == 'medium' || x == 'srednji' || x == 'srednja') return 'Srednji';
  if (x == 'low' || x == 'nizak' || x == 'niska') return 'Nizak';
  if (RegExp(r'^[a-z_]+$').hasMatch(x)) return null;
  return raw!.trim();
}
