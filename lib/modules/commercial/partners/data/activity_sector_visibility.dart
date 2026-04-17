import 'activity_sector_catalog.dart';

/// Kad je `enabledActivitySectorCodes` na kompaniji `null` — cijeli šifarnik.
/// Inače samo uključene šifre (whitelist).
List<ActivitySectorDef> resolveVisibleActivitySectors(dynamic raw) {
  if (raw == null) return activitySectorCatalogSorted;
  if (raw is! List) return activitySectorCatalogSorted;
  final codes = raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (codes.isEmpty) return activitySectorCatalogSorted;
  return activitySectorCatalogSorted
      .where((e) => codes.contains(e.code))
      .toList();
}

/// Padajuća lista na partneru: vidljive + trenutna šifra ako je „siročad“ (isključena u postavkama).
List<ActivitySectorDef> sectorsForPartnerPicker({
  required List<ActivitySectorDef> visibleForCompany,
  String? currentCode,
}) {
  final out = List<ActivitySectorDef>.from(visibleForCompany);
  final c = (currentCode ?? '').trim();
  if (c.isEmpty) return out;
  if (out.any((e) => e.code == c)) return out;
  final def = activitySectorDefForCode(c);
  if (def != null) {
    return [def, ...out];
  }
  return out;
}
