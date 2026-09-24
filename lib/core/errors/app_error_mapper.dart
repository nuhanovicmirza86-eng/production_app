import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AppErrorMapper {
  static String toMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      return _withoutTechLeak(_firebaseFunctionsMessage(error));
    }

    if (error is FirebaseException) {
      String mapped;
      switch (error.code) {
        case 'permission-denied':
          mapped = _permissionDeniedMessage(error);
          break;
        case 'unauthenticated':
          mapped = 'Morate biti prijavljeni da biste nastavili.';
          break;
        case 'unavailable':
          mapped = 'Servis trenutno nije dostupan. Pokušajte ponovo.';
          break;
        case 'not-found':
          mapped = 'Traženi podatak nije pronađen.';
          break;
        case 'already-exists':
          mapped = 'Podatak već postoji.';
          break;
        case 'failed-precondition':
          mapped = _failedPreconditionMessage(error);
          break;
        case 'deadline-exceeded':
          mapped = 'Zahtjev je istekao. Pokušajte ponovo.';
          break;
        case 'cancelled':
          mapped = 'Akcija je prekinuta.';
          break;
        case 'invalid-argument':
          mapped = 'Uneseni podaci nisu ispravni.';
          break;
        default:
          mapped = error.message?.trim().isNotEmpty == true
              ? error.message!
              : 'Došlo je do greške. Pokušajte ponovo.';
      }
      return _withoutTechLeak(mapped);
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

    if (raw.contains('loadlibrary') ||
        raw.contains('deferredload') ||
        raw.contains('part.js') ||
        raw.contains('failed to load')) {
      return 'Modul ekrana se nije uspio učitati. Osvježite stranicu (Ctrl+Shift+R) '
          'ili kontaktirajte administratora.';
    }

    if (raw.contains('permission-denied') || raw.contains('permission denied')) {
      return 'Nemate pristup ovim podacima za ovu ulogu ili pogon. '
          'Provjerite dodijeljenu ulogu i pogon.';
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

    if (error is Exception) {
      final msg = error.toString();
      const prefix = 'Exception: ';
      if (msg.startsWith(prefix)) {
        final inner = msg.substring(prefix.length).trim();
        if (inner.isNotEmpty && !_isOpaqueRuntimeType(inner)) {
          return _withoutTechLeak(inner);
        }
      }
    }

    final fallback = error.toString().trim();
    if (fallback.isNotEmpty && !_isOpaqueRuntimeType(fallback)) {
      return _withoutTechLeak(fallback);
    }

    return 'Došlo je do greške. Pokušajte ponovo.';
  }

  static String _withoutTechLeak(String message) {
    var t = message;
    t = t.replaceAll(RegExp(r'permission-denied', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'permission denied', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'firestore\.rules', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\n+\(kod:.*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (t.isEmpty) {
      return 'Nemate pristup ovim podacima za ovu ulogu ili pogon. '
          'Provjerite dodijeljenu ulogu i pogon.';
    }
    return t;
  }

  static bool _isOpaqueRuntimeType(String s) {
    final t = s.trim();
    return t.isEmpty ||
        t == 'Exception' ||
        t.startsWith('Instance of ') ||
        t.startsWith('minified:');
  }

  /// Callable (Cloud Functions) — nije Firestore `permission-denied` s klijenta.
  /// Poruka s poslužitelja (HttpsError) obično je već na bosanskom.
  static String _firebaseFunctionsMessage(FirebaseFunctionsException e) {
    final m = (e.message ?? '').trim();
    switch (e.code) {
      case 'permission-denied':
        if (m.isNotEmpty) return m;
        return 'Nemate pristup ovim podacima za ovu ulogu ili pogon. '
            'Provjerite dodijeljenu ulogu i pogon.';
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
        if (m.isNotEmpty && m.toUpperCase() != 'INTERNAL') {
          return kDebugMode ? '$m\n\n(kod: ${e.code})' : m;
        }
        return 'Nije moguće završiti zatvaranje neusaglašenosti. Pokušajte ponovo.';
      case 'unavailable':
        return 'Servis trenutno nije dostupan. Pokušajte ponovo.';
      case 'deadline-exceeded':
        return 'Zahtjev je istekao. Pokušajte ponovo.';
      case 'resource-exhausted':
        return m.isNotEmpty
            ? m
            : 'Kvota ili limit servisa je prekoračen. Pokušajte kasnije.';
      default:
        if (m.isNotEmpty && m.toUpperCase() != 'INTERNAL') {
          return kDebugMode ? '$m\n\n(kod: ${e.code})' : m;
        }
        return 'Greška na serveru (${e.code}). Pokušajte ponovo.';
    }
  }

  /// Jasno razlikuje Firestore security rules od ostalih uzroka.
  static String _permissionDeniedMessage(FirebaseException error) {
    return 'Nemate pristup ovim podacima za ovu ulogu ili pogon. '
        'Provjerite dodijeljenu ulogu i pogon.';
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
