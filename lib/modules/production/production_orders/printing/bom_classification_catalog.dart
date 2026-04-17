/// BOM klasifikacije iz proizvoda / sastavnice — jedan izvor za UI i etikete.
const List<String> kBomClassificationCodes = [
  'PRIMARY',
  'SECONDARY',
  'TRANSPORT',
];

String bomClassificationTitleBs(String code) {
  switch (code.toUpperCase()) {
    case 'PRIMARY':
      return 'Primarna';
    case 'SECONDARY':
      return 'Sekundarna';
    case 'TRANSPORT':
      return 'Transportna';
    default:
      return code;
  }
}

/// Jedan red za padajući izbor — naslov + kratka veza na GK/PP/SK/MA.
String bomClassificationDropdownSubtitleBs(String code) {
  switch (code.toUpperCase()) {
    case 'PRIMARY':
      return 'Glavna BOM za proizvod — tipično tok do GK (gotov komad)';
    case 'SECONDARY':
      return 'Druga BOM struktura — često PP/SK, međuoperacija, lot materijala';
    case 'TRANSPORT':
      return 'BOM za ambalažu / transport — nije klasičan proizvodni artikl';
    default:
      return '';
  }
}

/// Objašnjenje za postavku stanice (što odabrati u praksi).
String bomClassificationStationHelpLongBs(String code) {
  switch (code.toUpperCase()) {
    case 'PRIMARY':
      return 'U bazi svaki proizvod može imati više sastavnica (BOM) označenih klasifikacijom. '
          'Primarna je glavna: ona opisuje što ulazi u jedan komad u glavnom proizvodnom toku. '
          'Na listama proizvoda šifre često počinju s GK (gotov komad), PP (poluproizvod) itd. — to je vrsta artikla po šifri; '
          'PRIMARY znači da na ovoj stanici knjižiš i etiketiraš upravo prema toj glavnoj sastavnici.\n\n'
          'Odaberi za stanice gdje je fokus nalog / kontrola / ispis za taj glavni tok (npr. brizganje gotovog dijela ako je u šifrarniku glavna BOM primarna).';
    case 'SECONDARY':
      return 'Sekundarna sastavnica je dodatna BOM (druga struktura ili međuoperacija), npr. kad isti artikl ima alternativni sastav ili kad pratiš poluproizvod u lancu. '
          'U aplikaciji se često veže uz drugačije polje (npr. lot ulaznog materijala). '
          'Šifra artikla i dalje može biti PP ili SK — ovdje biraš da stanica radi na sekundarnoj BOM, ne na primarnoj.\n\n'
          'Odaberi za stanice koje u modelu podataka koriste sekundarnu sastavnicu (međuoperacija, repromaterijal, poluproizvod prije finala).';
    case 'TRANSPORT':
      return 'Transportna klasifikacija u BOM-u služi za ambalažu, palete, kutije, nositelje — dakle artikle koji nisu „komad proizvoda“ u uobičajenom smislu nego nositelj ili pakovanje.\n\n'
          'Odaberi za stanice koje samo etiketiraju ili evidentiraju transport / ambalažu prema toj vrsti sastavnice.';
    default:
      return '';
  }
}

/// Kratki uvod za ekran postavki (odnos BOM vs šifra GK/PP/SK/MA).
String bomClassificationStationIntroBs() {
  return 'Ovdje ne biraš slova šifre artikla (GK, PP, SK, MA) — to dolazi iz proizvoda. '
      'Biraš koju sastavnicu (BOM) u sustavu ova stanica koristi: primarnu, sekundarnu ili transportnu. '
      'Ista vrijednost ide u JSON etikete i u praćenje.';
}

/// Tip etikete u smislu logistike / tragljivosti (MASTER_DATA_AND_LOGISTICS).
String bomClassificationLogisticsLabelBs(String code) {
  switch (code.toUpperCase()) {
    case 'PRIMARY':
      return 'Gotov proizvod (primarna sastavnica)';
    case 'SECONDARY':
      return 'Poluproizvod (sekundarna sastavnica)';
    case 'TRANSPORT':
      return 'Transport / ambalaža';
    default:
      return 'Materijal / etiketa';
  }
}
