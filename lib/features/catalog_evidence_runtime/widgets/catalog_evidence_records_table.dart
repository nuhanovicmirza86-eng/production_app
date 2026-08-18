import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/standard_table_components.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../station_evidence/screens/profile_driven_evidence_detail_screen.dart';

/// Veličina kolone u standardnoj tabeli evidencija (flex + mobile min-width).
enum CatalogEvidenceColumnSize {
  narrow,
  medium,
  wide,
}

/// Kanonsko pravilo poravnanja:
/// - tekstualne kolone → lijevo
/// - brojčane kolone → desno
/// - status → lijevo (badge)
/// - Detalji → centar (akcija)
class CatalogEvidenceTableColumn {
  const CatalogEvidenceTableColumn({
    required this.id,
    required this.label,
    this.size = CatalogEvidenceColumnSize.medium,
    this.align = TextAlign.left,
    this.numeric = false,
  });

  final String id;
  final String label;
  final CatalogEvidenceColumnSize size;
  final TextAlign align;
  final bool numeric;

  int get flex => switch (size) {
        CatalogEvidenceColumnSize.narrow => 4,
        CatalogEvidenceColumnSize.medium => 7,
        CatalogEvidenceColumnSize.wide => 9,
      };

  double get minWidth => catalogEvidenceColumnMinWidth(id, size: size);

  /// Širina kolone u layoutu — dovoljna za header (1–2 riječi po redu) i sadržaj.
  double get layoutWidth {
    final dataWidth = minWidth;
    final headerWidth = catalogEvidenceHeaderLayoutWidth(label);
    return math.max(dataWidth, headerWidth);
  }
}

CatalogEvidenceTableColumn _textColumn({
  required String id,
  required String label,
  CatalogEvidenceColumnSize size = CatalogEvidenceColumnSize.medium,
}) {
  return CatalogEvidenceTableColumn(
    id: id,
    label: label,
    size: size,
  );
}

CatalogEvidenceTableColumn _numericColumn({
  required String id,
  required String label,
}) {
  return CatalogEvidenceTableColumn(
    id: id,
    label: label,
    size: CatalogEvidenceColumnSize.narrow,
    align: TextAlign.right,
    numeric: true,
  );
}

/// M1-I1-F3 — zajedničke kolone na kraju svake evidence tabele (isti redoslijed).
const CatalogEvidenceTableColumn _standardEvidenceTimeColumn =
    CatalogEvidenceTableColumn(
  id: 'evidence_time',
  label: 'Vrijeme evidencije',
  size: CatalogEvidenceColumnSize.medium,
);

const CatalogEvidenceTableColumn _standardOperatorColumn =
    CatalogEvidenceTableColumn(
  id: 'operator',
  label: 'Operater',
);

const CatalogEvidenceTableColumn _standardStatusColumn = CatalogEvidenceTableColumn(
  id: 'status',
  label: 'Status',
  size: CatalogEvidenceColumnSize.narrow,
);

const CatalogEvidenceTableColumn _standardDetailsColumn = CatalogEvidenceTableColumn(
  id: 'details',
  label: 'Detalji',
  size: CatalogEvidenceColumnSize.narrow,
  align: TextAlign.center,
);

/// Kolone koje nikad ne smiju ostati u poslovnom dijelu — idu isključivo u trailer.
const Set<String> _catalogEvidenceCommonColumnIds = {
  'evidence_time',
  'measured_at',
  'measuredAt',
  'date',
  'time',
  'operator',
  'status',
  'details',
};

/// Poslovne kolone + uvijek isti kraj: Vrijeme evidencije → Operater → Status → Detalji.
List<CatalogEvidenceTableColumn> _appendStandardCommonColumns(
  List<CatalogEvidenceTableColumn> businessColumns,
) {
  final filtered = businessColumns
      .where((column) => !_catalogEvidenceCommonColumnIds.contains(column.id))
      .toList(growable: false);
  return [
    ...filtered,
    _standardEvidenceTimeColumn,
    _standardOperatorColumn,
    _standardStatusColumn,
    _standardDetailsColumn,
  ];
}

