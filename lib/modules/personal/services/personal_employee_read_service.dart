import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/personal_employee_doc.dart';

/// Čitanje `employees` za Personal modul (bez pisanja).
class PersonalEmployeeReadService {
  PersonalEmployeeReadService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Strim zaposlenika firme, sort po `lastName` rastuće.
  ///
  /// Zahtjeva Firestore indeks `companyId` + `lastName` kada prvi put radi u projektu.
  Stream<List<PersonalEmployeeDoc>> streamEmployees({
    required String companyId,
  }) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream.value(const []);
    }

    return _db
        .collection('employees')
        .where('companyId', isEqualTo: cid)
        .orderBy('lastName')
        .snapshots()
        .map(
          (snap) => snap.docs.map(PersonalEmployeeDoc.fromSnapshot).toList(),
        );
  }
}
