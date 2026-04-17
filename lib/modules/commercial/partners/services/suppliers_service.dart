import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/partner_models.dart';

class SuppliersService {
  SuppliersService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firestore.collection('suppliers');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Datumi za Callable (ISO string).
  Map<String, dynamic> _supplierPayloadForCallable(SupplierModel supplier) {
    final m = Map<String, dynamic>.from(
      supplier.toMapForWrite(includeIdFields: false),
    );
    for (final k in ['approvalDate', 'lastEvaluationDate', 'nextAuditDate']) {
      final v = m[k];
      if (v is DateTime) {
        m[k] = v.toUtc().toIso8601String();
      }
    }
    return m;
  }

  Future<List<SupplierModel>> listSuppliers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _suppliers
        .where('companyId', isEqualTo: cid)
        .limit(limit)
        .get();

    final q = query.trim().toLowerCase();
    final out = <SupplierModel>[];

    for (final doc in snap.docs) {
      final d = doc.data();
      final m = SupplierModel.fromMap(doc.id, d);
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

  Future<SupplierModel?> getById({
    required String companyId,
    required String supplierId,
  }) async {
    final cid = companyId.trim();
    final id = supplierId.trim();
    if (cid.isEmpty || id.isEmpty) return null;

    final doc = await _suppliers.doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final model = SupplierModel.fromMap(doc.id, data);
    if (model.companyId != cid) return null;
    return model;
  }

  Future<String> createSupplier({
    required Map<String, dynamic> companyData,
    required SupplierModel draft,
  }) async {
    final companyId = _s(companyData['companyId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');

    final payload = SupplierModel(
      id: '',
      companyId: companyId,
      code: draft.code.trim().isEmpty ? '' : draft.code.trim().toUpperCase(),
      name: draft.name.trim(),
      legalName: draft.legalName.trim(),
      status: draft.status.trim(),
      supplierType: draft.supplierType.trim(),
      country: draft.country,
      city: draft.city,
      address: draft.address,
      taxId: draft.taxId,
      notes: draft.notes,
      leadTimeDays: draft.leadTimeDays,
      supplierCategory: draft.supplierCategory,
      isStrategic: draft.isStrategic,
      approvalStatus: draft.approvalStatus,
      approvalDate: draft.approvalDate,
      riskLevel: draft.riskLevel,
      nonconformanceCount: draft.nonconformanceCount,
      claimCount: draft.claimCount,
      lastEvaluationDate: draft.lastEvaluationDate,
      nextAuditDate: draft.nextAuditDate,
      qualityRating: draft.qualityRating,
      deliveryRating: draft.deliveryRating,
      responseRating: draft.responseRating,
      overallScore: draft.overallScore,
      approvedMaterialGroups: draft.approvedMaterialGroups,
      approvedProcesses: draft.approvedProcesses,
      certificates: draft.certificates,
      contractDeliveryDays: draft.contractDeliveryDays,
      contractPaymentDays: draft.contractPaymentDays,
      contractCollectionDays: draft.contractCollectionDays,
      contractGraceDaysLate: draft.contractGraceDaysLate,
      activitySector: draft.activitySector,
      partnerRatingClass: draft.partnerRatingClass,
    );

    final res = await _functions
        .httpsCallable('createCommercialSupplier')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'supplier': _supplierPayloadForCallable(payload),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Kreiranje dobavljača nije uspjelo.');
    }
    final id = _s(data['supplierId']);
    if (id.isEmpty) throw Exception('Kreiranje dobavljača: prazan odgovor.');
    return id;
  }

  Future<void> updateSupplier({
    required Map<String, dynamic> companyData,
    required SupplierModel supplier,
    String? changeReason,
  }) async {
    final companyId = _s(companyData['companyId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');
    if (supplier.id.trim().isEmpty) throw Exception('Missing supplierId');

    final res = await _functions
        .httpsCallable('updateCommercialSupplier')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'supplierId': supplier.id.trim(),
          'changeReason': changeReason,
          'supplier': _supplierPayloadForCallable(supplier),
        });
    if (res.data['success'] != true) {
      throw Exception('Ažuriranje dobavljača nije uspjelo.');
    }
  }

  /// Poziva Cloud Function [refreshSupplierOperationalSignals] (narudžbe → auto-skor).
  Future<void> refreshOperationalSignals({
    required String companyId,
    String? supplierId,
    bool allSuppliers = false,
    int limit = 25,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Missing companyId');
    if ((supplierId == null || supplierId.trim().isEmpty) && !allSuppliers) {
      throw Exception('supplierId ili allSuppliers je obavezno.');
    }
    final payload = <String, dynamic>{
      'companyId': cid,
      'limit': limit,
      if (supplierId != null && supplierId.trim().isNotEmpty)
        'supplierId': supplierId.trim(),
      if (allSuppliers) 'allSuppliers': true,
    };
    final res = await _functions
        .httpsCallable('refreshSupplierOperationalSignals')
        .call<Map<String, dynamic>>(payload);
    if (res.data['success'] != true) {
      throw Exception(
        'Osvježavanje operativnog skora dobavljača nije uspjelo.',
      );
    }
  }
}
