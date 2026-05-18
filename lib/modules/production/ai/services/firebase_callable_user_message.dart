import 'package:cloud_functions/cloud_functions.dart';

/// Poruka za korisnika iz [FirebaseFunctionsException].
///
/// Firebase/Callable ponekad propagira samo status **INTERNAL** bez teksta
/// s [HttpsError] poruke — tada pokažemo smisleni tekst na hrvatskom.
String firebaseCallableUserMessage(FirebaseFunctionsException e) {
  final raw = (e.message ?? '').trim();
  final code = e.code.trim().toLowerCase();

  if (raw.isNotEmpty && raw.toUpperCase() != 'INTERNAL') {
    return raw;
  }

  switch (code) {
    case 'internal':
      return 'Privremena greška poslužitelja ili AI servisa (Vertex). '
          'Pokušaj ponovo za nekoliko trenutaka. Ako se ponavlja, administrator treba '
          'u Firebase konzoli otvoriti logove Cloud Function (npr. productionTrackingAssistant / aiChat) '
          'i provjeriti Vertex AI: dopuštenja, kvotu, model i da je API uključen za projekt.';
    case 'unavailable':
      return 'Servis je trenutno nedostupan. Pokušaj kasnije.';
    case 'deadline-exceeded':
      return 'Zahtjev je predugo trajao. Pokušaj s kraćim pitanjem ili kasnije.';
    case 'resource-exhausted':
      return 'Dosegnuto je ograničenje korištenja (kvota). Pokušaj kasnije ili kontaktiraj administratora.';
    case 'permission-denied':
      return raw.isNotEmpty
          ? raw
          : 'Nemaš dopuštenje za ovu radnju.';
    case 'unauthenticated':
      return raw.isNotEmpty ? raw : 'Moraš biti prijavljen.';
    case 'failed-precondition':
      return raw.isNotEmpty ? raw : 'Preduvjet nije ispunjen. Obrati se administratoru.';
    case 'invalid-argument':
      return raw.isNotEmpty ? raw : 'Neispravan zahtjev.';
    default:
      if (raw.isNotEmpty) return raw;
      return 'Neočekivana greška (${e.code}).';
  }
}
