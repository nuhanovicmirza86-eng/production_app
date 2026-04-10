import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppErrorMapper {
  static String toMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return _permissionDeniedMessage(error);
        case 'unauthenticated':
          return 'Morate biti prijavljeni da biste nastavili.';
        case 'unavailable':
          return 'Servis trenutno nije dostupan. Pokušajte ponovo.';
        case 'not-found':
          return 'Traženi podatak nije pronađen.';
        case 'already-exists':
          return 'Podatak već postoji.';
        case 'failed-precondition':
          return _failedPreconditionMessage(error);
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

  /// Jasno razlikuje Firestore security rules od ostalih uzroka.
  static String _permissionDeniedMessage(FirebaseException error) {
    const base =
        'Pristup podacima u bazi je odbijen (Firestore: permission-denied). '
        'To su sigurnosna pravila, ne greška aplikacije. '
        'Provjerite ulogu korisnika, da je nalog aktivan i da su deployana '
        'ažurna firestore.rules na istom Firebase projektu.';
    if (kDebugMode) {
      final m = error.message?.trim();
      if (m != null && m.isNotEmpty) {
        return '$base\n\nTehnički detalj (debug): $m';
      }
    }
    return base;
  }

  static String _failedPreconditionMessage(FirebaseException error) {
    final m = (error.message ?? '').toLowerCase();
    if (m.contains('index') || m.contains('indexes')) {
      return 'Upit zahtijeva Firestore indeks ili indeks se još gradi. '
          'U konzoli provjeri Indexes za kolekciju (npr. orders) ili '
          'pokreni firebase deploy --only firestore:indexes.';
    }
    final raw = error.message?.trim();
    if (raw != null && raw.isNotEmpty) {
      return 'Zahtjev nije ispunjen (failed-precondition): $raw';
    }
    return 'Zahtjev nije ispunjen zbog stanja podataka ili konfiguracije baze.';
  }
}
