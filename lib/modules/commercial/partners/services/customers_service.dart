import 'package:cloud_functions/cloud_functions.dart';

import '../models/customer_requirements_profile_model.dart';
import '../models/partner_models.dart';

class CustomersService {
  CustomersService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _customerPayloadForCallable(CustomerModel customer) {
    return Map<String, dynamic>.from(
      customer.toMapForWrite(includeIdFields: false),
    );
  }

  static Map<String, dynamic> _mapFromDynamic(dynamic raw) {
    if (raw is! Map) return {};
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<CustomerModel>> listCustomers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final res = await _functions
        .httpsCallable('listCommercialCustomers')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'limit': limit,
          if (query.trim().isNotEmpty) 'query': query.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Dohvat kupaca nije uspio.');
    }

    final out = <CustomerModel>[];
    for (final row in _listOfMaps(data['customers'])) {
      final id = _s(row['id']);
      if (id.isEmpty) continue;
      final m = CustomerModel.fromMap(id, row);
      if (m.companyId != cid) continue;
      out.add(m);
    }
    return out;
  }

  Future<CustomerModel?> getById({
    required String companyId,
    required String customerId,
  }) async {
    final cid = companyId.trim();
    final id = customerId.trim();
    if (cid.isEmpty || id.isEmpty) return null;

    final res = await _functions
        .httpsCallable('getCommercialCustomer')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'customerId': id,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Dohvat kupca nije uspio.');
    }
    final raw = data['customer'];
    if (raw == null) return null;
    final row = _mapFromDynamic(raw);
    final docId = _s(row['id']).isEmpty ? id : _s(row['id']);
    final model = CustomerModel.fromMap(docId, row);
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

    final res = await _functions
        .httpsCallable('getCustomerRequirementsProfile')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'customerId': id,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Dohvat CSR profila nije uspio.');
    }
    final raw = data['profile'];
    if (raw == null) return null;
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final profileId = _s(row['id']).isNotEmpty ? _s(row['id']) : id;
    final m = CustomerRequirementsProfileModel.fromMap(profileId, row);
    if (m.companyId != cid || m.customerId != id) return null;
    return m;
  }

  /// Jednokratno učitavanje preko Callable (nema Firestore listen nakon B4).
  Stream<CustomerRequirementsProfileModel?> watchCustomerRequirementsProfile({
    required String companyId,
    required String customerId,
  }) {
    return Stream.fromFuture(
      getCustomerRequirementsProfile(
        companyId: companyId,
        customerId: customerId,
      ),
    );
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
