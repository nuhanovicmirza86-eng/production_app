import 'package:cloud_firestore/cloud_firestore.dart';

import '../quality_firestore_collections.dart';

/// Read-only upiti za QMS kolekcije (tenant). Upisi idu kroz Callable kada su definisani.
class QualityQueryService {
  QualityQueryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<int> countControlPlans({required String companyId}) async {
    try {
      final q = await _db
          .collection(QualityFirestoreCollections.controlPlans)
          .where('companyId', isEqualTo: companyId)
          .limit(500)
          .get();
      return q.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> countInspectionPlans({required String companyId}) async {
    try {
      final q = await _db
          .collection(QualityFirestoreCollections.inspectionPlans)
          .where('companyId', isEqualTo: companyId)
          .limit(500)
          .get();
      return q.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> countOpenNcrs({required String companyId}) async {
    try {
      final q = await _db
          .collection(QualityFirestoreCollections.nonConformances)
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: ['OPEN', 'UNDER_REVIEW', 'CONTAINED'])
          .limit(500)
          .get();
      return q.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> countOpenCapas({required String companyId}) async {
    try {
      final q = await _db
          .collection(QualityFirestoreCollections.actionPlans)
          .where('companyId', isEqualTo: companyId)
          .where('sourceType', isEqualTo: 'non_conformance')
          .where('status', whereIn: ['open', 'in_progress', 'waiting_verification'])
          .limit(500)
          .get();
      return q.docs.length;
    } catch (_) {
      return 0;
    }
  }
}
