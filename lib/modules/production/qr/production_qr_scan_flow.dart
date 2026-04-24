import 'package:flutter/material.dart';

import '../../logistics/receipt/screens/logistics_receipt_qr_result_screen.dart';
import '../../logistics/receipt/screens/packing_box_receipt_screen.dart';
import '../../logistics/receipt/screens/production_label_receipt_screen.dart';
import '../../logistics/wms/screens/wms_lot_scan_result_screen.dart';
import '../../workforce/employee_profiles/workforce_employee_qr_navigation.dart';
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
    case ProductionQrIntent.workforceEmployeeV1:
      await openWorkforceEmployeeFromBadgeQr(
        context: context,
        companyData: companyData,
        rawPayload: resolution.rawPayload,
      );
      break;

    case ProductionQrIntent.productionOrderReferenceV1:
      final id = resolution.productionOrderId?.trim();
      if (id == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR naloga nije uredan.')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('QR kutije nije valjan.')));
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
          const SnackBar(content: Text('QR lota nije uredan.')),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              WmsLotScanResultScreen(companyData: companyData, lotDocId: lotId),
        ),
      );
      break;

    case ProductionQrIntent.logisticsReceiptDocV1:
      final receiptId = resolution.logisticsReceiptDocId?.trim();
      if (receiptId == null || receiptId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR prijema nije uredan.')),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LogisticsReceiptQrResultScreen(
            companyData: companyData,
            receiptDocId: receiptId,
          ),
        ),
      );
      break;

    case ProductionQrIntent.nepoznat:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nepoznat QR.')),
      );
      break;
  }
}
