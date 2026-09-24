/// M1-I12-D — validacija količina evidencije dorade (korak 7).
String? ncrReworkQtySumDetailError({
  required int reworked,
  required int separated,
  required int toRecheck,
}) {
  if (reworked < 1) return null;
  if (separated + toRecheck == reworked) return null;
  return 'Zbir odvojenih komada i komada za ponovnu kontrolu mora biti '
      'jednak broju dorađenih komada.\n'
      'Trenutno: $separated + $toRecheck = ${separated + toRecheck}, '
      'a dorađeno je $reworked.';
}
