/// M1-I12-D — kontrolisani izbori za evidenciju ponovne kontrole.
const String ncrRecheckChoiceOther = 'Drugo';

const List<String> ncrRecheckCheckedAspectOptions = [
  'Vizuelni izgled',
  'Dimenzije',
  'Funkcionalnost',
  'Oštećenje',
  'Čistoća',
  'Oznaka / etiketa',
  ncrRecheckChoiceOther,
];

const List<String> ncrRecheckOutcomeOptions = [
  'Odobreno',
  'Djelimično odobreno',
  'Nije odobreno',
];

String? resolveNcrRecheckCheckDescription({
  required String? selected,
  required String otherText,
  String otherLabel = ncrRecheckChoiceOther,
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

String recheckOutcomeHintBs(String outcome) {
  switch (outcome) {
    case 'Odobreno':
      return 'Ishod: ponovna kontrola odobrena — neusaglašenost se može zatvoriti.';
    case 'Djelimično odobreno':
      return 'Ishod: djelimično odobreno — neusaglašenost ostaje otvorena i '
          'traži se nova odluka za odbijene komade.';
    case 'Nije odobreno':
      return 'Ishod: ponovna kontrola nije odobrena — slijedi nova odluka '
          'za odbijene komade.';
    default:
      return 'Odaberi ishod ponovne kontrole.';
  }
}
