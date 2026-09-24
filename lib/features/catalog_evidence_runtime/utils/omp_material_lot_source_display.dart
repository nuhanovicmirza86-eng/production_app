/// M1-I11-B — poslovni prikaz izvora lota (PDF / lista / Detalji).
///
/// Ako postoji lot a izvor nije eksplicitno `wms`, tretira se kao ručni
/// (nije potvrđen kroz WMS) — radi audita i starih zapisa bez polja.
library;

const String ompMaterialLotSourceManualLabel =
    'Ručni unos — nije potvrđen kroz WMS';

const String ompMaterialLotSourceWmsLabel = 'WMS lot (potvrđen)';

/// Kanonski kod izvora: `wms` | `manual` | prazno.
String ompMaterialLotSourceCode(Map<String, dynamic> fieldValues) {
  final raw = (fieldValues['materialLotSource'] ?? '').toString().trim();
  if (raw == 'wms' || raw == 'manual') return raw;
  final docId = (fieldValues['inventoryLotDocId'] ?? '').toString().trim();
  if (docId.isNotEmpty) return 'wms';
  return '';
}

/// Label za PDF / Detalji. [null] ako nema lota.
String? ompMaterialLotSourceDisplayLabel(Map<String, dynamic> fieldValues) {
  final lot = (fieldValues['materialLot'] ?? '').toString().trim();
  if (lot.isEmpty) return null;
  final code = ompMaterialLotSourceCode(fieldValues);
  if (code == 'wms') return ompMaterialLotSourceWmsLabel;
  // manual ili nedostaje izvor → jasno označi kao nepotvrđen
  return ompMaterialLotSourceManualLabel;
}

bool ompMaterialLotIsManualOrUnconfirmed(Map<String, dynamic> fieldValues) {
  final lot = (fieldValues['materialLot'] ?? '').toString().trim();
  if (lot.isEmpty) return false;
  return ompMaterialLotSourceCode(fieldValues) != 'wms';
}

/// Lista/tablica: lot + oznaka ručnog unosa kad nije WMS.
String ompMaterialLotListDisplay(Map<String, dynamic> fieldValues) {
  final lot = (fieldValues['materialLot'] ?? '').toString().trim();
  if (lot.isEmpty) return '—';
  if (ompMaterialLotIsManualOrUnconfirmed(fieldValues)) {
    return '$lot (ručno)';
  }
  return lot;
}
