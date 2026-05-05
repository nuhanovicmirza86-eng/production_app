import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_connection_model.dart';

class FinanceConnectionService {
  FinanceConnectionService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Čitanje veza za tenant; sortiranje po nazivu na klijentu.
  Stream<List<FinanceConnectionModel>> watchConnections(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceConnectionModel>>.value(const []);
    }
    return _db
        .collection('finance_connections')
        .where('companyId', isEqualTo: cid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinanceConnectionModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            final an = a.connectionName.toLowerCase();
            final bn = b.connectionName.toLowerCase();
            final c = an.compareTo(bn);
            if (c != 0) return c;
            return a.id.compareTo(b.id);
          });
          return list;
        });
  }
}
