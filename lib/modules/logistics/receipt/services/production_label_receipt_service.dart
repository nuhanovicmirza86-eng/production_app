import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../production/production_orders/models/production_order_model.dart';

/// Prijem outputa nakon skena etikete — zapis u `inventory_movements`
/// (LOGISTICS_SCHEMA: `production_output_pending`, `pending`).
class ProductionLabelReceiptService {
  ProductionLabelReceiptService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _movements =>
      _firestore.collection('inventory_movements');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static double _parseQty(String qtyText) {
    final first = qtyText.trim().split(RegExp(r'\s+')).first;
    return double.tryParse(first.replaceAll(',', '.')) ?? 0;
  }

  static String _unitFromQtyTextOrFallback(String qtyText, String orderUnit) {
    final parts = qtyText.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.sublist(1).join(' ').trim();
    }
    return orderUnit.trim();
  }

  static String _itemTypeFromCls(String? cls) {
    switch (cls?.toUpperCase()) {
      case 'SECONDARY':
        return 'semi_finished';
      case 'TRANSPORT':
        return 'finished_good';
      default:
        return 'finished_good';
    }
  }

  /// Jedan pending movement prema odabranom magacinu.
  Future<void> createPendingMovementFromLabel({
    required String companyId,
    required String plantKey,
    required String userId,
    required String toWarehouseId,
    required ProductionOrderModel order,
    required Map<String, dynamic> labelFields,
    String? extraNote,
  }) async {
    final qtyText = _s(labelFields['qty']);
    final qty = _parseQty(qtyText);
    if (qty <= 0) {
      throw Exception('Količina na etiketi nije valjana.');
    }

    final unit = _unitFromQtyTextOrFallback(qtyText, order.unit);
    final cls = _s(labelFields['cls']);
    final docRef = _movements.doc();
    final baseNote =
        'Sken etikete (klasifikacija: ${cls.isEmpty ? '—' : cls})';
    final noteExtra = _s(extraNote);
    final notes = noteExtra.isEmpty ? baseNote : '$baseNote — $noteExtra';

    await docRef.set({
      'companyId': companyId,
      'plantKey': plantKey,
      'movementCode': null,
      'movementType': 'production_output_pending',
      'status': 'pending',
      'itemId': order.productId,
      'itemCode': order.productCode,
      'itemName': order.productName,
      'itemType': _itemTypeFromCls(cls.isEmpty ? null : cls),
      'lotId': docRef.id,
      'batchNumber': _s(labelFields['pn']),
      'quantity': qty,
      'unit': unit,
      'fromWarehouseId': null,
      'toWarehouseId': toWarehouseId,
      'referenceType': 'production_order',
      'referenceId': order.id,
      'notes': notes,
      'labelScanSnapshot': labelFields,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });
  }
}
