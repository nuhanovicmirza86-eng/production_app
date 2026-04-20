import '../packing/packing_box_qr.dart';
import '../production_orders/printing/classification_label_print_qr.dart';
import '../production_orders/printing/production_order_qr_payload.dart';

/// Namjena skeniranog QR-a u aplikaciji (proizvodnja + logistika).
///
/// Arhitektura (izvor istine): `maintenance_app/docs/architecture/PRODUCTION_QR_AND_SCANNING_ARCHITECTURE.md`
///
/// Svaki generator QR-a u toku (nalog, etiketa, lot, prenos…) treba imati
/// vlastiti format payloada; [resolveProductionQrScan] ga mapira na jedan [ProductionQrIntent].
///
/// Plan navigacije (implementacija kasnije):
/// | Intent | Tipičan izvor | Ciljni ekran / tok |
/// |--------|----------------|---------------------|
/// | [ProductionQrIntent.productionOrderReferenceV1] | `po:v1;…` na nalogu / A4 | Detalji PN → evidencija / [ProductionExecutionScreen] |
/// | [ProductionQrIntent.printedClassificationLabelV1] | JSON etiketa | Prijem sa liste, zaliha po magacinu, prenos (logistika) |
/// | [ProductionQrIntent.unknown] | nepoznat string | Ručni unos ili poruka |
///
/// Buduće (dodati ovdje i u [resolveProductionQrScan]):
/// - `wmslot:v1;<lotDocId>` → Firestore id dokumenta u `inventory_lots` (WMS sken).
/// - `lot:v1` → detalj lota, FIFO, prenos između magacina
/// - `mv:v1` / `rcpt:v1` → potvrda prijema / otpreme
///
/// Sigurnost: sken sam po sebi ne smije zaobići Firestore pravila; ekrani
/// i dalje provjeravaju ulogu i `companyId` / `plantKey`.
enum ProductionQrIntent {
  /// Referenca na proizvodni nalog (`po:v1;…`).
  productionOrderReferenceV1,

  /// Otisnuta etiketa klasifikacije (`type`: production_classification_label).
  printedClassificationLabelV1,

  /// Zatvorena kutija Stanica 1 (`type`: packing_box_station1).
  packedStation1BoxV1,

  /// WMS lot: `wmslot:v1;<inventory_lots doc id>`.
  wmsLotDocV1,

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
  });

  final ProductionQrIntent intent;
  final String rawPayload;

  /// Iz `po:v1` (Firestore id dokumenta naloga).
  final String? productionOrderId;

  /// Iz `po:v1` ili etikete (`pn`).
  final String? productionOrderCode;

  /// Kad je [intent] [ProductionQrIntent.printedClassificationLabelV1].
  final Map<String, dynamic>? labelFields;

  /// Kad je [intent] [ProductionQrIntent.packedStation1BoxV1] — `packing_boxes` id.
  final String? packingBoxId;

  /// Kad je [intent] [ProductionQrIntent.wmsLotDocV1] — `inventory_lots` id.
  final String? wmsLotDocId;

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

  if (trimmed.startsWith('po:v1;')) {
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.productionOrderReferenceV1,
      rawPayload: trimmed,
      productionOrderId: tryParseProductionOrderIdFromQr(trimmed),
      productionOrderCode: tryParseProductionOrderCodeFromQr(trimmed),
    );
  }

  if (trimmed.startsWith('wmslot:v1;')) {
    var rest = trimmed.substring('wmslot:v1;'.length).trim();
    if (rest.startsWith('docId=')) {
      rest = rest.substring('docId='.length).trim();
    }
    return ProductionQrScanResolution(
      intent: ProductionQrIntent.wmsLotDocV1,
      rawPayload: trimmed,
      wmsLotDocId: rest.isEmpty ? null : rest,
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
