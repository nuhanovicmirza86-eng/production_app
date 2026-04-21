/// Vrsta dokumenta u QMS dokumentaciji (radni uput, pakovanje, obrazac …).
/// Kasnije: veza na `products` i Callable za pohranu.
enum QmsDocumentKind {
  workInstruction,
  packingInstruction,
  form,
  other,
}

extension QmsDocumentKindLabels on QmsDocumentKind {
  String get label => switch (this) {
        QmsDocumentKind.workInstruction => 'Radni uput',
        QmsDocumentKind.packingInstruction => 'Uput za pakovanje',
        QmsDocumentKind.form => 'Obrazac',
        QmsDocumentKind.other => 'Ostalo',
      };

  String get shortLabel => switch (this) {
        QmsDocumentKind.workInstruction => 'Radni uputi',
        QmsDocumentKind.packingInstruction => 'Pakovanje',
        QmsDocumentKind.form => 'Obrasci',
        QmsDocumentKind.other => 'Ostalo',
      };

  /// Vrijednost u Callable / Firestore (`quality_qms_writes`).
  String get apiValue => switch (this) {
        QmsDocumentKind.workInstruction => 'work_instruction',
        QmsDocumentKind.packingInstruction => 'packing_instruction',
        QmsDocumentKind.form => 'form',
        QmsDocumentKind.other => 'other',
      };
}

QmsDocumentKind? parseQmsDocumentKindApi(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final k in QmsDocumentKind.values) {
    if (k.apiValue == raw) return k;
  }
  return null;
}
