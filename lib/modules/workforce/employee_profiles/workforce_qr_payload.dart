/// Javni radnikov QR/bedž — isti stil segmentiranih polja kao `meter:` / [asset] QR-ovi.
/// Skener u aplikaciji kasnije parsira i traži [employeeDocId] u tenantu.
String buildWorkforceEmployeeQrPayload({
  required String companyId,
  required String plantKey,
  required String employeeDocId,
}) {
  final c = companyId.trim();
  final p = plantKey.trim();
  final e = employeeDocId.trim();
  return 'workforceEmployee:v1;companyId=${Uri.encodeComponent(c)};'
      'plantKey=${Uri.encodeComponent(p)};'
      'employeeDocId=${Uri.encodeComponent(e)}';
}

/// Uspjeli parse QR bedža (isti format kao [buildWorkforceEmployeeQrPayload]).
class ParsedWorkforceEmployeeQr {
  const ParsedWorkforceEmployeeQr({
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
  });

  final String companyId;
  final String plantKey;
  final String employeeDocId;
}

/// Vraća [ParsedWorkforceEmployeeQr] ili `null` ako niz nije ispravan bedž.
ParsedWorkforceEmployeeQr? tryParseWorkforceEmployeeQr(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (!t.startsWith('workforceEmployee:v1')) return null;
  final parts = t.split(';');
  if (parts.length < 2) return null;
  if (parts.first.trim() != 'workforceEmployee:v1') return null;
  String? c;
  String? p;
  String? e;
  for (var i = 1; i < parts.length; i++) {
    final seg = parts[i].trim();
    final eq = seg.indexOf('=');
    if (eq < 0) continue;
    final k = seg.substring(0, eq).trim();
    final v = seg.substring(eq + 1);
    switch (k) {
      case 'companyId':
        c = Uri.decodeComponent(v).trim();
        break;
      case 'plantKey':
        p = Uri.decodeComponent(v).trim();
        break;
      case 'employeeDocId':
        e = Uri.decodeComponent(v).trim();
        break;
    }
  }
  if (c == null || p == null || e == null) return null;
  if (c.isEmpty || p.isEmpty || e.isEmpty) return null;
  if (!RegExp(r'^RAD_\d+$').hasMatch(e)) return null;
  return ParsedWorkforceEmployeeQr(
    companyId: c,
    plantKey: p,
    employeeDocId: e,
  );
}
