import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/customer_requirements_profile_model.dart';
import '../models/partner_models.dart';

class CustomersService {
  CustomersService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');

  CollectionReference<Map<String, dynamic>> get _csrProfiles =>
      _firestore.collection('customer_requirements_profiles');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _customerPayloadForCallable(CustomerModel customer) {
    return Map<String, dynamic>.from(
      customer.toMapForWrite(includeIdFields: false),
    );
  }

  Future<List<CustomerModel>> listCustomers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _customers
        .where('companyId', isEqualTo: cid)
        .limit(limit)
        .get();

    final q = query.trim().toLowerCase();
    final out = <CustomerModel>[];

    for (final doc in snap.docs) {
      final d = doc.data();
      final m = CustomerModel.fromMap(doc.id, d);
      if (m.companyId != cid) continue;

      if (q.isNotEmpty) {
        final hay =
            '${m.code.toLowerCase()} ${m.name.toLowerCase()} '
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
    if (companyId.isEmpty) throw Exception('Missing companyId');

    final payload = CustomerModel(
      id: '',
      companyId: companyId,
      code: draft.code.trim().isEmpty ? '' : draft.code.trim().toUpperCase(),
      name: draft.name.trim(),
      legalName: draft.legalName.trim(),
      status: draft.status.trim(),
      customerType: draft.customerType.trim(),
      country: draft.country,
      countryCode: draft.countryCode,
      city: draft.city,
      address: draft.address,
      taxId: draft.taxId,
      notes: draft.notes,
      contractDeliveryDays: draft.contractDeliveryDays,
      contractPaymentDays: draft.contractPaymentDays,
      contractCollectionDays: draft.contractCollectionDays,
      contractGraceDaysLate: draft.contractGraceDaysLate,
      activitySector: draft.activitySector,
      partnerRatingClass: draft.partnerRatingClass,
      isStrategic: draft.isStrategic,
    );

    final res = await _functions
        .httpsCallable('createCommercialCustomer')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'customer': _customerPayloadForCallable(payload),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Kreiranje kupca nije uspjelo.');
    }
    final id = _s(data['customerId']);
    if (id.isEmpty) throw Exception('Kreiranje kupca: prazan odgovor.');
    return id;
  }

  Future<void> updateCustomer({
    required Map<String, dynamic> companyData,
    required CustomerModel customer,
  }) async {
    final companyId = _s(companyData['companyId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');
    if (customer.id.trim().isEmpty) throw Exception('Missing customerId');

    final res = await _functions
        .httpsCallable('updateCommercialCustomer')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'customerId': customer.id.trim(),
          'customer': _customerPayloadForCallable(customer),
        });
    if (res.data['success'] != true) {
      throw Exception('Ažuriranje kupca nije uspjelo.');
    }
  }

  Future<CustomerRequirementsProfileModel?> getCustomerRequirementsProfile({
    required String companyId,
    required String customerId,
  }) async {
    final cid = companyId.trim();
    final id = customerId.trim();
    if (cid.isEmpty || id.isEmpty) return null;
    final doc = await _csrProfiles.doc(id).get();
    if (!doc.exists) return null;
    final m = CustomerRequirementsProfileModel.fromDoc(doc);
    if (m.companyId != cid) return null;
    return m;
  }

  /// Firestore snapshot profila zahtjeva kupca (isti id kao `customers` dokument).
  Stream<CustomerRequirementsProfileModel?> watchCustomerRequirementsProfile({
    required String companyId,
    required String customerId,
  }) {
    final cid = companyId.trim();
    final id = customerId.trim();
    if (cid.isEmpty || id.isEmpty) {
      return Stream.value(null);
    }
    return _csrProfiles.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final m = CustomerRequirementsProfileModel.fromDoc(doc);
      if (m.companyId != cid) return null;
      return m;
    });
  }

  Future<void> upsertCustomerRequirementsProfile({
    required String companyId,
    required String customerId,
    required CustomerRequirementsProfileModel profile,
  }) async {
    final cid = companyId.trim();
    final id = customerId.trim();
    if (cid.isEmpty || id.isEmpty) throw Exception('Missing ids');
    final res = await _functions
        .httpsCallable('upsertCustomerRequirementsProfile')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'customerId': id,
          'profile': profile.toCallablePatch(),
        });
    if (res.data['ok'] != true) {
      throw Exception('Snimanje CSR profila nije uspjelo.');
    }
  }
}
