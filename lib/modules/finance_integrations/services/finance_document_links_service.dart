import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_document_link_model.dart';

/// Čitanje veza dokumenata preko Callable [listFinanceDocumentLinks]
/// (`operonix-finance-integrations`). Bez direktnog Firestore reada na `(default)`.
class FinanceDocumentLinksService {
  FinanceDocumentLinksService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'europe-west1';
  static const String _listCallableName = 'listFinanceDocumentLinks';
  static const int _limit = 100;

  final FirebaseFunctions _functions;

  /// Isti API kao prije M4-B; jednokratno učitavanje preko Callablea (nema live snapshota).
  Stream<List<FinanceDocumentLinkModel>> watchLinks(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceDocumentLinkModel>>.value(const []);
    }
    return Stream.fromFuture(_fetchLinks(cid));
  }

  Future<List<FinanceDocumentLinkModel>> _fetchLinks(String companyId) async {
    final callable = _functions.httpsCallable(_listCallableName);
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'limit': _limit,
    });

    final data = response.data;
    if (data is! Map) {
      return const [];
    }

    final rawItems = data['items'];
    if (rawItems is! List) {
      return const [];
    }

    final list = <FinanceDocumentLinkModel>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      _normalizeCallableTimestamps(item);
      list.add(FinanceDocumentLinkModel.fromFirestore(id, item));
    }

    list.sort((a, b) {
      final au = a.updatedAt;
      final bu = b.updatedAt;
      if (au != null && bu != null) {
        final c = bu.compareTo(au);
        if (c != 0) return c;
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }

  static void _normalizeCallableTimestamps(Map<String, dynamic> item) {
    final dt = _parseCallableTimestamp(item['updatedAt']);
    if (dt != null) {
      item['updatedAt'] = dt;
    }
  }

  static DateTime? _parseCallableTimestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map) {
      final sec = v['seconds'];
      final ns = v['nanoseconds'];
      if (sec is num) {
        final millis =
            sec.toInt() * 1000 + ((ns is num ? ns.toInt() : 0) ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      }
    }
    return null;
  }
}
