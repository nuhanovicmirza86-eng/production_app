/// Format / parse komadnih (integer) količina u evidence UI (M1-I2-F3 / F4 / F5).
library;

const Set<String> structuredPieceQuantityFieldKeys = {
  'unitsChecked',
  'unitsAccepted',
  'unitsRejected',
  'goodQty',
  'scrapQty',
  'reworkQty',
  'okQty',
  'qtySubmitted',
  'processedQty',
};

/// packaging_control: prazno Prihvaćeno / Odbijeno = 0 (M1-I2-F4).
const Set<String> packagingZeroDefaultQuantityFieldKeys = {
  'unitsAccepted',
  'unitsRejected',
};

const Set<String> packagingUnitsBalanceFieldKeys = {
  'unitsChecked',
  'unitsAccepted',
  'unitsRejected',
};

bool isStructuredPieceQuantityField(String fieldKey) =>
    structuredPieceQuantityFieldKeys.contains(fieldKey.trim());

bool isPackagingCheckLinesTable(String tableKey) =>
    tableKey.trim() == 'packaging_check_lines';

bool isPackagingZeroDefaultQuantityField({
  required String tableKey,
  required String fieldKey,
}) =>
    isPackagingCheckLinesTable(tableKey) &&
    packagingZeroDefaultQuantityFieldKeys.contains(fieldKey.trim());

/// Prikaz: `12` umjesto `12.0` / `12,0`.
String formatStructuredPieceQuantity(dynamic raw) {
  if (raw == null) return '';
  if (raw is num) {
    if (raw == raw.roundToDouble()) return raw.toInt().toString();
    return raw.toString();
  }
  final text = raw.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return '';
  final n = num.tryParse(text);
  if (n == null) return text;
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

/// Parse za spremanje: cijeli broj kad je komadno polje.
num? parseStructuredPieceQuantity(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final n = num.tryParse(normalized);
  if (n == null || n.isNaN) return null;
  if (n == n.roundToDouble()) return n.toInt();
  return n;
}

/// Prazno → 0 za Prihvaćeno / Odbijeno u packaging redu.
num packagingQuantityOrZero(dynamic raw) {
  if (raw == null) return 0;
  if (raw is num) {
    if (raw.isNaN || raw < 0) return 0;
    return raw == raw.roundToDouble() ? raw.toInt() : raw;
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return 0;
  final n = parseStructuredPieceQuantity(text);
  if (n == null || n < 0) return 0;
  return n;
}

/// Rezultat validacije: jasna poruka + polja za inline error (M1-I2-F5).
class PackagingUnitsBalanceIssue {
  const PackagingUnitsBalanceIssue({
    required this.message,
    this.errorFieldKeys = packagingUnitsBalanceFieldKeys,
  });

  final String message;
  final Set<String> errorFieldKeys;
}

/// Provjereno == Prihvaćeno + Odbijeno (prazno = 0).
PackagingUnitsBalanceIssue? packagingUnitsBalanceIssue({
  required dynamic unitsChecked,
  required dynamic unitsAccepted,
  required dynamic unitsRejected,
}) {
  final checked = packagingQuantityOrZero(unitsChecked);
  final accepted = packagingQuantityOrZero(unitsAccepted);
  final rejected = packagingQuantityOrZero(unitsRejected);
  final sum = accepted + rejected;
  if ((sum - checked).abs() <= 0.000001) return null;
  final sumLabel = formatStructuredPieceQuantity(sum);
  final checkedLabel = formatStructuredPieceQuantity(checked);
  return PackagingUnitsBalanceIssue(
    message:
        'Greška: Prihvaćeno + Odbijeno = $sumLabel, a Provjereno = $checkedLabel.',
  );
}

/// Prihvaćeno + Odbijeno == Provjereno (prazno = 0) — poruka za listu redova.
String? validatePackagingUnitsBalance({
  required String tableLabel,
  required int rowIndexOneBased,
  required dynamic unitsChecked,
  required dynamic unitsAccepted,
  required dynamic unitsRejected,
}) {
  final issue = packagingUnitsBalanceIssue(
    unitsChecked: unitsChecked,
    unitsAccepted: unitsAccepted,
    unitsRejected: unitsRejected,
  );
  if (issue == null) return null;
  return '$tableLabel, red $rowIndexOneBased: ${issue.message}';
}
