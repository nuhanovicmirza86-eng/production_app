import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_control_snapshot_model.dart';

class FinanceControlSnapshotsService {
  FinanceControlSnapshotsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const int _limit = 120;

  Stream<List<FinanceControlSnapshotModel>> watchSnapshots(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceControlSnapshotModel>>.value(const []);
    }
    return _db
        .collection('finance_control_snapshots')
        .where('companyId', isEqualTo: cid)
        .limit(_limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) =>
                    FinanceControlSnapshotModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            final py = b.periodYear.compareTo(a.periodYear);
            if (py != 0) return py;
            final pm = b.periodMonth.compareTo(a.periodMonth);
            if (pm != 0) return pm;
            return b.id.compareTo(a.id);
          });
          return list;
        });
  }
}
