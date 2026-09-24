/// M1-I10-A — BS prikaz labele za QMS NCR (kanonski kodovi ostaju EN u podacima).
abstract final class QmsNcrDisplayLabels {
  static const statusHr = <String, String>{
    'OPEN': 'Otvoreno',
    'UNDER_REVIEW': 'U pregledu',
    'CONTAINED': 'Zadržano',
    'CLOSED': 'Zatvoreno',
    'DISMISSED': 'Odbačeno',
  };

  static const severityHr = <String, String>{
    'LOW': 'Niska',
    'MEDIUM': 'Srednja',
    'HIGH': 'Visoka',
    'CRITICAL': 'Kritična',
  };

  static const sourceHr = <String, String>{
    'CUSTOMER': 'Kupac',
    'SUPPLIER': 'Dobavljač',
    'PROCESS': 'Kontrola proizvodnje',
    'INCOMING': 'Ulazna kontrola',
  };

  static const profileSourceHr = <String, String>{
    'first_piece_approval': 'Odobrenje prvog komada',
    'in_process_quality_check': 'Kontrola u procesu',
    'final_control': 'Završna kontrola',
    'packaging_control': 'Kontrola pakovanja',
    'operation_material_preparation': 'Priprema materijala za operaciju',
  };

  static const outcomeHr = <String, String>{
    'rejected': 'Odbijeno',
    'approved_with_deviation': 'Odobreno s odstupanjem',
    'fail': 'Ne prolazi',
    'conditional_pass': 'Uslovno prolazi',
    'recheck_required': 'Potrebna ponovna kontrola',
    'rework_required': 'Potrebna dorada',
    'blocked': 'Blokirano',
    'hold': 'Zadržano',
    'rework_packaging': 'Dorada pakovanja',
  };

  static String status(String code) {
    final c = code.trim().toUpperCase();
    return statusHr[c] ?? code;
  }

  /// Kanonski poslovni broj NCR-a (novi format ima prednost nad legacy `ncrCode`).
  static String displayDocumentNumber({
    String? ncrDocumentNo,
    String? ncrCode,
  }) {
    final docNo = (ncrDocumentNo ?? '').trim();
    if (docNo.isNotEmpty) return docNo;
    final legacy = (ncrCode ?? '').trim();
    if (legacy.isNotEmpty) return legacy;
    return 'Neusaglašenost';
  }

  static String severity(String code) {
    final c = code.trim().toUpperCase();
    return severityHr[c] ?? code;
  }

  static String source(String code) {
    final c = code.trim().toUpperCase();
    return sourceHr[c] ?? 'Kontrola';
  }

  /// Grupa za vizuelni obrub kartice na NCR listi.
  static String statusBorderGroup(String code) {
    switch (code.trim().toUpperCase()) {
      case 'UNDER_REVIEW':
      case 'CONTAINED':
        return 'in_progress';
      case 'CLOSED':
        return 'closed';
      case 'DISMISSED':
        return 'dismissed';
      case 'OPEN':
      default:
        return 'open';
    }
  }

  static String profileSource(String? profileKey) {
    final k = (profileKey ?? '').trim().toLowerCase();
    if (k.isEmpty) return 'Proizvodnja';
    return profileSourceHr[k] ?? 'Proizvodnja';
  }

  static String outcome(String? outcomeKey) {
    final k = (outcomeKey ?? '').trim().toLowerCase();
    if (k.isEmpty) return '—';
    return outcomeHr[k] ?? outcomeKey!.trim();
  }

  /// Tehnički plantKey tipa `PLANT_2` — ne za korisnički prikaz.
  static bool isTechnicalPlantKey(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return false;
    return RegExp(r'^PLANT_\d+$', caseSensitive: false).hasMatch(v);
  }

  /// Auto-opis iz evidencije: poslovni nazivi profila, bez tehničkih ključeva.
  static String sanitizeUserFacingDescription(
    String raw, {
    String? evidenceProfileKey,
    String? plantDisplayName,
    String? plantKey,
  }) {
    var t = raw.trim();
    if (t.isEmpty) return t;

    t = t.replaceAllMapped(
      RegExp(r'Automatski iz evidencije\s*\(([^)]+)\)', caseSensitive: false),
      (m) {
        final key = (m.group(1) ?? '').trim();
        final label = profileSourceHr[key.toLowerCase()] ??
            profileSource(evidenceProfileKey ?? key);
        return 'Automatski iz evidencije: $label';
      },
    );

    for (final e in profileSourceHr.entries) {
      if (t.contains(e.key)) {
        t = t.replaceAll(e.key, e.value);
      }
    }

    final pKey = (plantKey ?? '').trim();
    final pLabel = (plantDisplayName ?? '').trim();
    if (pKey.isNotEmpty && pLabel.isNotEmpty && t.contains(pKey)) {
      t = t.replaceAll(pKey, pLabel);
    } else if (isTechnicalPlantKey(pKey) && t.contains(pKey)) {
      t = t.replaceAll(pKey, 'pogon');
    }

    return t;
  }

  /// Sakrij Firestore-like ID-eve iz korisničkog prikaza.
  static bool looksLikeInternalId(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return true;
    if (v.contains('-') && RegExp(r'[A-Za-z]').hasMatch(v) && v.length > 12) {
      // npr. PLANT_2-260603-93314 — poslovni kod
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) return false;
      if (v.contains('_') || RegExp(r'-\d{4,}').hasMatch(v)) return false;
    }
    // Tipičan auto-id: 20 alfanumeričkih bez razmaka
    if (RegExp(r'^[A-Za-z0-9]{18,28}$').hasMatch(v)) return true;
    return false;
  }

  static String? businessOrNull(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (looksLikeInternalId(v)) return null;
    return v;
  }
}
