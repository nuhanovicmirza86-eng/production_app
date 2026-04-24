import 'package:flutter/material.dart';

import '../../production/products/services/product_lookup_service.dart';
import '../../production/qr/production_qr_resolver.dart';
import '../../production/qr/screens/production_qr_scan_screen.dart';

/// Bilo koji sadržaj QR-a (šarža, interni kod, …).
Future<String?> wmsScanBarcodeRaw(
  BuildContext context, {
  required Map<String, dynamic> companyData,
}) async {
  final res = await Navigator.push<ProductionQrScanResolution>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProductionQrScanScreen(companyData: companyData),
    ),
  );
  final raw = res?.rawPayload.trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

/// Otvara [ProductionQrScanScreen] i vraća **Firestore id** lota (`inventory_lots`).
///
/// Podržano: `wmslot:v1;<docId>` ili sirovi string (npr. samo id ako je tako otisnuto).
Future<String?> wmsScanLotDocId(
  BuildContext context, {
  required Map<String, dynamic> companyData,
}) async {
  final res = await Navigator.push<ProductionQrScanResolution>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProductionQrScanScreen(companyData: companyData),
    ),
  );
  if (res == null) return null;
  final fromPrefix = res.wmsLotDocId?.trim();
  if (fromPrefix != null && fromPrefix.isNotEmpty) return fromPrefix;
  final raw = res.rawPayload.trim();
  if (raw.isEmpty) return null;
  return raw;
}

/// Sken artikla za prijem / WMS — vraća zapis iz šifarnika ili `null` ako kod nije prepoznat.
Future<ProductLookupItem?> wmsScanResolvedProduct(
  BuildContext context, {
  required Map<String, dynamic> companyData,
}) async {
  final res = await Navigator.push<ProductionQrScanResolution>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProductionQrScanScreen(companyData: companyData),
    ),
  );
  if (res == null) return null;
  if (res.intent == ProductionQrIntent.wmsLotDocV1) {
    return null;
  }
  if (res.intent == ProductionQrIntent.workforceEmployeeV1 ||
      res.intent == ProductionQrIntent.productionOrderReferenceV1 ||
      res.intent == ProductionQrIntent.packedStation1BoxV1 ||
      res.intent == ProductionQrIntent.logisticsReceiptDocV1) {
    return null;
  }

  final cid = (companyData['companyId'] ?? '').toString().trim();
  if (cid.isEmpty) return null;

  if (res.intent == ProductionQrIntent.printedClassificationLabelV1) {
    final m = res.labelFields;
    final pid = (m?['productId'] ?? m?['product_id'] ?? '').toString().trim();
    if (pid.isNotEmpty) {
      return ProductLookupService().getByProductId(
        companyId: cid,
        productId: pid,
        onlyActive: true,
      );
    }
    final pcode = (m?['pcode'] ?? '').toString().trim();
    if (pcode.isNotEmpty) {
      return ProductLookupService().getByExactCode(
        companyId: cid,
        productCode: pcode,
      );
    }
    return null;
  }

  return ProductLookupService().findProductByScanContent(
    companyId: cid,
    raw: res.rawPayload.trim(),
  );
}
