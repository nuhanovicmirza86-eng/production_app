import 'dart:convert';

/// QR na etiketi zatvorene kutije (Stanica 1 / pripremna).
/// Logistika skenira isti JSON za prijem u magacin.
const String kPackingBoxQrType = 'packing_box_station1';

String buildPackingBoxQrJson({
  required String boxId,
  required String companyId,
  required String plantKey,
  required String stationKey,
  required String classification,
}) {
  final map = <String, dynamic>{
    'v': 1,
    'type': kPackingBoxQrType,
    'boxId': boxId.trim(),
    'companyId': companyId.trim(),
    'plantKey': plantKey.trim(),
    'stationKey': stationKey.trim(),
    'cls': classification.trim().toUpperCase(),
  };
  return jsonEncode(map);
}

Map<String, dynamic>? tryParsePackingBoxQr(String raw) {
  final s = raw.trim();
  if (s.isEmpty || !s.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

bool isPackingBoxStation1Map(Map<String, dynamic> m) {
  return (m['type']?.toString() == kPackingBoxQrType);
}
