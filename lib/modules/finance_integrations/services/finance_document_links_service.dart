import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_document_link_model.dart';

class FinanceDocumentLinksService {
  FinanceDocumentLinksService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const int _limit = 100;

  Stream<List<FinanceDocumentLinkModel>> watchLinks(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceDocumentLinkModel>>.value(const []);
    }
    return _db
        .collection('finance_document_links')
        .where('companyId', isEqualTo: cid)
        .limit(_limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinanceDocumentLinkModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            final au = a.updatedAt;
            final bu = b.updatedAt;
            if (au != null && bu != null) {
              final c = bu.compareTo(au);
              if (c != 0) return c;
            }
            return b.id.compareTo(a.id);
          });
          return list;
        });
  }
}
