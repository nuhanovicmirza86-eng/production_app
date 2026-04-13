import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_scrap_line.dart';

class ProductionOperatorTrackingService {
  ProductionOperatorTrackingService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('production_operator_tracking');

  /// Unosi za jedan dan i fazu (npr. samo `preparation`).
  Stream<List<ProductionOperatorTrackingEntry>> watchDayPhase({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const Stream.empty();
    }
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('phase', isEqualTo: phase)
        .where('workDate', isEqualTo: workDate)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ProductionOperatorTrackingEntry.fromDoc)
              .toList(),
        );
  }

  /// Jednokratno učitavanje (npr. za PDF) — isti filtri kao [watchDayPhase].
  Future<List<ProductionOperatorTrackingEntry>> fetchDayPhase({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const [];
    }
    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('phase', isEqualTo: phase)
        .where('workDate', isEqualTo: workDate)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(ProductionOperatorTrackingEntry.fromDoc).toList();
  }

  Future<void> createEntry({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
    required String itemCode,
    required String itemName,
    /// Pripremljeno / dobro (bez škarta).
    required double goodQty,
    required String unit,
    String? productId,
    String? productionOrderId,
    String? commercialOrderId,
    String? rawMaterialOrderCode,
    String? lineOrBatchRef,
    String? customerName,
    String? rawWorkOperatorName,
    String? preparedByDisplayName,
    String? sourceQrPayload,
    String? notes,
    List<TrackingScrapLine> scrapBreakdown = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Korisnik nije prijavljen.');
    }
    final email = user.email ?? '';
    final scrapSum = scrapBreakdown.fold<double>(
      0,
      (a, b) => a + b.qty,
    );
    final totalQty = goodQty + scrapSum;
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'phase': phase,
      'workDate': workDate.trim(),
      'itemCode': itemCode.trim(),
      'itemName': itemName.trim(),
      'quantity': totalQty,
      'unit': unit.trim().isEmpty ? 'kom' : unit.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user.uid,
      'createdByEmail': email,
    };
    if (productId != null && productId.trim().isNotEmpty) {
      payload['productId'] = productId.trim();
    }
    if (productionOrderId != null && productionOrderId.trim().isNotEmpty) {
      payload['productionOrderId'] = productionOrderId.trim();
    }
    if (commercialOrderId != null && commercialOrderId.trim().isNotEmpty) {
      payload['commercialOrderId'] = commercialOrderId.trim();
    }
    if (rawMaterialOrderCode != null && rawMaterialOrderCode.trim().isNotEmpty) {
      payload['rawMaterialOrderCode'] = rawMaterialOrderCode.trim();
    }
    if (lineOrBatchRef != null && lineOrBatchRef.trim().isNotEmpty) {
      payload['lineOrBatchRef'] = lineOrBatchRef.trim();
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      payload['customerName'] = customerName.trim();
    }
    if (rawWorkOperatorName != null && rawWorkOperatorName.trim().isNotEmpty) {
      payload['rawWorkOperatorName'] = rawWorkOperatorName.trim();
    }
    if (preparedByDisplayName != null && preparedByDisplayName.trim().isNotEmpty) {
      payload['preparedByDisplayName'] = preparedByDisplayName.trim();
    }
    if (sourceQrPayload != null && sourceQrPayload.trim().isNotEmpty) {
      payload['sourceQrPayload'] = sourceQrPayload.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    if (scrapBreakdown.isNotEmpty) {
      payload['scrapBreakdown'] =
          scrapBreakdown.map((e) => e.toMap()).toList();
    }
    await _col.add(payload);
  }
}
