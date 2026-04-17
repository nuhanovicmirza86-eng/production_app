import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/operator_tracking_column_labels.dart';

/// Snimanje [operatorTrackingColumnLabelsKey] i [operatorTrackingColumnUiKey] na `companies/{id}`.
class CompanyOperatorTrackingColumnLabelsService {
  CompanyOperatorTrackingColumnLabelsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const Set<String> _allowedKeys = {
    OperatorTrackingColumnKeys.rowIndex,
    OperatorTrackingColumnKeys.prepDateTime,
    OperatorTrackingColumnKeys.lineOrBatchRef,
    OperatorTrackingColumnKeys.releaseToolOrRodRef,
    OperatorTrackingColumnKeys.itemCode,
    OperatorTrackingColumnKeys.itemName,
    OperatorTrackingColumnKeys.customerName,
    OperatorTrackingColumnKeys.goodQty,
    OperatorTrackingColumnKeys.scrapTotal,
    OperatorTrackingColumnKeys.rawMaterialOrder,
    OperatorTrackingColumnKeys.rawWorkOperator,
    OperatorTrackingColumnKeys.preparedBy,
    OperatorTrackingColumnKeys.quantityTotal,
    OperatorTrackingColumnKeys.unit,
    OperatorTrackingColumnKeys.productionOrderNumber,
    OperatorTrackingColumnKeys.commercialOrderNumber,
    OperatorTrackingColumnKeys.notes,
    OperatorTrackingColumnKeys.operatorEmail,
  };

  Future<void> save({
    required String companyId,
    required Map<String, String> labelsByKey,
    required bool showSystemHeaders,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return;
    final clean = <String, String>{};
    for (final e in labelsByKey.entries) {
      final k = e.key.trim();
      final v = e.value.trim();
      if (!_allowedKeys.contains(k) || v.isEmpty) continue;
      clean[k] = v;
    }
    await _db.collection('companies').doc(cid).update({
      operatorTrackingColumnLabelsKey: clean,
      operatorTrackingColumnUiKey: {
        'showSystemHeaders': showSystemHeaders,
      },
    });
  }
}
