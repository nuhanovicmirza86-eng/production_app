import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_budget_doc.dart';

/// Read-only stream budžeta za tenant + FY + period.
class FinanceBudgetsService {
  FinanceBudgetsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<FinanceBudgetDoc>> watchForPeriod({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
  }) {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return Stream<List<FinanceBudgetDoc>>.value(const []);
    }
    return _db
        .collection('companies')
        .doc(cid)
        .collection('finance_budgets')
        .where('companyId', isEqualTo: cid)
        .where('businessYearId', isEqualTo: by)
        .where('periodYear', isEqualTo: periodYear)
        .where('periodMonth', isEqualTo: periodMonth)
        .snapshots()
        .map(
          (s) => s.docs.map(FinanceBudgetDoc.fromSnapshot).toList(),
        );
  }
}
