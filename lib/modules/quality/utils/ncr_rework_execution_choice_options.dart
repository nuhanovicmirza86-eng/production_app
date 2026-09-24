/// M1-I12-D — kontrolisani izbori za evidenciju izvršenja dorade.
const String ncrReworkChoiceOther = 'Drugo';

const List<String> ncrReworkWorkDoneOptions = [
  'Sortiranje',
  'Čišćenje ivice',
  'Uklanjanje viška materijala',
  'Vizuelna dorada',
  'Korekcija podešavanja',
  ncrReworkChoiceOther,
];

const List<String> ncrReworkSeparatedReasonOptions = [
  'Vizuelna greška',
  'Dimenziona neusaglašenost',
  'Oštećenje',
  'Nečistoća',
  'Sumnjiv komad za dodatnu provjeru',
  ncrReworkChoiceOther,
];

const List<String> ncrReworkMachineCorrectionOptions = [
  'Temperatura',
  'Pritisak',
  'Vrijeme ciklusa',
  'Alat / kalup',
  'Podešavanje linije',
  ncrReworkChoiceOther,
];

/// Vraća konačni tekst za backend ili `null` ako izbor nije kompletan.
String? resolveNcrEvidenceChoiceValue({
  required String? selected,
  required String otherText,
  String otherLabel = ncrReworkChoiceOther,
  int minOtherLength = 2,
}) {
  final choice = (selected ?? '').trim();
  if (choice.isEmpty) return null;
  if (choice == otherLabel) {
    final custom = otherText.trim();
    if (custom.length < minOtherLength) return null;
    return custom;
  }
  return choice;
}
