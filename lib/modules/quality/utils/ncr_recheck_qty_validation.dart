/// M1-I12-D — validacija količina evidencije ponovne kontrole (korak 9).
String? ncrRecheckQtySumDetailError({
  required int checked,
  required int ok,
  required int rejected,
  required int separated,
}) {
  if (checked < 1) return null;
  if (ok + rejected + separated == checked) return null;
  return 'Zbir ispravnih, ponovo odbijenih i odvojenih komada mora biti '
      'jednak broju kontrolisanih komada.\n'
      'Trenutno: $ok + $rejected + $separated = ${ok + rejected + separated}, '
      'a kontrolisano je $checked.';
}

/// Provjera usklađenosti odabranog ishoda s količinama.
String? ncrRecheckOutcomeMismatchError({
  required String? outcome,
  required int ok,
  required int rejected,
}) {
  final selected = (outcome ?? '').trim();
  if (selected.isEmpty) return null;
  switch (selected) {
    case 'Odobreno':
      if (rejected > 0) {
        return 'Za ishod „Odobreno” broj ponovo odbijenih komada mora biti 0.';
      }
      return null;
    case 'Djelimično odobreno':
      if (ok < 1 || rejected < 1) {
        return 'Za „Djelimično odobreno” mora postojati barem jedan ispravan '
            'i jedan ponovo odbijen komad.';
      }
      return null;
    case 'Nije odobreno':
      if (rejected < 1 || ok > 0) {
        return 'Za „Nije odobreno” nema ispravnih komada — svi moraju biti '
            'ponovo odbijeni ili odvojeni.';
      }
      return null;
    default:
      return null;
  }
}