bool _usesProfileOperatorFieldColumns(String profileKey) {
  switch (profileKey.trim()) {
    case 'chemical_dosing':
    case 'wastewater_treatment':
      return true;
    default:
      return false;
  }
}

/// Poslovne kolone (bez vremena/operatera/statusa — F3 trailer).
const List<String> _chemicalDosingTableFieldKeys = [
  'chemicalId',
  'dosedQuantity',
  'unit',
  'workBathId',
  'operatorComment',
];

const List<String> _wastewaterTableFieldKeys = [
  'treatmentType',
  'treatedQuantity',
  'reactorNumber',
  'phValue',
  'finalNeutralizationRedoxMv',
  'sludgeQuantity',
  'operatorComment',
];

List<String> _profileOperatorTableFieldKeys(String profileKey) {
  switch (profileKey.trim()) {
    case 'chemical_dosing':
      return _chemicalDosingTableFieldKeys;
    case 'wastewater_treatment':
      return _wastewaterTableFieldKeys;
    default:
      return const [];
  }
}

CatalogEvidenceTableColumn _columnForProfileField(
  ProductionStationProfileField field,
) {
  final id = field.key;
  final label = _tableLabelForProfileField(field);

  if (field.type == 'number') {
    return _numericColumn(id: id, label: label);
  }
  if (field.type == 'datetime') {
    return _textColumn(id: id, label: label);
  }
  if (field.type == 'text' ||
      field.key == 'operatorComment' ||
      field.key == 'dosingReason' ||
      field.key == 'measurementReason' ||
      field.key == 'chemicalUsedNote') {
    return _textColumn(
      id: id,
      label: label,
      size: CatalogEvidenceColumnSize.wide,
    );
  }
  if (field.type == 'enum' &&
      (field.key == 'reactorNumber' ||
          field.key == 'heavyMetalsPresent' ||
          field.key == 'unit')) {
    return _textColumn(
      id: id,
      label: label,
      size: CatalogEvidenceColumnSize.narrow,
    );
  }
  return _textColumn(id: id, label: label);
}

String _tableLabelForProfileField(ProductionStationProfileField field) {
  final fromKey = _tableLabelForFieldKey(field.key);
  if (fromKey != field.key) return fromKey;
  final label = field.label.trim();
  return label.isEmpty ? field.key : label;
}

List<CatalogEvidenceTableColumn> _profileOperatorFieldColumns(
  ProductionStationProfileCatalogEntry profile,
) {
  final fieldKeys = _profileOperatorTableFieldKeys(profile.profileKey);
  final fieldsByKey = {
    for (final field in profile.fields) field.key: field,
  };
  final columns = <CatalogEvidenceTableColumn>[];
  final isWastewater = profile.profileKey.trim() == 'wastewater_treatment';
  final isDosing = profile.profileKey.trim() == 'chemical_dosing';
  for (final key in fieldKeys) {
    if (_catalogEvidenceCommonColumnIds.contains(key)) continue;
    final field = fieldsByKey[key];
    if (isWastewater) {
      columns.add(_wastewaterColumnForTableKey(key, field));
      continue;
    }
    if (isDosing && key == 'workBathId') {
      columns.add(
        _textColumn(
          id: key,
          label: 'Procesna tačka',
          size: CatalogEvidenceColumnSize.wide,
        ),
      );
      continue;
    }
    if (isDosing && key == 'dosedQuantity') {
      columns.add(_numericColumn(id: key, label: 'Količina'));
      continue;
    }
    if (isDosing && key == 'unit') {
      columns.add(
        _textColumn(
          id: key,
          label: 'Jedinica',
          size: CatalogEvidenceColumnSize.narrow,
        ),
      );
      continue;
    }
    if (field == null) continue;
    columns.add(_columnForProfileField(field));
  }
  return _appendStandardCommonColumns(columns);
}

const Set<String> _wastewaterNumericTableFieldKeys = {
  'treatedQuantity',
  'limeQuantity',
  'sodiumMetabisulfiteQuantity',
  'sodiumHydroxideQuantity',
  'phValue',
  'temperatureC',
  'sludgeQuantity',
  'finalNeutralizationPh',
  'finalNeutralizationRedoxMv',
};

