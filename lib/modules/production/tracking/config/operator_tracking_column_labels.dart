import '../models/production_operator_tracking_entry.dart';

/// Ključ u `companies` / sesiji: mapa [operatorTrackingColumnKeys] → prilagođeni naslov kolone.
const String operatorTrackingColumnLabelsKey = 'operatorTrackingColumnLabels';

/// Ključ u `companies` / sesiji: UI postavke (npr. prikaz sistemskih oznaka u zaglavlju).
const String operatorTrackingColumnUiKey = 'operatorTrackingColumnUi';

/// Stabilni identifikatori kolona (isti u kodu, pravilima i dokumentaciji).
abstract class OperatorTrackingColumnKeys {
  static const rowIndex = 'rowIndex';
  static const prepDateTime = 'prepDateTime';
  static const lineOrBatchRef = 'lineOrBatchRef';
  static const releaseToolOrRodRef = 'releaseToolOrRodRef';
  static const itemCode = 'itemCode';
  static const itemName = 'itemName';
  static const customerName = 'customerName';
  static const goodQty = 'goodQty';
  static const scrapTotal = 'scrapTotal';
  static const rawMaterialOrder = 'rawMaterialOrder';
  static const rawWorkOperator = 'rawWorkOperator';
  static const preparedBy = 'preparedBy';

  /// Jednokratna ispravka vlastitog zapisa (ikonica u retku).
  static const actions = 'actions';

  /// PDF dnevnog lista (dodatne kolone u odnosu na tablicu na stanici).
  static const quantityTotal = 'quantityTotal';
  static const unit = 'unit';
  static const productionOrderNumber = 'productionOrderNumber';
  static const commercialOrderNumber = 'commercialOrderNumber';
  static const notes = 'notes';
  static const operatorEmail = 'operatorEmail';
}

/// Sistemska oznaka (polje / koncept) — prikazuje se u drugom redu kad admin uključi prikaz.
String operatorTrackingColumnSystemLine(String columnKey) => columnKey;

class OperatorTrackingColumnUi {
  final bool showSystemHeaders;

  const OperatorTrackingColumnUi({this.showSystemHeaders = false});

  factory OperatorTrackingColumnUi.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const OperatorTrackingColumnUi();
    final v = m['showSystemHeaders'];
    return OperatorTrackingColumnUi(showSystemHeaders: v == true);
  }
}

Map<String, String> parseOperatorTrackingColumnLabels(
  Map<String, dynamic> companyData,
) {
  final raw = companyData[operatorTrackingColumnLabelsKey];
  if (raw is! Map) return {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final key = k.toString().trim();
    final val = v.toString().trim();
    if (key.isEmpty || val.isEmpty) return;
    out[key] = val;
  });
  return out;
}

OperatorTrackingColumnUi parseOperatorTrackingColumnUi(
  Map<String, dynamic> companyData,
) {
  final raw = companyData[operatorTrackingColumnUiKey];
  if (raw is! Map) return const OperatorTrackingColumnUi();
  return OperatorTrackingColumnUi.fromMap(Map<String, dynamic>.from(raw));
}

/// Ugrađeni (default) naslovi kolona — koriste se kad kompanija nema svoj naziv.
String defaultOperatorTrackingColumnTitle(
  String columnKey, {
  required String phase,
  required String unit,
}) {
  switch (columnKey) {
    case OperatorTrackingColumnKeys.rowIndex:
      return 'R.br.';
    case OperatorTrackingColumnKeys.prepDateTime:
      return 'Datum i vrijeme';
    case OperatorTrackingColumnKeys.lineOrBatchRef:
      return 'Palica / šarž / lin.';
    case OperatorTrackingColumnKeys.releaseToolOrRodRef:
      return 'Alat / pal. (puštanje)';
    case OperatorTrackingColumnKeys.itemCode:
      return 'Šifra kom.';
    case OperatorTrackingColumnKeys.itemName:
      return 'Naziv kom.';
    case OperatorTrackingColumnKeys.customerName:
      return 'Kupac';
    case OperatorTrackingColumnKeys.goodQty:
      switch (phase) {
        case ProductionOperatorTrackingEntry.phaseFirstControl:
        case ProductionOperatorTrackingEntry.phaseFinalControl:
          return 'Dobro ($unit)';
        default:
          return 'Pripr. ($unit)';
      }
    case OperatorTrackingColumnKeys.scrapTotal:
      return 'Škart ($unit)';
    case OperatorTrackingColumnKeys.rawMaterialOrder:
      return 'Nalog sirov.';
    case OperatorTrackingColumnKeys.rawWorkOperator:
      return 'Op. izrada';
    case OperatorTrackingColumnKeys.preparedBy:
      return 'Pripremio';
    case OperatorTrackingColumnKeys.actions:
      return 'Radnja';
    case OperatorTrackingColumnKeys.quantityTotal:
      return 'Ukup.';
    case OperatorTrackingColumnKeys.unit:
      return 'MJ';
    case OperatorTrackingColumnKeys.productionOrderNumber:
      return 'PN';
    case OperatorTrackingColumnKeys.commercialOrderNumber:
      return 'Nar.';
    case OperatorTrackingColumnKeys.notes:
      return 'Napomena';
    case OperatorTrackingColumnKeys.operatorEmail:
      return 'Operater';
    default:
      return columnKey;
  }
}

