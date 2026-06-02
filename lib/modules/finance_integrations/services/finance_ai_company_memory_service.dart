import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_company_memory_doc.dart';

/// Čitanje memorije preko Callable [getFinanceAiCompanyMemory];
/// pisanje preko [upsertFinanceAiCompanyMemory]. Bez direktnog Firestore reada.
class FinanceAiCompanyMemoryService {
  FinanceAiCompanyMemoryService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static const String _getCallableName = 'getFinanceAiCompanyMemory';

  Stream<FinanceAiCompanyMemoryDoc?> watchMemory({required String companyId}) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<FinanceAiCompanyMemoryDoc?>.value(null);
    }
    return Stream.fromFuture(_fetchMemory(cid));
  }

  Future<FinanceAiCompanyMemoryDoc?> _fetchMemory(String companyId) async {
    final res = await _functions.httpsCallable(_getCallableName).call(
      <String, dynamic>{'companyId': companyId},
    );
    final raw = res.data;
    if (raw is! Map) {
      return null;
    }
    final m = Map<String, dynamic>.from(raw);
    if (m['ok'] != true) {
      return null;
    }

    final itemRaw = m['item'];
    if (itemRaw == null) {
      return null;
    }
    if (itemRaw is! Map) {
      return null;
    }
    final item = Map<String, dynamic>.from(itemRaw);
    final id = (item['documentId'] ?? companyId).toString().trim();
    if (id.isEmpty) {
      return null;
    }
    item.remove('documentId');
    _normalizeCallableTimestamps(item);
    return FinanceAiCompanyMemoryDoc.fromFirestore(id, item);
  }

  Future<void> upsertAssistantContext({
    required String companyId,
    required String assistantContext,
  }) async {
    final res = await _functions
        .httpsCallable('upsertFinanceAiCompanyMemory')
        .call(<String, dynamic>{
          'companyId': companyId.trim(),
          'assistantContext': assistantContext,
        });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Spremanje AI konteksta nije uspjelo.');
    }
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
