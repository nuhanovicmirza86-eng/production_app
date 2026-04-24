/// Čitljiv sažetak WMS lota za UI (bez internih ID-eva dokumenta).
String wmsLotCaptionFromDocData(Map<String, dynamic> d) {
  String s(dynamic v) => (v ?? '').toString().trim();

  final code = s(d['itemCode']);
  final name = s(d['itemName']);
  final lotLogical = s(d['lotId']);
  final batch = s(d['batchNumber']);
  final qty = d['quantity'];
  final unit = s(d['unit']);

  final parts = <String>[];
  if (code.isNotEmpty && name.isNotEmpty) {
    parts.add('$code — $name');
  } else if (code.isNotEmpty) {
    parts.add(code);
  } else if (name.isNotEmpty) {
    parts.add(name);
  }
  if (lotLogical.isNotEmpty) parts.add('Lot $lotLogical');
  if (batch.isNotEmpty) parts.add('Šarža $batch');
  if (qty != null) {
    final qn = qty is num ? qty.toString() : s(qty);
    if (qn.isNotEmpty) {
      parts.add(unit.isNotEmpty ? '$qn $unit' : qn);
    }
  }
  return parts.isEmpty ? 'Lot' : parts.join(' · ');
}
