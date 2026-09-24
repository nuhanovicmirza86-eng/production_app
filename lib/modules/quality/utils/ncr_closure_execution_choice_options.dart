/// M1-I12-D — kontrolisani izbori za zatvaranje neusaglašenosti.

const String ncrClosureCapaRequired = 'required';
const String ncrClosureCapaNotRequired = 'not_required';
const String ncrClosureCapaAlreadyExists = 'already_exists';

const List<MapEntry<String, String>> ncrClosureCapaDecisionOptions = [
  MapEntry(ncrClosureCapaRequired, 'CAPA potrebna'),
  MapEntry(ncrClosureCapaNotRequired, 'CAPA nije potrebna'),
  MapEntry(ncrClosureCapaAlreadyExists, 'CAPA već postoji'),
];

const String ncrClosureReasonOther = 'other';

const List<MapEntry<String, String>> ncrClosureCapaNotRequiredReasonOptions = [
  MapEntry('minor_rework', 'Manje odstupanje otklonjeno doradom'),
  MapEntry('recheck_confirms', 'Ponovna kontrola potvrđuje ispravnost'),
  MapEntry('no_repeat', 'Nema ponavljanja problema'),
  MapEntry(ncrClosureReasonOther, 'Drugo'),
];

String? resolveNcrClosureNotRequiredReason({
  required String? reasonKey,
  required String otherText,
}) {
  final key = (reasonKey ?? '').trim();
  if (key.isEmpty) return null;
  if (key == ncrClosureReasonOther) {
    final custom = otherText.trim();
    if (custom.length < 3) return null;
    return custom;
  }
  for (final e in ncrClosureCapaNotRequiredReasonOptions) {
    if (e.key == key) return e.value;
  }
  return null;
}
