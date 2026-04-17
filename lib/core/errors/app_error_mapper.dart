import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AppErrorMapper {
  static String toMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      return _firebaseFunctionsMessage(error);
    }

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

  /// Callable (Cloud Functions) — nije Firestore `permission-denied` s klijenta.
  /// Poruka s poslužitelja (HttpsError) obično je već na bosanskom.
  static String _firebaseFunctionsMessage(FirebaseFunctionsException e) {
    final m = (e.message ?? '').trim();
    switch (e.code) {
      case 'permission-denied':
        if (m.isNotEmpty) {
          return kDebugMode ? '$m\n\n(kod: ${e.code})' : m;
        }
        return 'Nemaš dozvolu za ovu radnju (provjera na serveru). '
            'Provjeri ulogu, da li korisnik pripada istoj firmi i da li je nalog aktivan.';
      case 'unauthenticated':
        return m.isNotEmpty
            ? m
            : 'Morate biti prijavljeni da biste nastavili.';
      case 'invalid-argument':
        return m.isNotEmpty
            ? m
            : 'Uneseni podaci nisu ispravni.';
      case 'not-found':
        return m.isNotEmpty ? m : 'Traženi podatak nije pronađen.';
      case 'failed-precondition':
        return m.isNotEmpty
            ? m
            : 'Operacija nije dozvoljena u trenutnom stanju podataka.';
      case 'internal':
        return m.isNotEmpty
            ? m
            : 'Greška na serveru. Pokušajte ponovo kasnije.';
      case 'unavailable':
        return 'Servis trenutno nije dostupan. Pokušajte ponovo.';
      case 'deadline-exceeded':
        return 'Zahtjev je istekao. Pokušajte ponovo.';
      case 'resource-exhausted':
        return m.isNotEmpty
            ? m
            : 'Kvota ili limit servisa je prekoračen. Pokušajte kasnije.';
      default:
        if (m.isNotEmpty) {
          return kDebugMode ? '$m\n\n(kod: ${e.code})' : m;
        }
        return 'Greška na serveru (${e.code}). Pokušajte ponovo.';
    }
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
    final raw = (error.message ?? '').trim();
    final m = raw.toLowerCase();
    if (m.contains('index') || m.contains('indexes')) {
      final base =
          'Baza traži sastavljeni indeks za ovaj prikaz (ili se indeks još gradi 1–5 min). '
          'Admin: iz maintenance_app repozitorija pokreni '
          '`firebase deploy --only firestore:indexes`, ili u Firebase konzoli '
          'otvori Firestore → Indexes i koristi link „create composite index” '
          'iz poruke greške u pregledniku (Network / Console).';
      if (kDebugMode && raw.isNotEmpty) {
        return '$base\n\nTehnički detalj:\n$raw';
      }
      return base;
    }
    if (raw.isNotEmpty) {
      return 'Zahtjev nije ispunjen (failed-precondition): $raw';
    }
    return 'Zahtjev nije ispunjen zbog stanja podataka ili konfiguracije baze.';
  }
}
