import 'package:cloud_firestore/cloud_firestore.dart';

class PartnerPick {
  final String id;
  final String code;
  final String name;

  const PartnerPick({
    required this.id,
    required this.code,
    required this.name,
  });
}

/// Minimalni lookup za kupce/dobavljače prema arhitekturi (`customers`, `suppliers`).
class PartnersLookupService {
  PartnersLookupService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<PartnerPick>> searchCustomers({
    required String companyId,
    required String query,
    int limit = 80,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _firestore
        .collection('customers')
        .where('companyId', isEqualTo: cid)
        .limit(limit)
        .get();

    return _filterAndMap(
      docs: snap.docs,
      query: query,
      codeField: 'code',
      nameField: 'name',
    );
  }

  Future<List<PartnerPick>> searchSuppliers({
    required String companyId,
    required String query,
    int limit = 80,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _firestore
        .collection('suppliers')
        .where('companyId', isEqualTo: cid)
        .limit(limit)
        .get();

    return _filterAndMap(
      docs: snap.docs,
      query: query,
      codeField: 'code',
      nameField: 'name',
    );
  }

  List<PartnerPick> _filterAndMap({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String query,
    required String codeField,
    required String nameField,
  }) {
    final q = query.trim().toLowerCase();
    final out = <PartnerPick>[];

    for (final doc in docs) {
      final data = doc.data();
      final code = (data[codeField] ?? '').toString().trim();
      final name = (data[nameField] ?? '').toString().trim();
      if (code.isEmpty && name.isEmpty) continue;

      final pick = PartnerPick(id: doc.id, code: code, name: name);

      if (q.isEmpty) {
        out.add(pick);
        continue;
      }

      final hay = '${code.toLowerCase()} ${name.toLowerCase()}';
      if (hay.contains(q)) {
        out.add(pick);
      }
    }

    out.sort((a, b) {
      final c = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return out;
  }
}
