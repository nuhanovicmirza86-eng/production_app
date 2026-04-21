/// Deterministički IDjevi dokumenata za tenant + pogon + mašinu.
class OoePathIds {
  OoePathIds._();

  /// `ooe_live_status/{id}` — jedinstveno unutar root kolekcije.
  static String liveStatusDocId({
    required String companyId,
    required String plantKey,
    required String machineId,
  }) {
    final c = companyId.trim();
    final p = plantKey.trim();
    final m = machineId.trim();
    return '$c|$p|$m';
  }

  /// `ooe_shift_summaries/{id}`
  static String shiftSummaryDocId({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime shiftDateLocal,
    required String shiftId,
  }) {
    final c = companyId.trim();
    final p = plantKey.trim();
    final m = machineId.trim();
    final sid = shiftId.trim();
    final d = shiftDateLocal;
    final dk =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '$c|$p|$m|$dk|$sid';
  }

  /// `shift_contexts/{id}` — jedna smjena na konkretan dan (npr. DAY @ 2026-04-22).
  static String shiftContextDocId({
    required String companyId,
    required String plantKey,
    required String shiftDateKey,
    required String shiftCode,
  }) {
    final c = companyId.trim();
    final p = plantKey.trim();
    final d = shiftDateKey.trim();
    final code = shiftCode.trim().toUpperCase();
    return '$c|$p|$d|$code';
  }
}
