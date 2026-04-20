import '../../../commercial/orders/models/order_model.dart';

/// Stavka za PDF otpremnice (hub → kupac).
class HubOutboundShipmentLinePdf {
  const HubOutboundShipmentLinePdf({
    required this.code,
    required this.name,
    required this.quantity,
    required this.unit,
    this.lotLabel,
  });

  final String code;
  final String name;
  final double quantity;
  final String unit;
  final String? lotLabel;
}

/// Zaglavlje otpreme za PDF — usklađeno s `HUB_CUSTOMER_OUTBOUND_SHIPMENTS.md` §5 + fiskalna polja kao na `orders`.
class HubCustomerOutboundShipmentPdfData {
  const HubCustomerOutboundShipmentPdfData({
    required this.shipmentCode,
    this.orderNumber,
    this.orderId,
    required this.partnerName,
    this.partnerCode,
    this.deliveryAddress,
    this.shippingTerms,
    this.currency,
    this.isExport = false,
    this.customerCountryCode,
    this.incoterms,
    this.vatExemptionNote,
    this.customsDeclarationRef,
    this.cmrNumber,
    this.awbNumber,
    this.hubWarehouseLabel,
    this.carrierName,
    this.trackingNumber,
    this.plannedShipDate,
    this.actualShipDate,
    this.statusLabel,
    required this.lines,
    this.footerNote,
  });

  final String shipmentCode;
  final String? orderNumber;
  final String? orderId;

  final String partnerName;
  final String? partnerCode;

  final String? deliveryAddress;
  final String? shippingTerms;
  final String? currency;

  final bool isExport;
  final String? customerCountryCode;
  final String? incoterms;
  final String? vatExemptionNote;
  final String? customsDeclarationRef;
  final String? cmrNumber;
  final String? awbNumber;

  final String? hubWarehouseLabel;
  final String? carrierName;
  final String? trackingNumber;
  final DateTime? plannedShipDate;
  final DateTime? actualShipDate;
  final String? statusLabel;

  final List<HubOutboundShipmentLinePdf> lines;

  /// Napomena ispod dokumenta (npr. nacrt vs. službeni dokument).
  final String? footerNote;

  /// Isti skup napomena kao na prodajnoj narudžbi / fakturi (BiH).
  String get fiscalBlockText {
    final parts = <String>[];
    if (isExport) parts.add('Izvoz (INO)');
    final cc = (customerCountryCode ?? '').trim();
    if (cc.isNotEmpty) parts.add('ISO država: $cc');
    final inc = (incoterms ?? '').trim();
    if (inc.isNotEmpty) parts.add('INCOTERMS: $inc');
    final vn = (vatExemptionNote ?? '').trim();
    if (vn.isNotEmpty) parts.add('Napomena (PDV): $vn');
    final cd = (customsDeclarationRef ?? '').trim();
    if (cd.isNotEmpty) parts.add('Carinska deklaracija: $cd');
    final cmr = (cmrNumber ?? '').trim();
    if (cmr.isNotEmpty) parts.add('CMR: $cmr');
    final awb = (awbNumber ?? '').trim();
    if (awb.isNotEmpty) parts.add('AWB: $awb');
    return parts.join('\n');
  }

  /// Nacrt otpremnice iz zaglavlja prodajne narudžbe (dok se ne kreira `hub_customer_outbound_shipments`).
  factory HubCustomerOutboundShipmentPdfData.fromCustomerOrder(
    OrderModel order, {
    String draftShipmentCodePrefix = 'NACRT',
    String? hubWarehouseLabel,
    String? footerNote,
  }) {
    if (order.orderType != OrderType.customer) {
      throw ArgumentError(
        'Otpremnica prema kupcu odnosi se na prodajnu narudžbu (customer_order).',
      );
    }
    return HubCustomerOutboundShipmentPdfData(
      shipmentCode: '$draftShipmentCodePrefix-${order.orderNumber}',
      orderNumber: order.orderNumber,
      orderId: order.id,
      partnerName: order.partnerName,
      partnerCode: order.partnerCode,
      deliveryAddress: order.deliveryAddress,
      shippingTerms: order.shippingTerms,
      currency: order.currency,
      isExport: order.isExport,
      customerCountryCode: order.customerCountryCode,
      incoterms: order.incoterms,
      vatExemptionNote: order.vatExemptionNote,
      customsDeclarationRef: order.customsDeclarationRef,
      cmrNumber: order.cmrNumber,
      awbNumber: order.awbNumber,
      hubWarehouseLabel: hubWarehouseLabel,
      lines: order.items
          .map(
            (it) => HubOutboundShipmentLinePdf(
              code: it.productCode,
              name: it.productName,
              quantity: it.qty,
              unit: it.unit.isNotEmpty ? it.unit : 'kom',
              lotLabel: null,
            ),
          )
          .toList(),
      footerNote: footerNote ??
          'Nacrt iz podataka narudžbe. Službeni broj i status otpreme '
          'dodjeljuju se u logističkom modulu nakon kreiranja dokumenta otpreme.',
    );
  }
}
