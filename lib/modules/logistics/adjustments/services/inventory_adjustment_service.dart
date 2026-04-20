import 'package:cloud_functions/cloud_functions.dart';

class InventoryAdjustmentService {
  InventoryAdjustmentService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<void> applyLotAdjustment({
    required String companyId,
    required String lotDocId,
    required double newQuantityOnHand,
    required String reasonCode,
    required String reasonText,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Nedostaje companyId.');
    if (lotDocId.trim().isEmpty) throw Exception('Nedostaje lotDocId.');

    final res = await _functions
        .httpsCallable('applyInventoryLotAdjustment')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'lotDocId': lotDocId.trim(),
          'newQuantityOnHand': newQuantityOnHand,
          'reasonCode': reasonCode.trim(),
          'reasonText': reasonText.trim(),
        });

    if (res.data['success'] != true) {
      throw Exception('Korekcija nije potvrđena.');
    }
  }
}
