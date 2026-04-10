import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/partner_models.dart';

class SuppliersService {
  SuppliersService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firestore.collection('suppliers');
  CollectionReference<Map<String, dynamic>> get _supplierCounters =>
      _firestore.collection('supplier_counters');
  CollectionReference<Map<String, dynamic>> get _supplierStatusHistory =>
      _firestore.collection('supplier_status_history');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Future<String> _nextSupplierCode({
    required String companyId,
    required String generatedBy,
  }) async {
    final year = DateTime.now().year.toString();
    final yy = year.substring(year.length - 2);
    final counterId = '${companyId}_$year';
    final ref = _supplierCounters.doc(counterId);

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

      return 'SUP-$yy-${next.toString().padLeft(4, '0')}';
    });
  }

  Future<List<SupplierModel>> listSuppliers({
    required String companyId,
    int limit = 500,
    String query = '',
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap =
        await _suppliers.where('companyId', isEqualTo: cid).limit(limit).get();

    final q = query.trim().toLowerCase();
    final out = <SupplierModel>[];

    for (final doc in snap.docs) {
      final d = doc.data();
      final m = SupplierModel.fromMap(doc.id, d);
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
    final userId = _s(companyData['userId']).isEmpty ? 'system' : _s(companyData['userId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');

    final docRef = _suppliers.doc();
    final code = draft.code.trim().isEmpty
        ? await _nextSupplierCode(companyId: companyId, generatedBy: userId)
        : draft.code.trim().toUpperCase();

    final model = SupplierModel(
      id: docRef.id,
      companyId: companyId,
      code: code,
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

  Future<void> updateSupplier({
    required Map<String, dynamic> companyData,
    required SupplierModel supplier,
    String? changeReason,
  }) async {
    final companyId = _s(companyData['companyId']);
    final userId = _s(companyData['userId']).isEmpty ? 'system' : _s(companyData['userId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');
    if (supplier.id.trim().isEmpty) throw Exception('Missing supplierId');

    final supplierRef = _suppliers.doc(supplier.id);
    await _firestore.runTransaction((tx) async {
      final currentSnap = await tx.get(supplierRef);
      final current = currentSnap.data() ?? <String, dynamic>{};

      final oldApprovalStatus = _s(current['approvalStatus']);
      final oldRiskLevel = _s(current['riskLevel']);
      final oldSupplierCategory = _s(current['supplierCategory']);
      final oldIsStrategic = (current['isStrategic'] == true);

      final hasCriticalChange =
          oldApprovalStatus != supplier.approvalStatus ||
          oldRiskLevel != supplier.riskLevel ||
          oldSupplierCategory != supplier.supplierCategory ||
          oldIsStrategic != supplier.isStrategic;

      final reason = (changeReason ?? '').trim();
      if (hasCriticalChange && reason.isEmpty) {
        throw Exception(
          'Razlog promjene je obavezan za approval/risk/strategic izmjene.',
        );
      }

      tx.update(supplierRef, {
        ...supplier.toMapForWrite(includeIdFields: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });

      if (hasCriticalChange) {
        final histRef = _supplierStatusHistory.doc();
        tx.set(histRef, {
          'id': histRef.id,
          'companyId': companyId,
          'supplierId': supplier.id,
          'supplierCode': supplier.code,
          'eventType': 'critical_status_change',
          'changeReason': reason,
          'changedFields': <String>[
            if (oldApprovalStatus != supplier.approvalStatus) 'approvalStatus',
            if (oldRiskLevel != supplier.riskLevel) 'riskLevel',
            if (oldSupplierCategory != supplier.supplierCategory) 'supplierCategory',
            if (oldIsStrategic != supplier.isStrategic) 'isStrategic',
          ],
          'before': {
            'approvalStatus': oldApprovalStatus,
            'riskLevel': oldRiskLevel,
            'supplierCategory': oldSupplierCategory,
            'isStrategic': oldIsStrategic,
          },
          'after': {
            'approvalStatus': supplier.approvalStatus,
            'riskLevel': supplier.riskLevel,
            'supplierCategory': supplier.supplierCategory,
            'isStrategic': supplier.isStrategic,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
        });
      }
    });
  }
}