CatalogEvidenceTableColumn _wastewaterColumnForTableKey(
  String key,
  ProductionStationProfileField? field,
) {
  if (key == 'treatmentType') {
    return _textColumn(
      id: key,
      label: _tableLabelForFieldKey(key),
      size: CatalogEvidenceColumnSize.wide,
    );
  }
  if (field != null) {
    return _columnForProfileField(field);
  }
  final label = _tableLabelForFieldKey(key);
  if (_wastewaterNumericTableFieldKeys.contains(key)) {
    return _numericColumn(id: key, label: label);
  }
  if (key == 'operatorComment') {
    return _textColumn(
      id: key,
      label: label,
      size: CatalogEvidenceColumnSize.wide,
    );
  }
  if (key == 'reactorNumber' ||
      key == 'heavyMetalsPresent' ||
      key == 'unit') {
    return _textColumn(
      id: key,
      label: label,
      size: CatalogEvidenceColumnSize.narrow,
    );
  }
  return _textColumn(id: key, label: label);
}

String _tableLabelForFieldKey(String key) {
  switch (key) {
    case 'treatmentType':
      return 'Vrsta obrade';
    case 'treatedQuantity':
      return 'Količina';
    case 'unit':
      return 'Jed.';
    case 'reactorNumber':
      return 'Reaktor';
    case 'limeQuantity':
      return 'Kreč kg';
    case 'sodiumMetabisulfiteQuantity':
      return 'Na₂S₂O₅ kg';
    case 'sodiumHydroxideQuantity':
      return 'NaOH kg';
    case 'heavyMetalsPresent':
      return 'Teški metali';
    case 'phValue':
      return 'pH';
    case 'temperatureC':
      return 'Temp. °C';
    case 'sludgeQuantity':
      return 'Talog';
    case 'finalNeutralizationPh':
      return 'pH neutral.';
    case 'finalNeutralizationRedoxMv':
      return 'Redox';
    case 'operatorComment':
      return 'Komentar';
    case 'measuredAt':
    case 'evidence_time':
      return 'Vrijeme evidencije';
    case 'chemicalId':
      return 'Hemikalija';
    case 'workBathId':
      return 'Procesna tačka';
    case 'dosedQuantity':
      return 'Količina';
    default:
      return key;
  }
}

const double _catalogEvidenceNarrowTableBreakpoint = 600;
const double _catalogEvidenceHeaderCharWidth = 6.3;
const double _catalogEvidenceRecordLimitToolbarBreakpoint = 520;

/// Širina tabele = tačan zbir kolona (scroll završava na zadnjoj koloni, bez praznog desno).
/// Globalno za sve profile koji koriste [CatalogEvidenceRecordsTable] (F1H-R2).
double _effectiveTableLayoutWidth(List<CatalogEvidenceTableColumn> columns) {
  return columns.fold<double>(
    0,
    (sum, column) => sum + column.layoutWidth,
  );
}

/// Horizontalni scroll kad sadržaj ne stane — nije vezano za pojedinačni profileKey.
bool _useFixedWidthTableLayout({
  required List<CatalogEvidenceTableColumn> columns,
  required double maxWidth,
}) {
  final tableLayoutWidth = _effectiveTableLayoutWidth(columns);
  return tableLayoutWidth > maxWidth + 1 ||
      maxWidth < _catalogEvidenceNarrowTableBreakpoint;
}

/// Standardni izbor broja zadnjih zapisa u tabeli evidencija.
const List<int> catalogEvidenceRecordLimitOptions = [10, 25, 50, 100];

/// Zadani broj zatvorenih zapisa u tabeli evidencija.
const int catalogEvidenceDefaultRecordLimit = 25;

