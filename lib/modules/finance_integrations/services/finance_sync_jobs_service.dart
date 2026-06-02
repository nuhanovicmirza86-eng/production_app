import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_sync_job_model.dart';

/// Čitanje poslova sinkronizacije preko Callable [listFinanceSyncJobs]
/// (`operonix-finance-integrations`). Bez direktnog Firestore reada na `(default)`.
class FinanceSyncJobsService {
  FinanceSyncJobsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'europe-west1';
  static const String _listCallableName = 'listFinanceSyncJobs';
  static const int _limit = 80;

  final FirebaseFunctions _functions;

  /// Poslovi koji zahtijevaju pažnju (sinkronizacija) — filter na klijentu iz [watchJobs].
  Stream<List<FinanceSyncJobModel>> watchProblemJobs(String companyId) {
    return watchJobs(companyId).map((list) {
      const bad = {'failed', 'requires_manual_review', 'retry_pending'};
      return list
          .where((j) => bad.contains(j.status.trim().toLowerCase()))
          .take(40)
          .toList();
    });
  }

  /// Isti API kao prije M4-C; jednokratno učitavanje preko Callablea (nema live snapshota).
  Stream<List<FinanceSyncJobModel>> watchJobs(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceSyncJobModel>>.value(const []);
    }
    return Stream.fromFuture(_fetchJobs(cid));
  }

  Future<List<FinanceSyncJobModel>> _fetchJobs(String companyId) async {
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

    final list = <FinanceSyncJobModel>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      _normalizeCallableTimestamps(item);
      list.add(FinanceSyncJobModel.fromFirestore(id, item));
    }

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
  }

  static void _normalizeCallableTimestamps(Map<String, dynamic> item) {
    for (final key in ['createdAt', 'updatedAt']) {
      final dt = _parseCallableTimestamp(item[key]);
      if (dt != null) {
        item[key] = dt;
      }
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
