import 'package:flutter/foundation.dart';

/// Prikaz stanja godišnjeg: ostatak s prošle godine, tekuća godina, iskorišteno, preostalo.
/// Točan obračun stjecanja (npr. nakon 6 mjeseci rada) definira se u pravilima + HR bazi.
@immutable
class WorkTimeAnnualBalanceView {
  const WorkTimeAnnualBalanceView({
    required this.carriedOverFromLastYear,
    required this.entitledThisYear,
    required this.scheduledThisYear,
    required this.takenThisYear,
  });

  final double carriedOverFromLastYear;
  final double entitledThisYear;
  final double scheduledThisYear;
  final double takenThisYear;

  double get remainingThisYear => (carriedOverFromLastYear + entitledThisYear) -
      (takenThisYear + scheduledThisYear);
}

/// Sažetak zakonskog okvira (Zakon o radu RH) — informativno za korisnike; točan pravni savjet = HR/odvjetnik.
const String kCroatiaAnnualLeaveLawSummaryHr =
    'Prema Zakonu o radu, radniku pripada minimalno 4 tjedna godišnjeg odmora u kalendarskoj '
    'godini; stjecanje, skraćenje i progresivno povećanje ovise o duljini neprekinutog rada, '
    'dob, zaštitnim kategorijama itd. Prijenos neiskorištenog dijela ovisi o Kolektivnom ugovoru '
    'i pravilu poslodavca, uz zakonit limit. U aplikaciju unesite dane prema vašim internim '
    'pravilima i UGO-u; ovdje se prikazuje stanje za odluke u modulu.';
