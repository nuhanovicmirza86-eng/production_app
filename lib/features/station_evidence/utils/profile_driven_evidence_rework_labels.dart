/// UI labele za M2-E rework_and_painting supervision (read-only).
String formatReworkOperationTypeLabel(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'DORADA':
      return 'Dorada';
    case 'LAKIRANJE':
      return 'Lakiranje';
    case 'ODMASĆIVANJE':
      return 'Odmašćivanje';
    case 'ČIŠĆENJE':
      return 'Čišćenje';
    case 'BRUŠENJE':
      return 'Brušenje';
    case 'KONTROLA_POSLIJE_DORADE':
      return 'Kontrola poslije dorade';
    default:
      final t = (raw ?? '').trim();
      return t.isEmpty ? '—' : t;
  }
}

String formatReworkResultStatusLabel(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'OK':
      return 'OK';
    case 'DJELOMIČNO_OK':
      return 'Djelomično OK';
    case 'NIJE_OK':
      return 'Nije OK';
    default:
      final t = (raw ?? '').trim();
      return t.isEmpty ? '—' : t;
  }
}

String formatReworkDurationMinutes(num? minutes) {
  if (minutes == null) return '—';
  final n = minutes is int ? minutes : minutes.round();
  return '$n min';
}

List<Map<String, dynamic>> parseStructuredEvidenceRows(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}
