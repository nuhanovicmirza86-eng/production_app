/// M1-I11-C — klasifikacija sljedivosti na BOM stavci (poslovni kodovi + BS labele).
library;

/// Vrsta stavke (kanonski kodovi).
const String bomItemKindRawMaterial = 'raw_material';
const String bomItemKindSemiFinished = 'semi_finished';
const String bomItemKindPurchasedComponent = 'purchased_component';
const String bomItemKindPackaging = 'packaging';
const String bomItemKindAuxiliary = 'auxiliary';
const String bomItemKindDocumentLabel = 'document_label';

const List<String> kBomItemKindCodes = [
  bomItemKindRawMaterial,
  bomItemKindSemiFinished,
  bomItemKindPurchasedComponent,
  bomItemKindPackaging,
  bomItemKindAuxiliary,
  bomItemKindDocumentLabel,
];

const Map<String, String> kBomItemKindLabelsBs = {
  bomItemKindRawMaterial: 'Sirovina',
  bomItemKindSemiFinished: 'Poluproizvod',
  bomItemKindPurchasedComponent: 'Kupljena komponenta',
  bomItemKindPackaging: 'Ambalaža',
  bomItemKindAuxiliary: 'Pomoćni materijal',
  bomItemKindDocumentLabel: 'Dokument / etiketa',
};

/// Način sljedivosti.
const String bomTraceabilityWmsLot = 'wms_lot';
const String bomTraceabilityInternalSeries = 'internal_series';
const String bomTraceabilitySupplierLot = 'supplier_lot';
const String bomTraceabilityNone = 'none';

const List<String> kBomTraceabilityModeCodes = [
  bomTraceabilityWmsLot,
  bomTraceabilityInternalSeries,
  bomTraceabilitySupplierLot,
  bomTraceabilityNone,
];

const Map<String, String> kBomTraceabilityModeLabelsBs = {
  bomTraceabilityWmsLot: 'WMS lot',
  bomTraceabilityInternalSeries: 'Interna serija',
  bomTraceabilitySupplierLot: 'Dobavljački lot',
  bomTraceabilityNone: 'Bez lota',
};

/// Firestore / picker ključevi na `bom_items`.
const String bomItemFieldKind = 'bomItemKind';
const String bomItemFieldTraceabilityMode = 'traceabilityMode';
const String bomItemFieldLotRequired = 'lotRequired';

/// Snapshot ključevi u OMP `fieldValues`.
const String ompBomItemKindSnapshot = 'bomItemKindSnapshot';
const String ompTraceabilityModeSnapshot = 'traceabilityModeSnapshot';
const String ompLotRequiredSnapshot = 'lotRequiredSnapshot';

const String ompLotNotRequiredBanner =
    'Lot nije obavezan za ovu BOM stavku';

/// Siguran default za stare BOM stavke bez klasifikacije.
const String bomItemKindDefault = bomItemKindRawMaterial;
const String bomTraceabilityModeDefault = bomTraceabilityWmsLot;
const bool bomLotRequiredDefault = true;

String? normalizeBomItemKind(dynamic raw) {
  final c = (raw ?? '').toString().trim();
  if (c.isEmpty) return null;
  return kBomItemKindCodes.contains(c) ? c : null;
}

String? normalizeBomTraceabilityMode(dynamic raw) {
  final c = (raw ?? '').toString().trim();
  if (c.isEmpty) return null;
  return kBomTraceabilityModeCodes.contains(c) ? c : null;
}

/// [null] ako vrijednost nije eksplicitno postavljena.
bool? normalizeBomLotRequired(dynamic raw) {
  if (raw == null) return null;
  if (raw is bool) return raw;
  final s = raw.toString().trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s == 'true' || s == '1' || s == 'da' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'ne' || s == 'no') return false;
  return null;
}

/// Resolve s defaultom (stare stavke → lot obavezan + WMS lot).
({String kind, String mode, bool lotRequired}) resolveBomItemTraceability(
  Map<String, dynamic>? item,
) {
  final kind = normalizeBomItemKind(item?[bomItemFieldKind]) ?? bomItemKindDefault;
  var mode = normalizeBomTraceabilityMode(item?[bomItemFieldTraceabilityMode]) ??
      bomTraceabilityModeDefault;
  var lotRequired =
      normalizeBomLotRequired(item?[bomItemFieldLotRequired]) ?? bomLotRequiredDefault;

  // Konzistentnost: Bez lota ⇒ lot nije obavezan.
  if (mode == bomTraceabilityNone) {
    lotRequired = false;
  }
  // Lot obavezan ne može biti uz način „Bez lota”.
  if (lotRequired && mode == bomTraceabilityNone) {
    mode = bomTraceabilityModeDefault;
  }

  return (kind: kind, mode: mode, lotRequired: lotRequired);
}

String bomItemKindLabelBs(String? code) {
  final c = normalizeBomItemKind(code);
  if (c == null) return '—';
  return kBomItemKindLabelsBs[c] ?? '—';
}

String bomTraceabilityModeLabelBs(String? code) {
  final c = normalizeBomTraceabilityMode(code);
  if (c == null) return '—';
  return kBomTraceabilityModeLabelsBs[c] ?? '—';
}

String bomLotRequiredLabelBs(bool? value) =>
    value == null ? '—' : (value ? 'Da' : 'Ne');

/// Validacija prije snimanja BOM stavke. [null] = OK.
String? validateBomItemTraceabilityForSave({
  required String? kind,
  required String? mode,
  required bool? lotRequired,
}) {
  if (normalizeBomItemKind(kind) == null) {
    return 'Odaberite vrstu stavke.';
  }
  if (normalizeBomTraceabilityMode(mode) == null) {
    return 'Odaberite način sljedivosti.';
  }
  if (lotRequired == null) {
    return 'Odaberite da li je lot obavezan.';
  }
  if (mode == bomTraceabilityNone && lotRequired == true) {
    return 'Za način „Bez lota” lot ne može biti obavezan.';
  }
  if (lotRequired == true && mode == bomTraceabilityNone) {
    return 'Za obavezan lot odaberite način sljedivosti (nije „Bez lota”).';
  }
  return null;
}

/// Da li OMP mora tražiti lot (iz fieldValues snimka ili default).
bool ompLotIsRequired(Map<String, dynamic> fieldValues) {
  final explicit = normalizeBomLotRequired(fieldValues[ompLotRequiredSnapshot]);
  if (explicit != null) return explicit;
  final mode = normalizeBomTraceabilityMode(
    fieldValues[ompTraceabilityModeSnapshot],
  );
  if (mode == bomTraceabilityNone) return false;
  return bomLotRequiredDefault;
}

/// Mapira resolved klasifikaciju u OMP fieldValues snimke.
Map<String, dynamic> ompTraceabilitySnapshotsFromResolved(
  ({String kind, String mode, bool lotRequired}) resolved,
) {
  return {
    ompBomItemKindSnapshot: resolved.kind,
    ompTraceabilityModeSnapshot: resolved.mode,
    ompLotRequiredSnapshot: resolved.lotRequired,
  };
}
