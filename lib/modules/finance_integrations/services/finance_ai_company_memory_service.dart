import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_company_memory_doc.dart';

/// Čitanje memorije + Callable [upsertFinanceAiCompanyMemory].
class FinanceAiCompanyMemoryService {
  FinanceAiCompanyMemoryService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<FinanceAiCompanyMemoryDoc?> watchMemory({required String companyId}) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<FinanceAiCompanyMemoryDoc?>.value(null);
    }
    return _db
        .collection('finance_ai_company_memory')
        .doc(cid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return FinanceAiCompanyMemoryDoc.fromFirestore(snap.id, snap.data()!);
    });
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
}
