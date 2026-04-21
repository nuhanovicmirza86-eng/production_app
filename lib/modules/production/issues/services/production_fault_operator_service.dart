import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Operativni upisi kvarova iz Production app-a (isti `faults` kao Maintenance).
class ProductionFaultOperatorService {
  ProductionFaultOperatorService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String _s(dynamic v) => (v ?? '').toString().trim();

  User get _requireUser {
    final u = _auth.currentUser;
    if (u == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Nisi prijavljen.',
      );
    }
    return u;
  }

  /// Otkaz vlastite prijave u statusu `open`, prije nego je maintenance preuzeo.
  Future<void> cancelOwnOpenFault({
    required String faultId,
    required String expectedCompanyId,
    String? cancelReason,
  }) async {
    final user = _requireUser;
    final id = faultId.trim();
    final companyId = expectedCompanyId.trim();
    final reason = (cancelReason ?? '').trim();

    if (id.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'faultId je prazan.',
      );
    }
    if (companyId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'Nedostaje podatak o kompaniji. Obrati se administratoru.',
      );
    }

    final ref = _db.collection('faults').doc(id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Kvar ne postoji.',
        );
      }

      final d = snap.data() ?? <String, dynamic>{};
      final docCompany = _s(d['companyId']);
      if (docCompany != companyId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Kvar ne pripada ovoj kompaniji.',
        );
      }

      final status = _s(d['status']).toLowerCase();
      final createdByUid = _s(d['createdByUid']);
      final takenByUid = _s(d['takenByUid']);

      if (createdByUid != user.uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Možeš otkazati samo svoju prijavu.',
        );
      }
      if (status != 'open') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Možeš otkazati samo kvar u statusu OPEN.',
        );
      }
      if (takenByUid.isNotEmpty) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Kvar je već preuzet od održavanja.',
        );
      }

      tx.update(ref, <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledByUid': user.uid,
        'cancelledByEmail': (user.email ?? '').trim(),
        if (reason.isNotEmpty) 'cancelReason': reason,
      });
    });
  }
}
