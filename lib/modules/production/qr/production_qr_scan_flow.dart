import 'package:flutter/material.dart';

import '../../logistics/receipt/screens/packing_box_receipt_screen.dart';
import '../../logistics/receipt/screens/production_label_receipt_screen.dart';
import '../production_orders/screens/production_order_details_screen.dart';
import 'production_qr_resolver.dart';
import 'screens/production_qr_scan_screen.dart';

/// Pokreće skeniranje QR-a i usmjerava prema rezoluciji (isti tok kao dashboard).
Future<void> runProductionQrScanFlow({
  required BuildContext context,
  required Map<String, dynamic> companyData,
}) async {
  final resolution = await Navigator.push<ProductionQrScanResolution>(
    context,
    MaterialPageRoute<ProductionQrScanResolution>(
      fullscreenDialog: true,
      builder: (_) => ProductionQrScanScreen(companyData: companyData),
    ),
  );

  if (!context.mounted || resolution == null) return;

  switch (resolution.intent) {
    case ProductionQrIntent.productionOrderReferenceV1:
      final id = resolution.productionOrderId?.trim();
      if (id == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR ne sadrži ID naloga. Koristite noviji ispis (po:v1 sa poljem id).',
            ),
          ),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductionOrderDetailsScreen(
            companyData: companyData,
            productionOrderId: id,
          ),
        ),
      );
      break;

    case ProductionQrIntent.printedClassificationLabelV1:
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductionLabelReceiptScreen(
            companyData: companyData,
            resolution: resolution,
          ),
        ),
      );
      break;

    case ProductionQrIntent.packedStation1BoxV1:
      final boxId = resolution.packingBoxId?.trim();
      if (boxId == null || boxId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR kutije nije valjan.')),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              PackingBoxReceiptScreen(companyData: companyData, boxId: boxId),
        ),
      );
      break;

    case ProductionQrIntent.wmsLotDocV1:
      final lotId = resolution.wmsLotDocId?.trim();
      if (lotId == null || lotId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WMS QR nema id lota. Koristi format wmslot:v1;<id>.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WMS lot: $lotId — otvori WMS (Putaway / Otpremna zona).',
          ),
        ),
      );
      break;

    case ProductionQrIntent.nepoznat:
      final raw = resolution.rawPayload;
      final preview = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nepoznat QR. Sadržaj: $preview')),
      );
      break;
  }
}