/// Minimalna širina headera da se label ne lomi po slovima (max 2 reda po riječima).
double catalogEvidenceHeaderLayoutWidth(String label) {
  final normalized = label.replaceAll('\n', ' ').trim();
  if (normalized.isEmpty) return 72;

  const pad = StandardTableMetrics.padH * 2;
  final words = normalized.split(RegExp(r'\s+'));
  final longestWord = words.fold<int>(
    0,
    (maxLen, word) => word.length > maxLen ? word.length : maxLen,
  );
  final longestWordWidth = longestWord * _catalogEvidenceHeaderCharWidth + pad;
  final singleLineWidth = normalized.length * _catalogEvidenceHeaderCharWidth + pad;

  if (normalized.length <= 14) {
    return singleLineWidth.clamp(56.0, 136.0);
  }

  final mid = (words.length / 2).ceil();
  final line1 = words.take(mid).join(' ');
  final line2 = words.skip(mid).join(' ');
  final line1Width = line1.length * _catalogEvidenceHeaderCharWidth + pad;
  final line2Width = line2.length * _catalogEvidenceHeaderCharWidth + pad;

  return [
    longestWordWidth,
    line1Width,
    line2Width,
    singleLineWidth,
  ].reduce(math.max).clamp(72.0, 148.0);
}

/// Minimalna širina kolone kad je tabela u horizontalnom scroll modu (mobile).
double catalogEvidenceColumnMinWidth(
  String columnId, {
  CatalogEvidenceColumnSize size = CatalogEvidenceColumnSize.medium,
}) {
  switch (columnId.trim()) {
    case 'measuredAt':
    case 'measured_at':
    case 'evidence_time':
      return 128;
    case 'workBathId':
    case 'work_bath':
    case 'chemicalId':
    case 'chemical':
    case 'treatmentType':
      return 140;
    case 'limeQuantity':
    case 'sodiumMetabisulfiteQuantity':
    case 'sodiumHydroxideQuantity':
    case 'phValue':
    case 'temperatureC':
    case 'sludgeQuantity':
    case 'finalNeutralizationPh':
    case 'finalNeutralizationRedoxMv':
      return 64;
    case 'chemicalLot':
      return 88;
    case 'operatorComment':
    case 'dosingReason':
    case 'measurementReason':
    case 'chemicalUsedNote':
      return 120;
    case 'reason':
      return 104;
    case 'operator':
      return 96;
    case 'order':
      return 92;
    case 'disposition':
      return 100;
    case 'product':
      return 128;
    case 'product_code':
      return 104;
    case 'materials':
      return 120;
    case 'date':
      return 80;
    case 'time':
      return 64;
    case 'quantity':
    case 'dosedQuantity':
    case 'treatedQuantity':
    case 'good_qty':
    case 'scrap_qty':
    case 'rework_qty':
    case 'qty_submitted':
    case 'processed':
    case 'ok':
    case 'scrap':
    case 'rework':
    case 'duration':
      return 64;
    case 'unit':
      return 56;
    case 'reactor':
    case 'reactorNumber':
      return 52;
    case 'heavy_metals':
    case 'heavyMetalsPresent':
      return 76;
    case 'status':
      return 84;
    case 'details':
      return 72;
    default:
      return switch (size) {
        CatalogEvidenceColumnSize.narrow => 64,
        CatalogEvidenceColumnSize.medium => 104,
        CatalogEvidenceColumnSize.wide => 128,
      };
  }
}

List<CatalogEvidenceTableColumn> catalogEvidenceTableColumnsForProfile(
  ProductionStationProfileCatalogEntry profile,
) {
  if (_usesProfileOperatorFieldColumns(profile.profileKey)) {
    return _profileOperatorFieldColumns(profile);
  }

  // Samo poslovne kolone — F3 trailer dodaje Vrijeme evidencije / Operater / Status / Detalji.
  final List<CatalogEvidenceTableColumn> businessColumns;
  switch (profile.profileKey.trim()) {
    case 'production_counting':
      businessColumns = [
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _textColumn(id: 'product_code', label: 'Šifra proizvoda'),
        _numericColumn(id: 'good_qty', label: 'Dobra količina'),
        _numericColumn(id: 'scrap_qty', label: 'Škart'),
        _numericColumn(id: 'rework_qty', label: 'Dorada'),
        _textColumn(id: 'unit', label: 'Jed.', size: CatalogEvidenceColumnSize.narrow),
      ];
      break;
    case 'packaging_control':
      businessColumns = [
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _textColumn(id: 'disposition', label: 'Dispozicija'),
      ];
      break;
    case 'first_piece_approval':
      businessColumns = [
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _numericColumn(id: 'qty_submitted', label: 'Predato'),
        _textColumn(id: 'disposition', label: 'Dispozicija'),
      ];
      break;
    case 'in_process_quality_check':
      businessColumns = [
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'work_location', label: 'Mjesto rada', size: CatalogEvidenceColumnSize.wide),
        _textColumn(id: 'inspection_outcome', label: 'Ishod'),
      ];
      break;
    default:
      businessColumns = const [];
  }
  return _appendStandardCommonColumns(businessColumns);
}

