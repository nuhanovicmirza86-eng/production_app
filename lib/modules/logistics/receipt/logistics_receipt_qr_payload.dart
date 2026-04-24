/// QR referenca na zapis prijema robe u `logistics_receipts`.
///
/// Format: `rcpt:v1;<docId>` ili `rcpt:v1;docId=<docId>` (isto pravilo kao `wmslot:v1`).
String buildLogisticsReceiptQrPayload({required String receiptDocId}) {
  final id = receiptDocId.trim();
  if (id.isEmpty) return 'rcpt:v1;';
  return 'rcpt:v1;docId=${Uri.encodeComponent(id)}';
}

/// Izvlači Firestore id dokumenta iz `rcpt:v1;…`.
String? tryParseLogisticsReceiptDocIdFromQr(String raw) {
  final t = raw.trim();
  if (t.isEmpty || !t.startsWith('rcpt:v1;')) return null;
  var rest = t.substring('rcpt:v1;'.length).trim();
  if (rest.startsWith('docId=')) {
    rest = rest.substring('docId='.length).trim();
  }
  if (rest.isEmpty) return null;
  return Uri.decodeComponent(rest);
}
