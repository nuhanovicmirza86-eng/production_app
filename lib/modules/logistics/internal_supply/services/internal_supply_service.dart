import 'package:cloud_functions/cloud_functions.dart';

/// Callable-i za interne narudžbe hub → pogon (`internal_supply_order_writes.js`).
class InternalSupplyService {
  InternalSupplyService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> submitInternalSupplyOrder({
    required String companyId,
    required String supplyingWarehouseId,
    required String requestingWarehouseId,
    String plantKey = '',
    String notes = '',
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await _functions
        .httpsCallable('submitInternalSupplyOrder')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'supplyingWarehouseId': supplyingWarehouseId.trim(),
          'requestingWarehouseId': requestingWarehouseId.trim(),
          'plantKey': plantKey.trim(),
          'notes': notes.trim(),
          'lines': lines,
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> getInternalSupplyLinePickGuidance({
    required String companyId,
    required String orderId,
    required String lineId,
    String hubWarehouseId = '',
  }) async {
    final res = await _functions
        .httpsCallable('getInternalSupplyLinePickGuidance')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
          'lineId': lineId.trim(),
          if (hubWarehouseId.trim().isNotEmpty)
            'hubWarehouseId': hubWarehouseId.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> hubConfirmPickForLine({
    required String companyId,
    required String orderId,
    required String lineId,
    required String pickedLotDocId,
    String pickedLotId = '',
    double? pickedQty,
    String fifoOverrideReason = '',
  }) async {
    final res = await _functions
        .httpsCallable('hubConfirmPickForLine')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
          'lineId': lineId.trim(),
          'pickedLotDocId': pickedLotDocId.trim(),
          'pickedLotId': pickedLotId.trim(),
          ...?pickedQty != null ? {'pickedQty': pickedQty} : null,
          'fifoOverrideReason': fifoOverrideReason.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> hubMarkOrderReadyToShip({
    required String companyId,
    required String orderId,
  }) async {
    final res = await _functions
        .httpsCallable('hubMarkOrderReadyToShip')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> hubShipInternalSupplyOrder({
    required String companyId,
    required String orderId,
  }) async {
    final res = await _functions
        .httpsCallable('hubShipInternalSupplyOrder')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> destReceiveInternalSupplyLine({
    required String companyId,
    required String orderId,
    required String lineId,
    String movementId = '',
  }) async {
    final res = await _functions
        .httpsCallable('destReceiveInternalSupplyLine')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
          'lineId': lineId.trim(),
          if (movementId.trim().isNotEmpty) 'movementId': movementId.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }

  Future<Map<String, dynamic>> destCompleteInternalSupplyOrder({
    required String companyId,
    required String orderId,
    String completionNote = '',
  }) async {
    final res = await _functions
        .httpsCallable('destCompleteInternalSupplyOrder')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'orderId': orderId.trim(),
          'completionNote': completionNote.trim(),
        });
    return Map<String, dynamic>.from(res.data as Map? ?? {});
  }
}
