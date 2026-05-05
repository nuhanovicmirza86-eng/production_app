import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_sync_job_model.dart';

class FinanceSyncJobsService {
  FinanceSyncJobsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int _limit = 80;

  Stream<List<FinanceSyncJobModel>> watchJobs(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceSyncJobModel>>.value(const []);
    }
    return _db
        .collection('finance_sync_jobs')
        .where('companyId', isEqualTo: cid)
        .limit(_limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinanceSyncJobModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            final au = a.updatedAt ?? a.createdAt;
            final bu = b.updatedAt ?? b.createdAt;
            if (au != null && bu != null) {
              final c = bu.compareTo(au);
              if (c != 0) return c;
            } else if (au != null) {
              return -1;
            } else if (bu != null) {
              return 1;
            }
            return b.id.compareTo(a.id);
          });
          return list;
        });
  }
}
