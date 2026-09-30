import 'package:cloud_functions/cloud_functions.dart';

import '../operonix_ai_ux_copy.dart';

/// Poruka za korisnika iz [FirebaseFunctionsException].
///
/// Firebase/Callable ponekad propagira samo status **INTERNAL** bez teksta
/// s [HttpsError] poruke — tada pokažemo smisleni poslovni tekst.
String firebaseCallableUserMessage(FirebaseFunctionsException e) {
  final raw = (e.message ?? '').trim();
  final code = e.code.trim().toLowerCase();

  // AI-M3-UI-LANG-01 — never surface raw field names to BCS UI.
  final lower = raw.toLowerCase();
  if (lower.contains('datefrom') || lower.contains('dateto')) {
    return 'Odaberite period za prikaz liste praćenja.';
  }

  if (_isTransientServiceFailure(code, raw)) {
    return kOperonixAiTransientReplyUnavailable;
  }

  if (raw.isNotEmpty && raw.toUpperCase() != 'INTERNAL') {
    if (_looksTechnical(raw)) {
      return kOperonixAiTransientReplyUnavailable;
    }
    return raw;
  }

  switch (code) {
    case 'internal':
    case 'unavailable':
    case 'deadline-exceeded':
    case 'resource-exhausted':
      return kOperonixAiTransientReplyUnavailable;
    case 'permission-denied':
      return raw.isNotEmpty ? raw : 'Nemaš dopuštenje za ovu radnju.';
    case 'unauthenticated':
      return raw.isNotEmpty ? raw : 'Moraš biti prijavljen.';
    case 'failed-precondition':
      return raw.isNotEmpty
          ? raw
          : 'Preduvjet nije ispunjen. Obrati se administratoru.';
    case 'invalid-argument':
      return raw.isNotEmpty ? raw : 'Neispravan zahtjev.';
    default:
      if (raw.isNotEmpty && !_looksTechnical(raw)) return raw;
      return kOperonixAiTransientReplyUnavailable;
  }
}

bool _isTransientServiceFailure(String code, String raw) {
  final lower = raw.toLowerCase();
  if (code == 'internal' ||
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'resource-exhausted') {
    return true;
  }
  if (raw.toUpperCase() == 'INTERNAL') return true;
  if (lower.contains('privremena greška') ||
      lower.contains('privremena greska') ||
      lower.contains('vertex') ||
      lower.contains('aichat') ||
      lower.contains('cloud function') ||
      lower.contains('callable')) {
    return true;
  }
  return false;
}

bool _looksTechnical(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('vertex') ||
      lower.contains('http') ||
      lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('firebase') ||
      lower.contains('callable') ||
      RegExp(r'\b[A-Z]{2,}[-_]?\d+\b').hasMatch(raw);
}
