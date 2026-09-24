/// Format / parse komadnih (integer) količina u evidence UI (M1-I2-F3 / F4 / F5).
library;

const Set<String> structuredPieceQuantityFieldKeys = {
  'unitsChecked',
  'unitsAccepted',
  'unitsRejected',
  'inspectedQty',
  'goodQty',
  'scrapQty',
  'reworkQty',
  'okQty',
  'qtySubmitted',
  'processedQty',
};

/// Finalna kontrola — controlled_items količine (M1-I5-C4).
const Set<String> controlledItemsQtyBalanceFieldKeys = {
  'inspectedQty',
  'goodQty',
  'scrapQty',
  'reworkQty',
};

bool isControlledItemsTable(String tableKey) =>
    tableKey.trim() == 'controlled_items';

/// M1-I5-C4B — detekcija balansa i kad table key / snapshot nije pouzdan.
bool needsControlledItemsQtyBalance({
  required String tableKey,
  String? profileKey,
  Iterable<String> columnKeys = const [],
}) {
  if (isControlledItemsTable(tableKey)) return true;
  if ((profileKey ?? '').trim() == 'final_control') return true;
  final keys = columnKeys.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet();
  return keys.contains('inspectedQty') &&
      keys.contains('goodQty') &&
      keys.contains('scrapQty') &&
      keys.contains('reworkQty');
}

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

/// packaging_control / in_process_quality_check — nema odbijenih / neprolaznih.
const String noDefectReasonCode = 'BEZ_GRESKE';
const String packagingNoDefectReasonCode = noDefectReasonCode;

const Map<String, String> packagingDefectReasonLabels = {
  noDefectReasonCode: 'Bez greške',
  'VIZUELNA_GRESKA': 'Vizuelna greška',
  'DIMENZIJA': 'Dimenzija / tolerancija',
  'BOJA_POVRŠINA': 'Boja / površina',
  'OŠTEĆENJE': 'Oštećenje',
  'KONTAMINACIJA': 'Kontaminacija',
  'NEUSKLADEN_BOM': 'Neusklađenost s specifikacijom',
  'OSTALO': 'Ostalo',
};

String packagingDefectReasonLabel(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '—';
  return packagingDefectReasonLabels[c] ?? c;
}

/// Fail qty = 0 → Bez greške; fail qty > 0 → obavezan stvarni razlog.
void syncZeroFailDefectReasonCode({
  required Map<String, String?> enumSelections,
  required dynamic failQty,
}) {
  final failed = packagingQuantityOrZero(failQty);
  if (failed <= 0) {
    enumSelections['defectReasonCode'] = noDefectReasonCode;
    return;
  }
  final current = (enumSelections['defectReasonCode'] ?? '').trim();
  if (current == noDefectReasonCode) {
    enumSelections['defectReasonCode'] = null;
  }
}

String? zeroFailDefectReasonIssue({
  required dynamic failQty,
  required String? defectReasonCode,
  required String failMessage,
}) {
  final failed = packagingQuantityOrZero(failQty);
  if (failed <= 0) return null;
  final reason = (defectReasonCode ?? '').trim();
  if (reason.isEmpty || reason == noDefectReasonCode) {
    return failMessage;
  }
  return null;
}

/// Odbijeno = 0 → Bez greške; Odbijeno > 0 → obavezan stvarni razlog.
void syncPackagingDefectReasonCode({
  required Map<String, String?> enumSelections,
  required dynamic unitsRejected,
}) {
  syncZeroFailDefectReasonCode(
    enumSelections: enumSelections,
    failQty: unitsRejected,
  );
}

String? packagingDefectReasonIssue({
  required dynamic unitsRejected,
  required String? defectReasonCode,
}) {
  return zeroFailDefectReasonIssue(
    failQty: unitsRejected,
    defectReasonCode: defectReasonCode,
    failMessage: 'Unesite stvarni razlog greške jer postoje odbijeni komadi.',
  );
}

