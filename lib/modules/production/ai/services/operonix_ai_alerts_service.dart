import 'package:cloud_functions/cloud_functions.dart';

/// AI-M3-F4 — list / seen / snooze / resolve Operonix AI alerts (F2 Callables).
class OperonixAiAlertsService {
  OperonixAiAlertsService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<OperonixAiAlertItem>> listAlerts({
    required String companyId,
    String? plantKey,
    bool includeResolved = false,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'includeResolved': includeResolved,
    };
    final pk = (plantKey ?? '').trim();
    if (pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }

    final callable = _functions.httpsCallable('listOperonixAiAlerts');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final list = data['alerts'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => OperonixAiAlertItem.fromMap(Map<String, dynamic>.from(m)))
        .where((a) => a.alertKey.isNotEmpty)
        .toList();
  }

  Future<OperonixAiAlertItem> markSeen({
    required String companyId,
    required String alertKey,
    String? plantKey,
  }) async {
    return _lifecycle(
      callableName: 'markOperonixAiAlertSeen',
      companyId: companyId,
      alertKey: alertKey,
      plantKey: plantKey,
    );
  }

  Future<OperonixAiAlertItem> snooze({
    required String companyId,
    required String alertKey,
    String? plantKey,
    String? reason,
    int snoozeDays = 1,
  }) async {
    return _lifecycle(
      callableName: 'snoozeOperonixAiAlert',
      companyId: companyId,
      alertKey: alertKey,
      plantKey: plantKey,
      extra: {
        if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
        'snoozeDays': snoozeDays,
      },
    );
  }

  Future<OperonixAiAlertItem> resolve({
    required String companyId,
    required String alertKey,
    String? plantKey,
  }) async {
    return _lifecycle(
      callableName: 'resolveOperonixAiAlert',
      companyId: companyId,
      alertKey: alertKey,
      plantKey: plantKey,
    );
  }

  Future<OperonixAiAlertItem> _lifecycle({
    required String callableName,
    required String companyId,
    required String alertKey,
    String? plantKey,
    Map<String, dynamic>? extra,
  }) async {
    final cid = companyId.trim();
    final key = alertKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (key.isEmpty) {
      throw StateError('Nedostaje identifikator upozorenja.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'alertKey': key,
      ...?extra,
    };
    final pk = (plantKey ?? '').trim();
    if (pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }

    final callable = _functions.httpsCallable(callableName);
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final alert = data['alert'];
    if (alert is Map) {
      return OperonixAiAlertItem.fromMap(Map<String, dynamic>.from(alert));
    }
    throw StateError('Prazan odgovor za upozorenje.');
  }
}

class OperonixAiAlertItem {
  const OperonixAiAlertItem({
    required this.alertKey,
    required this.companyDisplayName,
    required this.plantDisplayName,
    required this.kindLabel,
    required this.typeLabel,
    required this.severityLabel,
    required this.status,
    required this.statusLabel,
    required this.score,
    required this.evidence,
    required this.recommendedFirstAction,
    required this.affectedProducts,
    required this.affectedMachines,
    this.snoozeReason,
    this.snoozeUntilLabel,
  });

  /// Opaque round-trip for Callables — never shown in UI.
  final String alertKey;
  final String companyDisplayName;
  final String plantDisplayName;
  final String kindLabel;
  final String typeLabel;
  final String severityLabel;
  final String status;
  final String statusLabel;
  final int score;
  final String? evidence;
  final String? recommendedFirstAction;
  final List<String> affectedProducts;
  final List<String> affectedMachines;
  final String? snoozeReason;
  final String? snoozeUntilLabel;

  bool get isResolved => status == 'resolved';
  bool get isDeferred => status == 'deferred';
  bool get isSeen => status == 'seen';
  bool get isNew => status == 'new';

  factory OperonixAiAlertItem.fromMap(Map<String, dynamic> m) {
    List<String> labels(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((x) => (x ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return OperonixAiAlertItem(
      alertKey: (m['alertKey'] ?? '').toString().trim(),
      companyDisplayName:
          (m['companyDisplayName'] ?? 'Kompanija').toString().trim(),
      plantDisplayName: (m['plantDisplayName'] ?? 'Pogon').toString().trim(),
      kindLabel: (m['kindLabel'] ?? 'Signal').toString().trim(),
      typeLabel: (m['typeLabel'] ?? '').toString().trim(),
      severityLabel: (m['severityLabel'] ?? 'Srednje').toString().trim(),
      status: (m['status'] ?? 'new').toString().trim(),
      statusLabel: (m['statusLabel'] ?? 'Novo').toString().trim(),
      score: (m['score'] is num)
          ? (m['score'] as num).round()
          : int.tryParse('${m['score']}') ?? 0,
      evidence: () {
        final s = (m['evidence'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      recommendedFirstAction: () {
        final s = (m['recommendedFirstAction'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      affectedProducts: labels(m['affectedProducts']),
      affectedMachines: labels(m['affectedMachines']),
      snoozeReason: () {
        final s = (m['snoozeReason'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      snoozeUntilLabel: () {
        final s = (m['snoozeUntilLabel'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
    );
  }
}
