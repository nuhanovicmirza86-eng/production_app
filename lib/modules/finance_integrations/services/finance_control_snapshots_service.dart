import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_control_snapshot_model.dart';

/// Čitanje kontrolnih snimaka preko Callable [listFinanceControlSnapshots]
/// (default DB, Admin SDK). Bez direktnog Firestore reada na `(default)`.
class FinanceControlSnapshotsService {
  FinanceControlSnapshotsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'europe-west1';
  static const String _listCallableName = 'listFinanceControlSnapshots';
  static const int _limit = 120;

  final FirebaseFunctions _functions;

  Stream<List<FinanceControlSnapshotModel>> watchSnapshots(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceControlSnapshotModel>>.value(const []);
    }
    return Stream.fromFuture(_fetchSnapshots(cid));
  }

  Future<List<FinanceControlSnapshotModel>> _fetchSnapshots(
    String companyId,
  ) async {
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

    final list = <FinanceControlSnapshotModel>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      _normalizeCallableTimestamps(item);
      list.add(FinanceControlSnapshotModel.fromFirestore(id, item));
    }

    list.sort((a, b) {
      final py = b.periodYear.compareTo(a.periodYear);
      if (py != 0) return py;
      final pm = b.periodMonth.compareTo(a.periodMonth);
      if (pm != 0) return pm;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  static void _normalizeCallableTimestamps(Map<String, dynamic> item) {
    final v = item['updatedAt'];
    final dt = _parseCallableTimestamp(v);
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
