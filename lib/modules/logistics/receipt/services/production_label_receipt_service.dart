import 'package:cloud_functions/cloud_functions.dart';

import '../../../production/production_orders/models/production_order_model.dart';

/// Prijem outputa nakon skena etikete — zapis u `inventory_movements`
/// (LOGISTICS_SCHEMA: `production_output_pending`, `pending`) preko Callable.
class ProductionLabelReceiptService {
  ProductionLabelReceiptService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static double _parseQty(String qtyText) {
    final first = qtyText.trim().split(RegExp(r'\s+')).first;
    return double.tryParse(first.replaceAll(',', '.')) ?? 0;
  }

  /// Jedan pending movement prema odabranom magacinu (Callable + Admin write).
  /// Vraća [movementId] za `confirmInventoryMovement`.
  Future<String> createPendingMovementFromLabel({
    required String companyId,
    required String plantKey,
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

    final callable = _functions.httpsCallable(
      'createProductionOutputPendingMovement',
    );
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'toWarehouseId': toWarehouseId,
      'productionOrderId': order.id,
      'labelFields': labelFields,
      if (extraNote != null && extraNote.trim().isNotEmpty)
        'extraNote': extraNote.trim(),
    };

    final result = await callable.call<Map<String, dynamic>>(payload);
    final data = result.data;
    if (data['success'] != true) {
      throw Exception('Poziv nije uspio.');
    }
    final id = _s(data['movementId']);
    if (id.isEmpty) {
      throw Exception('Backend nije vratio movementId.');
    }
    return id;
  }
}
