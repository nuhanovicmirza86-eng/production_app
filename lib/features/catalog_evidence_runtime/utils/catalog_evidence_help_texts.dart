import 'package:flutter/material.dart';

import '../../../modules/production/ooe/widgets/ooe_info_icon.dart';

/// Info copy za company / catalog evidence profile (M1-I4-C4).
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

  /// Vraća info ikonu za poznati profil; inače null.
  static Widget? infoIconForProfileKey(String profileKey) {
    switch (profileKey.trim()) {
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
      default:
        return null;
    }
  }
}