/// Ne prolazi = 0 → Bez greške; Ne prolazi > 0 → obavezan stvarni razlog.
void syncInspectionDefectReasonCode({
  required Map<String, String?> enumSelections,
  required dynamic qtyFail,
}) {
  syncZeroFailDefectReasonCode(
    enumSelections: enumSelections,
    failQty: qtyFail,
  );
}

String? inspectionDefectReasonIssue({
  required dynamic qtyFail,
  required String? defectReasonCode,
}) {
  return zeroFailDefectReasonIssue(
    failQty: qtyFail,
    defectReasonCode: defectReasonCode,
    failMessage:
        'Unesite stvarni razlog greške jer postoje komadi koji ne prolaze.',
  );
}

const String finalControlNoDefectReasonCode = noDefectReasonCode;

/// Škart 0 + Dorada 0 → Bez greške; Škart > 0 ili Dorada > 0 → stvarni razlog.
void syncFinalControlDefectReasonCode({
  required Map<String, String?> enumSelections,
  required dynamic scrapQty,
  required dynamic reworkQty,
}) {
  final failed = packagingQuantityOrZero(scrapQty) +
      packagingQuantityOrZero(reworkQty);
  if (failed <= 0) {
    enumSelections['defectReason'] = noDefectReasonCode;
    return;
  }
  final current = (enumSelections['defectReason'] ?? '').trim();
  if (current == noDefectReasonCode) {
    enumSelections['defectReason'] = null;
  }
}

String? finalControlDefectReasonIssue({
  required dynamic scrapQty,
  required dynamic reworkQty,
  required String? defectReason,
}) {
  final failed = packagingQuantityOrZero(scrapQty) +
      packagingQuantityOrZero(reworkQty);
  if (failed <= 0) return null;
  final reason = (defectReason ?? '').trim();
  if (reason.isEmpty || reason == noDefectReasonCode) {
    return 'Unesite stvarni razlog greške jer postoji škart ili dorada.';
  }
  return null;
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

/// Rezultat validacije balansa Finalne kontrole (M1-I5-C4).
class ControlledItemsQtyBalanceIssue {
  const ControlledItemsQtyBalanceIssue({
    required this.message,
    this.errorFieldKeys = controlledItemsQtyBalanceFieldKeys,
  });

  final String message;
  final Set<String> errorFieldKeys;
}

/// OK + Škart + Dorada == Kontrolisano.
ControlledItemsQtyBalanceIssue? controlledItemsQtyBalanceIssue({
  required dynamic inspectedQty,
  required dynamic goodQty,
  required dynamic scrapQty,
  required dynamic reworkQty,
}) {
  final inspected = packagingQuantityOrZero(inspectedQty);
  final good = packagingQuantityOrZero(goodQty);
  final scrap = packagingQuantityOrZero(scrapQty);
  final rework = packagingQuantityOrZero(reworkQty);
  final sum = good + scrap + rework;
  if ((sum - inspected).abs() <= 0.000001) return null;
  final diff = (sum - inspected).abs();
  final inspectedLabel = formatStructuredPieceQuantity(inspected);
  final sumLabel = formatStructuredPieceQuantity(sum);
  final diffLabel = formatStructuredPieceQuantity(diff);
  return ControlledItemsQtyBalanceIssue(
    message:
        'Količine se ne poklapaju. Zbir OK, škart i dorada mora biti jednak '
        'kontrolisanoj količini.\n'
        'Kontrolisano: $inspectedLabel\n'
        'Zbir OK + škart + dorada: $sumLabel\n'
        'Razlika: $diffLabel',
  );
}

String? validateControlledItemsQtyBalanceRow({
  required String tableLabel,
  required int rowIndexOneBased,
  required dynamic inspectedQty,
  required dynamic goodQty,
  required dynamic scrapQty,
  required dynamic reworkQty,
}) {
  final issue = controlledItemsQtyBalanceIssue(
    inspectedQty: inspectedQty,
    goodQty: goodQty,
    scrapQty: scrapQty,
    reworkQty: reworkQty,
  );
  if (issue == null) return null;
  return '$tableLabel, red $rowIndexOneBased:\n${issue.message}';
}
