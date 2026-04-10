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
