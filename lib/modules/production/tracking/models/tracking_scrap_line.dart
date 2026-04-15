/// Jedna stavka škarta u operativnom unosu.
/// [code] = kanonski sistemski kod defekta (vidi QUALITY_ARCHITECTURE.md);
/// [label] = prikazni naziv (npr. kompanijski override za operatere).
class TrackingScrapLine {
  final String code;
  final String label;
  final double qty;

  const TrackingScrapLine({
    required this.code,
    required this.label,
    required this.qty,
  });

  Map<String, dynamic> toMap() => {'code': code, 'label': label, 'qty': qty};

  static TrackingScrapLine? tryParse(Map<String, dynamic> m) {
    final code = (m['code'] ?? '').toString().trim();
    final label = (m['label'] ?? '').toString().trim();
    final q = m['qty'];
    if (q is! num) return null;
    final qty = q.toDouble();
    if (qty <= 0) return null;
    if (code.isEmpty && label.isEmpty) return null;
    return TrackingScrapLine(
      code: code.isEmpty ? label : code,
      label: label.isEmpty ? code : label,
      qty: qty,
    );
  }
}

/// Definicija pločice škarta (iz [companyData] ili zadano).
class ScrapTileDef {
  final String code;
  final String label;

  const ScrapTileDef({required this.code, required this.label});
}
