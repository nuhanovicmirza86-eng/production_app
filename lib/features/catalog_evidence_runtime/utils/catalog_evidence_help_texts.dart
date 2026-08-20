import 'package:flutter/material.dart';

import '../../../modules/production/ooe/widgets/ooe_info_icon.dart';

/// Info copy za company / catalog evidence profile (HUB + runtime AppBar).
///
/// **M1-I5-C3 zakon:** svaka operativna evidencija u HUB-u mora imati info
/// ikonicu s BS objašnjenjem funkcije. Detalji sesije ne smiju sadržavati
/// to objašnjenje — samo evidentirane podatke.
abstract final class CatalogEvidenceHelpTexts {
  static const inProcessQualityCheckTooltip =
      'Kontrola proizvoda i procesa tokom proizvodnje.';

  static const inProcessQualityCheckTitle = 'Procesna kontrola kvaliteta';

  static const inProcessQualityCheckBody =
      'Procesna kontrola kvaliteta koristi se tokom proizvodnje za provjeru da li '
      'su proizvod i proces i dalje ispravni. Evidentira se proizvodni nalog, '
      'proizvod, mjesto rada, proizvodni operater, kontrolor kvaliteta, '
      'kontrolisana količina, prolazi/ne prolazi, razlog greške i ishod kontrole.\n\n'
      'Nije isto što Kontrola pakovanja (ambalaža/oznake u fazi pakovanja) niti '
      'Odobrenje prvog komada (početno odobrenje proizvodnje).';

  static const packagingControlTooltip =
      'Kontrola ambalaže, oznaka i količine u fazi pakovanja.';

  static const packagingControlTitle = 'Kontrola pakovanja';

  static const packagingControlBody =
      'Kontrola pakovanja koristi se u fazi pakovanja za provjeru da li je '
      'proizvod pravilno upakovan, označen i pripremljen za dalje kretanje. '
      'Evidentira se operater pakovanja, kontrolor, količina pakovanja, '
      'prihvaćeno/odbijeno, greške pakovanja, etikete, ambalaža i komentar.\n\n'
      'Nije isto što Procesna kontrola kvaliteta (proizvod/proces tokom proizvodnje).';

  static const finalControlTooltip =
      'Finalna kontrola kvaliteta prije skladištenja ili isporuke.';

  static const finalControlTitle = 'Finalna kontrola';

  static const finalControlBody =
      'Finalna kontrola koristi se kao završna provjera kvaliteta prije '
      'skladištenja ili isporuke. Evidentira se proizvodni nalog, proizvod, '
      'kontrolor, kontrolisani komadi (OK / škart / dorada) i finalna '
      'dispozicija.\n\n'
      'Nije isto što Procesna kontrola kvaliteta (kontrola tokom proizvodnje), '
      'Odobrenje prvog komada (početno odobrenje) ni Kontrola pakovanja '
      '(ambalaža/oznake).';

  static const chemicalDosingTooltip =
      'Evidencija doziranja hemikalija u proces ili radnu kupku.';

  static const chemicalDosingTitle = 'Doziranje hemikalija';

  static const chemicalDosingBody =
      'Doziranje hemikalija koristi se za evidentiranje dodavanja hemikalija u '
      'proces ili radnu kupku. Evidentira se mjesto rada, hemikalija, količina, '
      'jedinica, vrijeme, operater i komentar. Koristi se za sljedivost procesa, '
      'potrošnju hemikalija i kontrolu pravilnog doziranja.';

  static const productionCountingTooltip =
      'Evidencija proizvedenih količina, škarta i dorade.';

  static const productionCountingTitle = 'Evidencija količina proizvodnje';

  static const productionCountingBody =
      'Evidencija količina proizvodnje koristi se za unos proizvedenih količina '
      'po nalogu, proizvodu, pogonu i operateru. Evidentira se dobra količina, '
      'škart, dorada i komentar. Koristi se za praćenje učinka proizvodnje i '
      'osnovnu proizvodnu sljedivost.';

  static const wastewaterTreatmentTooltip =
      'Evidencija tretmana i kontrole otpadnih voda.';

