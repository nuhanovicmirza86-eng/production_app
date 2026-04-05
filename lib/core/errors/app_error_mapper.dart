import 'package:cloud_firestore/cloud_firestore.dart';

class AppErrorMapper {
  static String toMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Nemate dozvolu za ovu akciju.';
        case 'unauthenticated':
          return 'Morate biti prijavljeni da biste nastavili.';
        case 'unavailable':
          return 'Servis trenutno nije dostupan. Pokušajte ponovo.';
        case 'not-found':
          return 'Traženi podatak nije pronađen.';
        case 'already-exists':
          return 'Podatak već postoji.';
        case 'failed-precondition':
          return 'Akcija trenutno nije dozvoljena zbog stanja podataka.';
        case 'deadline-exceeded':
          return 'Zahtjev je istekao. Pokušajte ponovo.';
        case 'cancelled':
          return 'Akcija je prekinuta.';
        case 'invalid-argument':
          return 'Uneseni podaci nisu ispravni.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!
              : 'Došlo je do greške. Pokušajte ponovo.';
      }
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('network')) {
      return 'Greška u mreži. Provjerite internet konekciju.';
    }

    if (raw.contains('socketexception')) {
      return 'Greška u mreži. Provjerite internet konekciju.';
    }

    if (raw.contains('timeout')) {
      return 'Zahtjev je istekao. Pokušajte ponovo.';
    }

    if (raw.contains('invalid company context')) {
      return 'Neispravan kontekst kompanije.';
    }

    if (raw.contains('production order not found')) {
      return 'Proizvodni nalog nije pronađen.';
    }

    if (raw.contains('only draft orders can be released')) {
      return 'Samo draft nalog može biti pušten u realizaciju.';
    }

    if (raw.contains('bom and routing must exist before release')) {
      return 'BOM i routing moraju postojati prije puštanja naloga.';
    }

    if (raw.contains('data is missing')) {
      return 'Podaci nisu dostupni. Pokušajte ponovo.';
    }

    return 'Došlo je do greške. Pokušajte ponovo.';
  }
}
