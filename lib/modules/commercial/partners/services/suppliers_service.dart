import 'package:cloud_functions/cloud_functions.dart';

import '../models/partner_models.dart';

class SuppliersService {
  SuppliersService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

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

  Future<List<SupplierModel>> listSuppliers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final res = await _functions
        .httpsCallable('listCommercialSuppliers')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'limit': limit,
          if (query.trim().isNotEmpty) 'query': query.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Dohvat dobavljača nije uspio.');
    }

    final out = <SupplierModel>[];
    for (final row in _listOfMaps(data['suppliers'])) {
      final id = _s(row['id']);
      if (id.isEmpty) continue;
      final m = SupplierModel.fromMap(id, row);
      if (m.companyId != cid) continue;
      out.add(m);
    }
    return out;
  }

  Future<SupplierModel?> getById({
    required String companyId,
    required String supplierId,
  }) async {
    final cid = companyId.trim();
    final id = supplierId.trim();
    if (cid.isEmpty || id.isEmpty) return null;

    final res = await _functions
        .httpsCallable('getCommercialSupplier')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'supplierId': id,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Dohvat dobavljača nije uspio.');
    }
    final raw = data['supplier'];
    if (raw == null) return null;
    final row = _mapFromDynamic(raw);
    final docId = _s(row['id']).isEmpty ? id : _s(row['id']);
    final model = SupplierModel.fromMap(docId, row);
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
