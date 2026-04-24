import '../../logistics/receipt/logistics_receipt_qr_payload.dart';
import '../../workforce/employee_profiles/workforce_qr_payload.dart';
import '../packing/packing_box_qr.dart';
import '../production_orders/printing/classification_label_print_qr.dart';
import '../production_orders/printing/production_order_qr_payload.dart';

/// Namjena skeniranog QR-a u aplikaciji (proizvodnja + logistika).
///
/// Arhitektura (izvor istine): `maintenance_app/docs/architecture/PRODUCTION_QR_AND_SCANNING_ARCHITECTURE.md`
///
/// Registrirani formati → [resolveProductionQrScan]:
/// - `workforceEmployee:v1;…` → [ProductionQrIntent.workforceEmployeeV1]
/// - `po:v1;` / `pol:v1;` → [ProductionQrIntent.productionOrderReferenceV1]
/// - `wmslot:v1;` / `lot:v1;` → [ProductionQrIntent.wmsLotDocV1] (isti payload)
/// - `rcpt:v1;` → [ProductionQrIntent.logisticsReceiptDocV1] (`logistics_receipts`)
/// - JSON `type: production_classification_label` → [ProductionQrIntent.printedClassificationLabelV1]
/// - JSON `type: packing_box_station1` → [ProductionQrIntent.packedStation1BoxV1]
///
/// Planirano (nije u resolveru): npr. `ship:v1` (otprema) kad bude definiran.
///
/// Sigurnost: sken sam po sebi ne smije zaobići Firestore pravila; ekrani
/// i dalje provjeravaju ulogu i `companyId` / `plantKey`.
enum ProductionQrIntent {
  /// Bedž radnika ([tryParseWorkforceEmployeeQr]).
  workforceEmployeeV1,

  /// Referenca na proizvodni nalog (`po:v1;…` ili `pol:v1;…`).
  productionOrderReferenceV1,

  /// Otisnuta etiketa klasifikacije (`type`: production_classification_label).
  printedClassificationLabelV1,

  /// Zatvorena kutija Stanica 1 (`type`: packing_box_station1).
  packedStation1BoxV1,

  /// Inventurni lot u WMS-u: `wmslot:v1;…` ili alias `lot:v1;…` (id dokumenta `inventory_lots`).
  wmsLotDocV1,

  /// Prijem robe (GR): `rcpt:v1;…` — id dokumenta u `logistics_receipts`.
  logisticsReceiptDocV1,

  nepoznat,
}

/// Rezultat parsiranja — koristi navigacija / logistički ekrani.
class ProductionQrScanResolution {
  ProductionQrScanResolution({
    required this.intent,
    required this.rawPayload,
    this.productionOrderId,
    this.productionOrderCode,
    this.labelFields,
    this.packingBoxId,
    this.wmsLotDocId,
    this.logisticsReceiptDocId,
    this.workforceEmployee,
  });

  final ProductionQrIntent intent;
  final String rawPayload;

  /// Kad je [intent] [ProductionQrIntent.workforceEmployeeV1].
  final ParsedWorkforceEmployeeQr? workforceEmployee;

  /// Iz `po:v1` / `pol:v1` (Firestore id dokumenta naloga).
  final String? productionOrderId;

  /// Iz `po:v1` / `pol:v1` ili etikete (`pn`).
  final String? productionOrderCode;

  /// Kad je [intent] [ProductionQrIntent.printedClassificationLabelV1].
  final Map<String, dynamic>? labelFields;

  /// Kad je [intent] [ProductionQrIntent.packedStation1BoxV1] — `packing_boxes` id.
  final String? packingBoxId;

  /// Kad je [intent] [ProductionQrIntent.wmsLotDocV1] — `inventory_lots` id.
  final String? wmsLotDocId;

  /// Kad je [intent] [ProductionQrIntent.logisticsReceiptDocV1] — `logistics_receipts` id.
  final String? logisticsReceiptDocId;

  bool get isKnown => intent != ProductionQrIntent.nepoznat;
}

/// Jedna ulazna tačka za skener: prepoznaje sve registrirane formate.
ProductionQrScanResolution resolveProductionQrScan(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.nepoznat,
      rawPayload: raw,
    );
  }

  final wf = tryParseWorkforceEmployeeQr(trimmed);
  if (wf != null) {
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.workforceEmployeeV1,
      rawPayload: trimmed,
      workforceEmployee: wf,
    );
  }

  if (trimmed.startsWith('po:v1;') || trimmed.startsWith('pol:v1;')) {
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.productionOrderReferenceV1,
      rawPayload: trimmed,
      productionOrderId: tryParseProductionOrderIdFromQr(trimmed),
      productionOrderCode: tryParseProductionOrderCodeFromQr(trimmed),
    );
  }

  if (trimmed.startsWith('wmslot:v1;') || trimmed.startsWith('lot:v1;')) {
    final prefix = trimmed.startsWith('wmslot:v1;') ? 'wmslot:v1;' : 'lot:v1;';
    var rest = trimmed.substring(prefix.length).trim();
    if (rest.startsWith('docId=')) {
      rest = rest.substring('docId='.length).trim();
    }
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.wmsLotDocV1,
      rawPayload: trimmed,
      wmsLotDocId: rest.isEmpty ? null : rest,
    );
  }

  if (trimmed.startsWith('rcpt:v1;')) {
    final rid = tryParseLogisticsReceiptDocIdFromQr(trimmed);
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.logisticsReceiptDocV1,
      rawPayload: trimmed,
      logisticsReceiptDocId: rid,
    );
  }

  final boxMap = tryParsePackingBoxQr(trimmed);
  if (boxMap != null && isPackingBoxStation1Map(boxMap)) {
    final bid = (boxMap['boxId'] ?? '').toString().trim();
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.packedStation1BoxV1,
      rawPayload: trimmed,
      packingBoxId: bid.isEmpty ? null : bid,
    );
  }

  final label = tryParseClassificationLabelPrintQr(trimmed);
  if (label != null &&
      (label['type']?.toString() == 'production_classification_label')) {
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.printedClassificationLabelV1,
      rawPayload: trimmed,
      productionOrderCode: label['pn']?.toString(),
      labelFields: label,
    );
  }

  return ProductionQrScanResolution(
    intent: ProductionQrIntent.nepoznat,
    rawPayload: trimmed,
  );
}
