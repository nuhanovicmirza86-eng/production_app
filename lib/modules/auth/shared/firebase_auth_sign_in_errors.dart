import 'package:firebase_auth/firebase_auth.dart';

/// Isti BS/EN tekstovi na svim Flutter platformama (web, Android, iOS, desktop)
/// kada servis za prijavu pretvori [FirebaseAuthException] u čitljivu grešku.
class LocalizedSignInFailure implements Exception {
  const LocalizedSignInFailure({
    required this.messageBs,
    required this.messageEn,
  });

  final String messageBs;
  final String messageEn;

  @override
  String toString() => messageBs;
}

/// Heuristika kad SDK vrati neočekivan [FirebaseAuthException.code] ali poznatu englesku poruku.
(String bs, String en)? firebaseAuthCredentialHeuristicBsEn(String? message) {
  final m = (message ?? '').toLowerCase();
  if (!m.contains('credential')) return null;
  if (m.contains('incorrect') ||
      m.contains('malformed') ||
      m.contains('expired')) {
    return (
      'Email ili lozinka nisu ispravni. Provjerite unos i pokušajte ponovo.',
      'The email or password is incorrect. Check your details and try again.'
    );
  }
  return null;
}

/// Jasne poruke za prijavu: bosanski + engleski (Firebase vraća engleski [FirebaseAuthException.message]).
(String bs, String en) firebaseAuthSignInErrorMessages(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
      return (
        'Email ili lozinka nisu ispravni. Provjerite unos i pokušajte ponovo.',
        'The email or password is incorrect. Check your details and try again.'
      );
    case 'user-not-found':
      return (
        'Nema korisničkog računa s ovom email adresom.',
        'There is no user account with this email address.'
      );
    case 'invalid-email':
      return (
        'Email adresa nije u ispravnom formatu.',
        'The email address is not in a valid format.'
      );
    case 'user-disabled':
      return (
        'Ovaj račun je deaktiviran. Obratite se administratoru.',
        'This account has been disabled. Contact your administrator.'
      );
    case 'too-many-requests':
      return (
        'Previše pokušaja prijave. Pričekajte trenutak pa pokušajte ponovo.',
        'Too many sign-in attempts. Please wait a moment and try again.'
      );
    case 'network-request-failed':
      return (
        'Nema mrežne veze ili usluga je nedostupna. Provjerite internet i pokušajte ponovo.',
        'No network connection or the service is unavailable. Check the internet and try again.'
      );
    case 'operation-not-allowed':
      return (
        'Prijava emailom i lozinkom nije omogućena za ovu aplikaciju.',
        'Email/password sign-in is not enabled for this application.'
      );
    case 'internal-error':
    case 'web-internal-error':
      return (
        'Greška na strani autentikacije. Pokušajte ponovo za nekoliko trenutaka.',
        'An authentication service error occurred. Please try again in a few moments.'
      );
    case 'invalid-api-key':
      return (
        'Konfiguracija aplikacije nije ispravna. Obratite se podršci.',
        'The app configuration is invalid. Contact support.'
      );
    default:
      return firebaseAuthCredentialHeuristicBsEn(e.message) ??
          (
            'Prijava nije uspjela. Pokušajte ponovo ili se obratite podršci.',
            'Sign-in failed. Try again or contact support.'
          );
  }
}

(String bs, String en) unexpectedSignInErrorMessages() {
  return (
    'Došlo je do neočekivane greške pri prijavi. Pokušajte ponovo.',
    'An unexpected error occurred during sign-in. Please try again.'
  );
}
