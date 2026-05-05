import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_sync_log_model.dart';

class FinanceSyncLogsService {
  FinanceSyncLogsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int _limit = 120;

  Stream<List<FinanceSyncLogModel>> watchLogs(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceSyncLogModel>>.value(const []);
    }
    return _db
        .collection('finance_sync_logs')
        .where('companyId', isEqualTo: cid)
        .limit(_limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinanceSyncLogModel.fromFirestore(d.id, d.data()),
              )
              .toList();
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
        });
  }
}