String catalogEvidenceSessionStatusLabel(String status) {
  switch (status.trim()) {
    case ProductionStationWorkSession.statusOpen:
      return 'U toku';
    case ProductionStationWorkSession.statusPaused:
      return 'Pauzirano';
    case ProductionStationWorkSession.statusClosed:
      return 'Završeno';
    default:
      return status.trim().isEmpty ? '—' : status.trim();
  }
}

String _fieldDisplayValue(
  ProductionStationProfileCatalogEntry profile,
  String fieldKey,
  dynamic raw,
) {
  if (raw == null) return '—';
  ProductionStationProfileField? field;
  for (final f in profile.fields) {
    if (f.key == fieldKey) {
      field = f;
      break;
    }
  }
  if (field != null && field.type == 'enum') {
    return field.enumLabelFor(raw.toString());
  }
  if (raw is num) {
    if (raw == raw.roundToDouble()) return raw.toInt().toString();
    return raw.toString();
  }
  final text = raw.toString().trim();
  return text.isEmpty ? '—' : text;
}

DateTime? _parseMeasuredAtValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString().trim());
}

/// Kanonski format vremena evidencije u tabelama (M1-I1-F3): dd.MM.yyyy HH:mm
String _formatEvidenceDateTime(DateTime? when) {
  if (when == null) return '—';
  return '${when.day.toString().padLeft(2, '0')}.'
      '${when.month.toString().padLeft(2, '0')}.'
      '${when.year} '
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
}

String _cellTextForProfileFieldKey(
  String fieldKey,
  ProductionStationWorkSession session,
  ProductionStationProfileCatalogEntry profile,
) {
  final values = session.fieldValues ?? const {};
  const snapshotByEntityField = <String, String>{
    'workBathId': 'workBathNameSnapshot',
    'chemicalId': 'chemicalNameSnapshot',
  };
  final snapshotKey = snapshotByEntityField[fieldKey];
  if (snapshotKey != null) {
    final name = (values[snapshotKey] ?? '').toString().trim();
    return name.isEmpty ? '—' : name;
  }
  if (fieldKey == 'treatmentType') {
    for (final key in [
      'treatmentTypeLabelSnapshot',
      'treatmentTypeNameSnapshot',
    ]) {
      final snap = (values[key] ?? '').toString().trim();
      if (snap.isNotEmpty) return snap;
    }
  }
  if (fieldKey == 'measuredAt') {
    final measured = _parseMeasuredAtValue(values['measuredAt']);
    return _formatEvidenceDateTime(
      measured ?? session.endedAt ?? session.createdAt,
    );
  }
  return _fieldDisplayValue(profile, fieldKey, values[fieldKey]);
}

