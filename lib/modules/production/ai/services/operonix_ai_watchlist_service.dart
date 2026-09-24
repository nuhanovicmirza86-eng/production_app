import 'package:cloud_functions/cloud_functions.dart';

/// AI-M3-E4 — get / refresh / explain proactive watchlist (E2/E3 Callables).
class OperonixAiWatchlistService {
  OperonixAiWatchlistService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<OperonixAiWatchlistSnapshot> getWatchlist({
    required String companyId,
    required String plantKey,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (pk.isEmpty) {
      throw StateError('Odaberi pogon za prikaz liste praćenja.');
    }

    final callable = _functions.httpsCallable('getOperonixAiWatchlist');
    final raw = await callable.call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
    });
    final data = raw.data;
    final wl = data['watchlist'];
    if (wl is Map) {
      return OperonixAiWatchlistSnapshot.fromMap(
        Map<String, dynamic>.from(wl),
      );
    }
    return OperonixAiWatchlistSnapshot.empty();
  }

  Future<OperonixAiWatchlistSnapshot> refreshWatchlist({
    required String companyId,
    required String plantKey,
    String? dateFrom,
    String? dateTo,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (pk.isEmpty) {
      throw StateError('Odaberi pogon za osvježavanje liste praćenja.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
    };
    final from = (dateFrom ?? '').trim();
    final to = (dateTo ?? '').trim();
    if (from.isNotEmpty) payload['dateFrom'] = from;
    if (to.isNotEmpty) payload['dateTo'] = to;

    final callable = _functions.httpsCallable('refreshOperonixAiWatchlist');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final wl = data['watchlist'];
    if (wl is Map) {
      return OperonixAiWatchlistSnapshot.fromMap(
        Map<String, dynamic>.from(wl),
      );
    }
    final list = data['watchlists'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      return OperonixAiWatchlistSnapshot.fromMap(
        Map<String, dynamic>.from(list.first as Map),
      );
    }
    return getWatchlist(companyId: cid, plantKey: pk);
  }

  Future<String> explainWatchlist({
    required String companyId,
    required String plantKey,
    String? message,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke.');
    }
    if (pk.isEmpty) {
      throw StateError('Odaberi pogon za objašnjenje liste praćenja.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'message': (message ?? 'Objasni trenutnu listu praćenja rizika i prilika.')
          .trim(),
    };

    final callable = _functions.httpsCallable('explainOperonixAiWatchlist');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    final text = (data['explanation'] ?? data['response'] ?? '')
        .toString()
        .trim();
    if (text.isEmpty) {
      throw StateError('Prazno objašnjenje liste praćenja.');
    }
    return text;
  }
}

class OperonixAiWatchlistSnapshot {
  const OperonixAiWatchlistSnapshot({
    required this.found,
    required this.companyDisplayName,
    required this.plantDisplayName,
    required this.recommendedFirstAction,
    required this.topRisks,
    required this.topOpportunities,
    required this.periodFromLabel,
    required this.periodToLabel,
    required this.refreshSourceLabel,
  });

  final bool found;
  final String companyDisplayName;
  final String plantDisplayName;
  final String recommendedFirstAction;
  final List<OperonixAiWatchlistItem> topRisks;
  final List<OperonixAiWatchlistItem> topOpportunities;
  final String? periodFromLabel;
  final String? periodToLabel;
  final String? refreshSourceLabel;

  factory OperonixAiWatchlistSnapshot.empty() =>
      const OperonixAiWatchlistSnapshot(
        found: false,
        companyDisplayName: 'Tvrtka',
        plantDisplayName: 'Pogon',
        recommendedFirstAction: 'Nedovoljno podataka za sigurnu preporuku.',
        topRisks: [],
        topOpportunities: [],
        periodFromLabel: null,
        periodToLabel: null,
        refreshSourceLabel: null,
      );

  factory OperonixAiWatchlistSnapshot.fromMap(Map<String, dynamic> m) {
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

    final risks = <OperonixAiWatchlistItem>[];
    final rawRisks = m['topRisks'];
    if (rawRisks is List) {
      for (final r in rawRisks) {
        if (r is Map) {
          risks.add(
            OperonixAiWatchlistItem.fromRisk(Map<String, dynamic>.from(r)),
          );
        }
      }
    }

    final opps = <OperonixAiWatchlistItem>[];
    final rawOpps = m['topOpportunities'];
    if (rawOpps is List) {
      for (final o in rawOpps) {
        if (o is Map) {
          opps.add(
            OperonixAiWatchlistItem.fromOpportunity(
              Map<String, dynamic>.from(o),
            ),
          );
        }
      }
    }

    return OperonixAiWatchlistSnapshot(
      found: m['found'] != false,
      companyDisplayName:
          (m['companyDisplayName'] ?? 'Tvrtka').toString().trim().isEmpty
              ? 'Tvrtka'
              : (m['companyDisplayName'] ?? 'Tvrtka').toString().trim(),
      plantDisplayName:
          (m['plantDisplayName'] ?? 'Pogon').toString().trim().isEmpty
              ? 'Pogon'
              : (m['plantDisplayName'] ?? 'Pogon').toString().trim(),
      recommendedFirstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      topRisks: risks,
      topOpportunities: opps,
      periodFromLabel: fromLabel,
      periodToLabel: toLabel,
      refreshSourceLabel: refreshLabel,
    );
  }
}

class OperonixAiWatchlistItem {
  const OperonixAiWatchlistItem({
    required this.rank,
    required this.typeLabel,
    required this.score,
    required this.evidence,
    required this.products,
    required this.machines,
    required this.openOrders,
    required this.firstAction,
    this.riskLevel,
  });

  final int rank;
  final String typeLabel;
  final int score;
  final String evidence;
  final List<String> products;
  final List<String> machines;
  final List<String> openOrders;
  final String firstAction;
  final String? riskLevel;

  factory OperonixAiWatchlistItem.fromRisk(Map<String, dynamic> m) {
    return OperonixAiWatchlistItem(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      typeLabel: (m['riskTypeLabel'] ?? m['riskType'] ?? 'Operativni rizik')
          .toString()
          .trim(),
      score: (m['score'] as num?)?.toInt() ?? 0,
      evidence: (m['evidence'] ?? 'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      products: _labels(m['affectedProducts']),
      machines: _labels(m['affectedMachines']),
      openOrders: _labels(m['affectedOpenOrders']),
      firstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      riskLevel: _riskLevelBcs(m['riskLevel']?.toString()),
    );
  }

  factory OperonixAiWatchlistItem.fromOpportunity(Map<String, dynamic> m) {
    return OperonixAiWatchlistItem(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      typeLabel:
          (m['opportunityTypeLabel'] ?? m['opportunityType'] ?? 'Prilika')
              .toString()
              .trim(),
      score: (m['score'] as num?)?.toInt() ?? 0,
      evidence: (m['evidence'] ?? 'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
      products: _labels(m['affectedProducts']),
      machines: _labels(m['affectedMachines']),
      openOrders: _labels(m['affectedOpenOrders']),
      firstAction: (m['recommendedFirstAction'] ??
              'Nedovoljno podataka za sigurnu preporuku.')
          .toString()
          .trim(),
    );
  }

  static List<String> _labels(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty && !s.startsWith('PLANT_'))
        .take(4)
        .toList();
  }

  static String? _riskLevelBcs(String? raw) {
    final x = (raw ?? '').trim().toLowerCase();
    if (x.isEmpty) return null;
    if (x == 'high' || x == 'visok' || x == 'visoka') return 'Visok';
    if (x == 'medium' || x == 'srednji' || x == 'srednja') return 'Srednji';
    if (x == 'low' || x == 'nizak' || x == 'niska') return 'Nizak';
    if (x.contains('nedovolj') || x == 'insufficient') {
      return 'Nedovoljno podataka';
    }
    // Already BCS or unknown — avoid raw EN codes in UI
    if (x == 'visok' || x == 'srednji' || x == 'nizak') return raw!.trim();
    if (RegExp(r'^[a-z_]+$').hasMatch(x)) return null;
    return raw!.trim();
  }
}
