import 'package:cloud_functions/cloud_functions.dart';

/// Callable WMS (centralni magacin): prijem, kvaliteta, putaway, FIFO, otpremna zona.
class WarehouseWmsService {
  WarehouseWmsService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> createGoodsReceipt({
    required String companyId,
    required String warehouseId,
    required List<Map<String, dynamic>> lines,
    String plantKey = '',
    String notes = '',
    String supplierOrderRef = '',
  }) async {
    final res = await _functions
        .httpsCallable('createWarehouseGoodsReceipt')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'warehouseId': warehouseId,
          'lines': lines,
          'plantKey': plantKey,
          'notes': notes,
          'supplierOrderRef': supplierOrderRef,
        });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> resolveLotQuality({
    required String companyId,
    required String lotDocId,
    required String decision,
    String note = '',
  }) async {
    final res = await _functions
        .httpsCallable('resolveWmsLotQuality')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'lotDocId': lotDocId,
          'decision': decision,
          'note': note,
        });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> putawayLot({
    required String companyId,
    required String lotDocId,
    String storageAisle = '',
    String storageShelf = '',
    String storageBin = '',
    String containerLabel = '',
    bool moveToPickingStaging = false,
  }) async {
    final res = await _functions
        .httpsCallable('putawayWmsInventoryLot')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'lotDocId': lotDocId,
          'storageAisle': storageAisle,
          'storageShelf': storageShelf,
          'storageBin': storageBin,
          'containerLabel': containerLabel,
          'moveToPickingStaging': moveToPickingStaging,
        });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getFifoLotsForItem({
    required String companyId,
    required String warehouseId,
    required String itemId,
  }) async {
    final res = await _functions
        .httpsCallable('getWmsFifoLotsForItem')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'warehouseId': warehouseId,
          'itemId': itemId,
        });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> moveLotToShippingZone({
    required String companyId,
    required String lotDocId,
  }) async {
    final res = await _functions
        .httpsCallable('moveWmsLotToShippingZone')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'lotDocId': lotDocId,
        });
    return Map<String, dynamic>.from(res.data);
  }
}