String _cellText(
  CatalogEvidenceTableColumn column,
  ProductionStationWorkSession session,
  ProductionStationProfileCatalogEntry profile,
) {
  final values = session.fieldValues ?? const {};
  final when = session.endedAt ?? session.createdAt;
  switch (column.id) {
    case 'evidence_time':
    case 'measured_at':
    case 'measuredAt':
    case 'date':
    case 'time':
      final measured = _parseMeasuredAtValue(values['measuredAt']);
      return _formatEvidenceDateTime(measured ?? when);
    case 'work_bath':
    case 'workBathId':
      final name = (values['workBathNameSnapshot'] ?? '').toString().trim();
      return name.isEmpty ? '—' : name;
    case 'chemical':
      final name = (values['chemicalNameSnapshot'] ?? '').toString().trim();
      return name.isEmpty ? '—' : name;
    case 'treatment_point':
      final name = (values['treatmentPointNameSnapshot'] ?? '').toString().trim();
      return name.isEmpty ? '—' : name;
    case 'reactor':
      return _fieldDisplayValue(profile, 'reactorNumber', values['reactorNumber']);
    case 'heavy_metals':
      return _fieldDisplayValue(
        profile,
        'heavyMetalsPresent',
        values['heavyMetalsPresent'],
      );
    case 'reason':
      if (profile.profileKey.trim() == 'wastewater_treatment') {
        return _fieldDisplayValue(
          profile,
          'measurementReason',
          values['measurementReason'],
        );
      }
      return _fieldDisplayValue(profile, 'dosingReason', values['dosingReason']);
    case 'quantity':
      if (profile.profileKey.trim() == 'wastewater_treatment') {
        return _fieldDisplayValue(
          profile,
          'treatedQuantity',
          values['treatedQuantity'],
        );
      }
      return _fieldDisplayValue(profile, 'dosedQuantity', values['dosedQuantity']);
    case 'order':
      final code = (values['productionOrderCode'] ?? '').toString().trim();
      // Nikad ne prikazuj Firestore document ID kao nalog.
      return code.isEmpty ? '—' : code;
    case 'product':
      final name = (values['productNameSnapshot'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      // production_counting has dedicated product_code column — do not duplicate.
      if (profile.profileKey.trim() == 'production_counting') return '—';
      final code = (values['productCode'] ?? '').toString().trim();
      if (code.isNotEmpty) return code;
      return '—';
    case 'product_code':
      final code = (values['productCode'] ?? '').toString().trim();
      return code.isEmpty ? '—' : code;
    case 'good_qty':
      return _fieldDisplayValue(profile, 'goodQty', values['goodQty']);
    case 'scrap_qty':
      return _fieldDisplayValue(profile, 'scrapQty', values['scrapQty']);
    case 'rework_qty':
      return _fieldDisplayValue(profile, 'reworkQty', values['reworkQty']);
    case 'unit':
      return _fieldDisplayValue(profile, 'unit', values['unit']);
    case 'qty_submitted':
      return _fieldDisplayValue(profile, 'qtySubmitted', values['qtySubmitted']);
    case 'disposition':
      final key = profile.profileKey.trim() == 'packaging_control'
          ? 'packagingDisposition'
          : 'firstPieceDisposition';
      return _fieldDisplayValue(profile, key, values[key]);
    case 'work_location':
      final loc = (values['workLocationNameSnapshot'] ?? '').toString().trim();
      if (loc.isNotEmpty) return loc;
      final machine = (values['machineNameSnapshot'] ?? '').toString().trim();
      final machineCode =
          (values['machineCodeSnapshot'] ?? '').toString().trim();
      if (machine.isNotEmpty || machineCode.isNotEmpty) {
        if (machineCode.isNotEmpty && machine.isNotEmpty) {
          return 'Mašina: $machineCode — $machine';
        }
        return 'Mašina: ${machine.isNotEmpty ? machine : machineCode}';
      }
      final bench = (values['workbenchNameSnapshot'] ?? '').toString().trim();
      final benchCode =
          (values['workbenchCodeSnapshot'] ?? '').toString().trim();
      if (bench.isNotEmpty || benchCode.isNotEmpty) {
        if (benchCode.isNotEmpty && bench.isNotEmpty) {
          return 'Radni sto: $benchCode — $bench';
        }
        return 'Radni sto: ${bench.isNotEmpty ? bench : benchCode}';
      }
      return '—';
    case 'inspection_outcome':
      return _fieldDisplayValue(
        profile,
        'inspectionOutcome',
        values['inspectionOutcome'],
      );
    case 'operator':
      final name = (session.operatorDisplayName ?? '').trim();
      if (name.isNotEmpty) return name;
      final created = (session.createdByDisplayName ?? '').trim();
      return created.isEmpty ? '—' : created;
    case 'status':
      return catalogEvidenceSessionStatusLabel(session.status);
    case 'lot':
      return _fieldDisplayValue(profile, 'chemicalLot', values['chemicalLot']);
    case 'operator_comment':
      return _fieldDisplayValue(
        profile,
        'operatorComment',
        values['operatorComment'],
      );
    default:
      if (_profileOperatorTableFieldKeys(profile.profileKey)
          .contains(column.id)) {
        return _cellTextForProfileFieldKey(column.id, session, profile);
      }
      return '—';
  }
}

class _CatalogEvidenceTableCell extends StatelessWidget {
  const _CatalogEvidenceTableCell({
    required this.borderColor,
    required this.isLastColumn,
    required this.align,
    required this.backgroundColor,
    required this.padding,
    required this.child,
    this.flex,
    this.width,
  });

  final Color borderColor;
  final bool isLastColumn;
  final TextAlign align;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final Widget child;
  final int? flex;
  final double? width;

  Alignment get _alignment {
    switch (align) {
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: isLastColumn
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1),
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Padding(
        padding: padding,
        child: Align(
          alignment: _alignment,
          child: child,
        ),
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: decorated);
    }
    return Expanded(flex: flex ?? 1, child: decorated);
  }
}

/// Donji tabelarni pregled zatvorenih evidencija (M1-F0 standard).
class CatalogEvidenceRecordsTable extends StatelessWidget {
  const CatalogEvidenceRecordsTable({
    super.key,
    required this.companyData,
    required this.profile,
    required this.sessions,
    required this.recordLimit,
    required this.onRecordLimitChanged,
    this.activeSession,
    this.loading = false,
    this.recordLimitOptions = catalogEvidenceRecordLimitOptions,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationProfileCatalogEntry profile;
  final List<ProductionStationWorkSession> sessions;
  final int recordLimit;
  final ValueChanged<int> onRecordLimitChanged;
  final List<int> recordLimitOptions;
  final ProductionStationWorkSession? activeSession;
  final bool loading;

  List<ProductionStationWorkSession> get _rows {
    final rows = List<ProductionStationWorkSession>.from(sessions);
    if (activeSession != null && activeSession!.isActive) {
      rows.insert(0, activeSession!);
    }
    return rows;
  }

  Widget _buildHeaderLabel({
    required CatalogEvidenceTableColumn column,
    required TextStyle headerStyle,
  }) {
    return Text(
      column.label,
      style: headerStyle,
      textAlign: column.align,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHeaderRow({
    required List<CatalogEvidenceTableColumn> columns,
    required Color borderColor,
    required Color headerBackground,
    required TextStyle headerStyle,
    required bool useFixedWidths,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++)
            _CatalogEvidenceTableCell(
              flex: useFixedWidths ? null : columns[i].flex,
              width: useFixedWidths ? columns[i].layoutWidth : null,
              borderColor: borderColor,
              isLastColumn: i == columns.length - 1,
              backgroundColor: headerBackground,
              align: columns[i].align,
              padding: const EdgeInsets.symmetric(
                horizontal: StandardTableMetrics.padH,
                vertical: StandardTableMetrics.headerPadV,
              ),
              child: _buildHeaderLabel(
                column: columns[i],
                headerStyle: headerStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow({
    required BuildContext context,
    required ProductionStationWorkSession session,
    required List<CatalogEvidenceTableColumn> columns,
    required Color borderColor,
    required Color rowBackground,
    required TextStyle cellStyle,
    required bool useFixedWidths,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++)
            _CatalogEvidenceTableCell(
              flex: useFixedWidths ? null : columns[i].flex,
              width: useFixedWidths ? columns[i].layoutWidth : null,
              borderColor: borderColor,
              isLastColumn: i == columns.length - 1,
              backgroundColor: rowBackground,
              align: columns[i].align,
              padding: EdgeInsets.symmetric(
                horizontal: StandardTableMetrics.padH,
                vertical: columns[i].id == 'details'
                    ? 4
                    : StandardTableMetrics.padV,
              ),
              child: _buildDataCell(
                context: context,
                column: columns[i],
                session: session,
                cellStyle: cellStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataCell({
    required BuildContext context,
    required CatalogEvidenceTableColumn column,
    required ProductionStationWorkSession session,
    required TextStyle cellStyle,
  }) {
    if (column.id == 'status') {
      return StandardTableStatusBadge(
        label: _cellText(column, session, profile),
      );
    }
    if (column.id == 'details') {
      return StandardTableOpenLink(
        onPressed: () => _openSessionDetail(context, session),
      );
    }
    return Text(
      _cellText(column, session, profile),
      style: cellStyle,
      textAlign: column.align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _openSessionDetail(
    BuildContext context,
    ProductionStationWorkSession session,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDrivenEvidenceDetailScreen(
          companyData: companyData,
          sessionId: session.id,
        ),
      ),
    );
  }

  Widget _buildTableBody({
    required BuildContext context,
    required List<CatalogEvidenceTableColumn> columns,
    required List<ProductionStationWorkSession> rows,
    required Color borderColor,
    required Color headerBackground,
    required Color rowBackground,
    required TextStyle headerStyle,
    required TextStyle cellStyle,
  }) {
    final emptyBody = Center(
      child: Text(
        'Završene evidencije pojavit će se ovdje.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        textAlign: TextAlign.center,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFixedWidths = _useFixedWidthTableLayout(
          columns: columns,
          maxWidth: constraints.maxWidth,
        );
        final tableLayoutWidth = _effectiveTableLayoutWidth(columns);

        Widget tableColumn() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(
                columns: columns,
                borderColor: borderColor,
                headerBackground: headerBackground,
                headerStyle: headerStyle,
                useFixedWidths: useFixedWidths,
              ),
              Expanded(
                child: rows.isEmpty
                    ? emptyBody
                    : Scrollbar(
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.vertical,
                        child: ListView.builder(
                          primary: false,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            return _buildDataRow(
                              context: context,
                              session: rows[index],
                              columns: columns,
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                              useFixedWidths: useFixedWidths,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        }

        if (useFixedWidths) {
          return Scrollbar(
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                width: tableLayoutWidth,
                height: constraints.maxHeight,
                child: tableColumn(),
              ),
            ),
          );
        }

        return tableColumn();
      },
    );
  }

  Widget _buildRecordLimitSelector({
    required BuildContext context,
    required ColorScheme cs,
  }) {
    final effectiveLimit = recordLimitOptions.contains(recordLimit)
        ? recordLimit
        : catalogEvidenceDefaultRecordLimit;

    return DropdownButton<int>(
      value: effectiveLimit,
      isDense: true,
      underline: const SizedBox.shrink(),
      icon: Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface,
          ),
      items: recordLimitOptions
          .map(
            (n) => DropdownMenuItem<int>(
              value: n,
              child: Text('Zadnjih $n unosa'),
            ),
          )
          .toList(growable: false),
      onChanged: loading
          ? null
          : (value) {
              if (value == null || value == effectiveLimit) return;
              onRecordLimitChanged(value);
            },
    );
  }

  Widget _buildTableToolbar({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme cs,
    required int rowCount,
  }) {
    final title = Text(
      'Pregled evidencija',
      style: theme.textTheme.titleMedium,
    );
    final selector = _buildRecordLimitSelector(context: context, cs: cs);
    final countText = Text(
      loading
          ? 'Učitavanje…'
          : rowCount == 0
          ? 'Nema zapisa za prikaz.'
          : '$rowCount zapisa',
      style: theme.textTheme.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackToolbar =
            constraints.maxWidth < _catalogEvidenceRecordLimitToolbarBreakpoint;

        if (stackToolbar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: selector,
              ),
              const SizedBox(height: 4),
              countText,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                selector,
              ],
            ),
            const SizedBox(height: 4),
            countText,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final columns = catalogEvidenceTableColumnsForProfile(profile);
    final borderColor = StandardTableMetrics.borderColor(cs);
    final headerBackground = StandardTableMetrics.headerBackground(cs);
    final rowBackground = StandardTableMetrics.rowBackground(cs);
    final headerStyle = StandardTableMetrics.headerStyle(cs);
    final cellStyle = StandardTableMetrics.cellStyle(cs);
    final rows = _rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildTableToolbar(
            context: context,
            theme: theme,
            cs: cs,
            rowCount: rows.length,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StandardTableShell(
              child: _buildTableBody(
                context: context,
                columns: columns,
                rows: rows,
                borderColor: borderColor,
                headerBackground: headerBackground,
                rowBackground: rowBackground,
                headerStyle: headerStyle,
                cellStyle: cellStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
