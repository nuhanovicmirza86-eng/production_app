import 'package:cloud_firestore/cloud_firestore.dart';

/// Čitanje šifrarnika poslovnih godina: `companies/{companyId}/financial_years`.
///
/// Polje **`businessYearId`** u financijskim dokumentima = [QueryDocumentSnapshot.id].
class CompanyFinancialYearsService {
  CompanyFinancialYearsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Aktivna(i) i zatvorene godine — sort po početku godine.
  Stream<List<FinancialYearListItem>> watchYears(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinancialYearListItem>>.value(const []);
    }
    return _db
        .collection('companies')
        .doc(cid)
        .collection('financial_years')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinancialYearListItem(
                  id: d.id,
                  data: d.data(),
                ),
              )
              .toList();
          list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
          return list;
        });
  }
}

class FinancialYearListItem {
  FinancialYearListItem({
    required this.id,
    required Map<String, dynamic> data,
  })  : name = (data['name'] ?? data['label'] ?? '').toString().trim(),
        status = (data['status'] ?? '').toString().trim().toLowerCase(),
        startMs = _tsMillis(data['startDate']);

  final String id;
  final String name;
  final String status;
  final int startMs;

  int get sortKey => startMs;

  String get displayLabel {
    if (name.isNotEmpty) return name;
    return id;
  }

  static int _tsMillis(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return 0;
  }
}
