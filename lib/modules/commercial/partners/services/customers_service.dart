import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/partner_models.dart';

class CustomersService {
  CustomersService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');
  CollectionReference<Map<String, dynamic>> get _customerCounters =>
      _firestore.collection('customer_counters');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Future<String> _nextCustomerCode({
    required String companyId,
    required String generatedBy,
  }) async {
    final year = DateTime.now().year.toString();
    final yy = year.substring(year.length - 2);
    final counterId = '${companyId}_$year';
    final ref = _customerCounters.doc(counterId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.data() ?? <String, dynamic>{};
      final current = (existing['lastNumber'] as num?)?.toInt() ?? 0;
      final next = current + 1;

      tx.set(ref, {
        'id': counterId,
        'companyId': companyId,
        'year': year,
        'lastNumber': next,
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdBy': generatedBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': generatedBy,
      }, SetOptions(merge: true));

      return 'CUS-$yy-${next.toString().padLeft(4, '0')}';
    });
  }

  Future<List<CustomerModel>> listCustomers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap =
        await _customers.where('companyId', isEqualTo: cid).limit(limit).get();

    final q = query.trim().toLowerCase();
    final out = <CustomerModel>[];

    for (final doc in snap.docs) {
      final d = doc.data();
      final m = CustomerModel.fromMap(doc.id, d);
      if (m.companyId != cid) continue;

      if (q.isNotEmpty) {
        final hay = '${m.code.toLowerCase()} ${m.name.toLowerCase()} '
            '${m.legalName.toLowerCase()}';
        if (!hay.contains(q)) continue;
      }

      out.add(m);
    }

    out.sort((a, b) {
      final c = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return out;
  }

  Future<CustomerModel?> getById({
    required String companyId,
    required String customerId,
  }) async {
    final cid = companyId.trim();
    final id = customerId.trim();
    if (cid.isEmpty || id.isEmpty) return null;

    final doc = await _customers.doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final model = CustomerModel.fromMap(doc.id, data);
    if (model.companyId != cid) return null;
    return model;
  }

  Future<String> createCustomer({
    required Map<String, dynamic> companyData,
    required CustomerModel draft,
  }) async {
    final companyId = _s(companyData['companyId']);
    final userId = _s(companyData['userId']).isEmpty ? 'system' : _s(companyData['userId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');

    final docRef = _customers.doc();
    final code = draft.code.trim().isEmpty
        ? await _nextCustomerCode(companyId: companyId, generatedBy: userId)
        : draft.code.trim().toUpperCase();

    final model = CustomerModel(
      id: docRef.id,
      companyId: companyId,
      code: code,
      name: draft.name.trim(),
      legalName: draft.legalName.trim(),
      status: draft.status.trim(),
      customerType: draft.customerType.trim(),
      country: draft.country,
      city: draft.city,
      address: draft.address,
      taxId: draft.taxId,
      notes: draft.notes,
    );

    await docRef.set({
      ...model.toMapForWrite(includeIdFields: true),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });

    return docRef.id;
  }

  Future<void> updateCustomer({
    required Map<String, dynamic> companyData,
    required CustomerModel customer,
  }) async {
    final companyId = _s(companyData['companyId']);
    final userId = _s(companyData['userId']).isEmpty ? 'system' : _s(companyData['userId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');
    if (customer.id.trim().isEmpty) throw Exception('Missing customerId');

    await _customers.doc(customer.id).update({
      ...customer.toMapForWrite(includeIdFields: false),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });
  }
}

