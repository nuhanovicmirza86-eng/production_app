/// Kanonski QR za proizvodni nalog: stabilna referenca (PRODUCTION_ARCHITECTURE).
/// Uključuje i **broj naloga** (`code`) radi skeniranja i provjere na terenu.
///
/// Format: `po:v1;c=<companyId>;p=<plantKey>;id=<productionOrderId>;code=<productionOrderCode>`
String buildProductionOrderQrPayload({
  required String companyId,
  required String plantKey,
  required String productionOrderId,
  required String productionOrderCode,
}) {
  final c = Uri.encodeComponent(companyId.trim());
  final p = Uri.encodeComponent(plantKey.trim());
  final id = Uri.encodeComponent(productionOrderId.trim());
  final code = Uri.encodeComponent(productionOrderCode.trim());
  return 'po:v1;c=$c;p=$p;id=$id;code=$code';
}

/// Parsiranje za budući skener (povrat `productionOrderId` ako je poznat format).
String? tryParseProductionOrderIdFromQr(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.startsWith('po:v1;')) {
    final id = _extractKeyValue(s, 'id');
    if (id != null && id.isNotEmpty) return id;
  }
  if (s.startsWith('pol:v1;')) {
    final id = _extractKeyValue(s, 'poId');
    if (id != null && id.isNotEmpty) return id;
  }

  return null;
}

/// Broj naloga iz QR-a (`code`), ako postoji.
String? tryParseProductionOrderCodeFromQr(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.startsWith('po:v1;') || s.startsWith('pol:v1;')) {
    return _extractKeyValue(s, 'code');
  }

  return null;
}

String? _extractKeyValue(String payload, String key) {
  final prefix = '$key=';
  for (final part in payload.split(';')) {
    final t = part.trim();
    if (t.startsWith(prefix)) {
      return Uri.decodeComponent(t.substring(prefix.length));
    }
  }
  return null;
}