/// Tooltip za zaglavlje (kad kompanija nema svoj); ostaje stabilan u odnosu na prilagođeni naslov.
String defaultOperatorTrackingColumnTooltip(
  String columnKey, {
  required String phase,
}) {
  switch (columnKey) {
    case OperatorTrackingColumnKeys.rowIndex:
      return 'Redni broj unosa (1 = zadnji spremljen u danu)';
    case OperatorTrackingColumnKeys.prepDateTime:
      return 'Automatski se postavlja pri spremanju';
    case OperatorTrackingColumnKeys.lineOrBatchRef:
      return 'Broj palice, šarže ili linije';
    case OperatorTrackingColumnKeys.releaseToolOrRodRef:
      return 'Broj alata ili palice na koju je pripremljen proizvod za puštanje u proizvodnju';
    case OperatorTrackingColumnKeys.itemCode:
      return 'Šifra komada';
    case OperatorTrackingColumnKeys.itemName:
      return 'Naziv komada';
    case OperatorTrackingColumnKeys.customerName:
      return 'Kupac';
    case OperatorTrackingColumnKeys.goodQty:
      switch (phase) {
        case ProductionOperatorTrackingEntry.phaseFirstControl:
          return 'Prihvaćena količina poluproizvoda (pločica iznad)';
        case ProductionOperatorTrackingEntry.phaseFinalControl:
          return 'Prihvaćena količina gotovog proizvoda (pločica iznad)';
        default:
          return 'Količina pripremljenih (odabir pločicom iznad)';
      }
    case OperatorTrackingColumnKeys.scrapTotal:
      return 'Ukupna količina škarta';
    case OperatorTrackingColumnKeys.rawMaterialOrder:
      return 'Broj naloga izrade sirovih komada';
    case OperatorTrackingColumnKeys.rawWorkOperator:
      return 'Ime operatera na izradi sirovih komada';
    case OperatorTrackingColumnKeys.preparedBy:
      return 'Ime i prezime proizvodnog operatera koji je pripremio komade';
    case OperatorTrackingColumnKeys.actions:
      return 'Jednokratna ispravka vlastitog unosa (audit u sustavu)';
    case OperatorTrackingColumnKeys.quantityTotal:
      return 'Ukupna količina na redu (dobro + škart)';
    case OperatorTrackingColumnKeys.unit:
      return 'Jedinica mjere';
    case OperatorTrackingColumnKeys.productionOrderNumber:
      return 'Proizvodni nalog (PN)';
    case OperatorTrackingColumnKeys.commercialOrderNumber:
      return 'Komercijalni nalog';
    case OperatorTrackingColumnKeys.notes:
      return 'Napomena na unosu';
    case OperatorTrackingColumnKeys.operatorEmail:
      return 'Korisnik koji je spremio unos';
    default:
      return columnKey;
  }
}

/// Prikazni naslov: prvo kompanijski, inače default.
String resolvedOperatorTrackingColumnTitle(
  String columnKey, {
  required Map<String, String> companyLabels,
  required String phase,
  required String unit,
}) {
  final c = companyLabels[columnKey]?.trim() ?? '';
  if (c.isNotEmpty) return c;
  return defaultOperatorTrackingColumnTitle(
    columnKey,
    phase: phase,
    unit: unit,
  );
}

String resolvedOperatorTrackingColumnTooltip(
  String columnKey, {
  required String phase,
}) {
  final base = defaultOperatorTrackingColumnTooltip(columnKey, phase: phase);
  final sys = operatorTrackingColumnSystemLine(columnKey);
  return '$base\n\nSistemsko polje: $sys';
}
