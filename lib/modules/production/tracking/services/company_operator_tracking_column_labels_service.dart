import '../../../../core/company_operational_config_service.dart';
import '../config/operator_tracking_column_labels.dart';

/// Snimanje [operatorTrackingColumnLabelsKey] i [operatorTrackingColumnUiKey] preko Callabla
/// [updateCompanyOperationalConfig] — bez direktnog Firestore SDK write-a na root `companies`.
class CompanyOperatorTrackingColumnLabelsService {
  CompanyOperatorTrackingColumnLabelsService({
    CompanyOperationalConfigService? operationalConfig,
  }) : _ops = operationalConfig ?? CompanyOperationalConfigService();

  final CompanyOperationalConfigService _ops;

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
    await _ops.updateOperationalConfig(<String, dynamic>{
      'companyId': cid,
      'operatorTrackingColumnLabels': clean,
      'operatorTrackingColumnUi': <String, dynamic>{
        'showSystemHeaders': showSystemHeaders,
      },
    });
  }
}
