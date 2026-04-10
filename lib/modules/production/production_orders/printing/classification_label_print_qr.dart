import 'dart:convert';

/// QR na otisnutoj etiketi (klasifikacija): puni sadržaj za praćenje na terenu.
///
/// JSON je namjerno čitljiv i jednostavan za parsiranje (bez samo `pol:v1` reference).
/// Ključevi: `pn` nalog, `piece` naziv komada, `qty` količina **u pakovanju**
/// (packagingQty proizvoda + jedinica naloga), `op` operater,
/// `ts` ISO-8601 UTC vrijeme ispisa, `cls` klasifikacija sastavnice.
String buildClassificationLabelPrintQrJson({
  required String productionOrderCode,
  required String productCode,
  required String pieceName,
  required String quantityText,
  required String operatorName,
  required DateTime printedAt,
  required String classification,
  int pieceNameMaxChars = 200,
}) {
  var piece = pieceName.trim();
  if (piece.length > pieceNameMaxChars) {
    piece = '${piece.substring(0, pieceNameMaxChars)}…';
  }

  final map = <String, dynamic>{
    'v': 1,
    'type': 'production_classification_label',
    'pn': productionOrderCode.trim(),
    'pcode': productCode.trim(),
    'piece': piece,
    'qty': quantityText.trim(),
    'op': operatorName.trim(),
    'ts': printedAt.toUtc().toIso8601String(),
    'cls': classification.trim().toUpperCase(),
  };

  return jsonEncode(map);
}

/// Pomoć za budući skener / integracije.
Map<String, dynamic>? tryParseClassificationLabelPrintQr(String raw) {
  final s = raw.trim();
  if (s.isEmpty || !s.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}
