import 'package:cloud_firestore/cloud_firestore.dart';

/// `finance_ai_company_memory/{companyId}` — tekstualni kontekst za Finance AI (Callable write).
class FinanceAiCompanyMemoryDoc {
  const FinanceAiCompanyMemoryDoc({
    required this.companyId,
    this.assistantContext = '',
    this.updatedAt,
    this.updatedByUid = '',
  });

  final String companyId;
  final String assistantContext;
  final DateTime? updatedAt;
  final String updatedByUid;

  static FinanceAiCompanyMemoryDoc? fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final cid = (data['companyId'] ?? docId).toString().trim();
    if (cid.isEmpty) return null;
    DateTime? updated;
    final ua = data['updatedAt'];
    if (ua is Timestamp) updated = ua.toDate();

    return FinanceAiCompanyMemoryDoc(
      companyId: cid,
      assistantContext: (data['assistantContext'] ?? '').toString(),
      updatedAt: updated,
      updatedByUid: (data['updatedByUid'] ?? '').toString(),
    );
  }
}
