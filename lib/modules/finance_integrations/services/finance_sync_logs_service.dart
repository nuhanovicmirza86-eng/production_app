import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_sync_log_model.dart';

/// Čitanje sync logova preko Callable [listFinanceSyncLogs]
/// (`operonix-finance-integrations`). Bez direktnog Firestore reada na `(default)`.
class FinanceSyncLogsService {
  FinanceSyncLogsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'europe-west1';
  static const String _listCallableName = 'listFinanceSyncLogs';
  static const int _limit = 120;

  final FirebaseFunctions _functions;

  /// Isti API kao prije M4-D; jednokratno učitavanje preko Callablea (nema live snapshota).
  Stream<List<FinanceSyncLogModel>> watchLogs(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceSyncLogModel>>.value(const []);
    }
    return Stream.fromFuture(_fetchLogs(cid));
  }

  Future<List<FinanceSyncLogModel>> _fetchLogs(String companyId) async {
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

    final list = <FinanceSyncLogModel>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      _normalizeCallableTimestamps(item);
      list.add(FinanceSyncLogModel.fromFirestore(id, item));
    }

    list.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at != null && bt != null) {
        final c = bt.compareTo(at);
        if (c != 0) return c;
      } else if (at != null) {
        return -1;
      } else if (bt != null) {
        return 1;
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }

  static void _normalizeCallableTimestamps(Map<String, dynamic> item) {
    final dt = _parseCallableTimestamp(item['createdAt']);
    if (dt != null) {
      item['createdAt'] = dt;
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