  static const wastewaterTreatmentTitle = 'Obrada otpadnih voda';

  static const wastewaterTreatmentBody =
      'Obrada otpadnih voda koristi se za evidentiranje tretmana procesnih voda. '
      'Evidentira se vrsta obrade, pH, redox, količine, talog, vrijeme, operater '
      'i komentar. Koristi se za sljedivost tretmana, internu kontrolu i '
      'ekološke zapise.';

  static const firstPieceApprovalTooltip =
      'Početno odobrenje proizvodnje na osnovu prvog komada.';

  static const firstPieceApprovalTitle = 'Odobrenje prvog komada';

  static const firstPieceApprovalBody =
      'Odobrenje prvog komada koristi se na početku proizvodnje za potvrdu da '
      'prvi komadi zadovoljavaju zahtjeve prije nastavka rada. Evidentira se '
      'nalog, proizvod, mašina ili mjesto rada, kontrolor, kontrolisani komadi, '
      'rezultat i odluka o odobrenju proizvodnje.';

  /// Info ikona za profil — **uvijek** vraća widget (M1-I5-C3).
  ///
  /// Za poznate profile: kurirani BS tekst.
  /// Za nove profile bez kuriranog teksta: [displayName] + [description]
  /// (katalog), da HUB nikad ne ostane bez info ikonice.
  static Widget infoIconForProfile({
    required String profileKey,
    String? displayName,
    String? description,
  }) {
    final key = profileKey.trim();
    switch (key) {
      case 'in_process_quality_check':
        return const OoeInfoIcon(
          tooltip: inProcessQualityCheckTooltip,
          dialogTitle: inProcessQualityCheckTitle,
          dialogBody: inProcessQualityCheckBody,
        );
      case 'packaging_control':
        return const OoeInfoIcon(
          tooltip: packagingControlTooltip,
          dialogTitle: packagingControlTitle,
          dialogBody: packagingControlBody,
        );
      case 'final_control':
        return const OoeInfoIcon(
          tooltip: finalControlTooltip,
          dialogTitle: finalControlTitle,
          dialogBody: finalControlBody,
        );
      case 'chemical_dosing':
        return const OoeInfoIcon(
          tooltip: chemicalDosingTooltip,
          dialogTitle: chemicalDosingTitle,
          dialogBody: chemicalDosingBody,
        );
      case 'production_counting':
        return const OoeInfoIcon(
          tooltip: productionCountingTooltip,
          dialogTitle: productionCountingTitle,
          dialogBody: productionCountingBody,
        );
      case 'wastewater_treatment':
        return const OoeInfoIcon(
          tooltip: wastewaterTreatmentTooltip,
          dialogTitle: wastewaterTreatmentTitle,
          dialogBody: wastewaterTreatmentBody,
        );
      case 'first_piece_approval':
        return const OoeInfoIcon(
          tooltip: firstPieceApprovalTooltip,
          dialogTitle: firstPieceApprovalTitle,
          dialogBody: firstPieceApprovalBody,
        );
      default:
        return _fallbackInfoIcon(
          displayName: displayName,
          description: description,
        );
    }
  }

  /// Kompatibilnost: isti kurirani tekstovi; bez fallback metapodataka.
  static Widget infoIconForProfileKey(String profileKey) =>
      infoIconForProfile(profileKey: profileKey);

  static Widget _fallbackInfoIcon({
    String? displayName,
    String? description,
  }) {
    final title = (displayName ?? '').trim().isEmpty
        ? 'Evidencija'
        : displayName!.trim();
    final body = (description ?? '').trim().isEmpty
        ? 'Ova evidencija bilježi operativne podatke prema konfiguraciji '
            'kompanije. Detalji sesije prikazuju samo unesene vrijednosti.'
        : description!.trim();
    final tooltip = body.length <= 80
        ? body
        : '${body.substring(0, 77).trimRight()}…';
    return OoeInfoIcon(
      tooltip: tooltip,
      dialogTitle: title,
      dialogBody: body,
    );
  }
}
