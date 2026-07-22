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

List<CatalogEvidenceTableColumn> _appendStandardDetailsColumn(
  List<CatalogEvidenceTableColumn> columns,
) {
  if (columns.any((column) => column.id == 'details')) {
    return columns;
  }
  return [...columns, _standardDetailsColumn];
}

const double _catalogEvidenceNarrowTableBreakpoint = 600;
const double _catalogEvidenceHeaderCharWidth = 6.3;

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
    case 'measured_at':
      return 116;
    case 'work_bath':
    case 'chemical':
    case 'treatment_point':
      return 100;
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
    case 'materials':
      return 120;
    case 'date':
      return 80;
    case 'time':
      return 64;
    case 'quantity':
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
      return 52;
    case 'heavy_metals':
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
  final List<CatalogEvidenceTableColumn> profileColumns;
  switch (profile.profileKey.trim()) {
    case 'production_counting':
      profileColumns = [
        _textColumn(id: 'date', label: 'Datum', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'time', label: 'Vrijeme', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _numericColumn(id: 'good_qty', label: 'Dobra'),
        _numericColumn(id: 'scrap_qty', label: 'Škart'),
        _numericColumn(id: 'rework_qty', label: 'Dorada'),
        _textColumn(id: 'unit', label: 'Jedinica', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
      break;
    case 'packaging_control':
      profileColumns = [
        _textColumn(id: 'date', label: 'Datum', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'time', label: 'Vrijeme', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _textColumn(id: 'disposition', label: 'Dispozicija'),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
      break;
    case 'first_piece_approval':
      profileColumns = [
        _textColumn(id: 'date', label: 'Datum', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'time', label: 'Vrijeme', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'order', label: 'Nalog'),
        _textColumn(id: 'product', label: 'Proizvod', size: CatalogEvidenceColumnSize.wide),
        _numericColumn(id: 'qty_submitted', label: 'Predato'),
        _textColumn(id: 'disposition', label: 'Dispozicija'),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
      break;
    case 'chemical_dosing':
      profileColumns = [
        _textColumn(id: 'measured_at', label: 'Vrijeme doziranja'),
        _textColumn(id: 'work_bath', label: 'Radna kada'),
        _textColumn(id: 'chemical', label: 'Hemikalija'),
        _numericColumn(id: 'quantity', label: 'Količina'),
        _textColumn(id: 'unit', label: 'Jedinica', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'reason', label: 'Razlog doziranja'),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
      break;
    case 'wastewater_treatment':
      profileColumns = [
        _textColumn(id: 'measured_at', label: 'Vrijeme mjerenja'),
        _textColumn(id: 'treatment_point', label: 'Procesna tačka'),
        _numericColumn(id: 'quantity', label: 'Tretirana kol.'),
        _textColumn(id: 'unit', label: 'Jedinica', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'reactor', label: 'Reaktor', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'heavy_metals', label: 'Teški metali', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
      break;
    default:
      profileColumns = [
        _textColumn(id: 'date', label: 'Datum', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'time', label: 'Vrijeme', size: CatalogEvidenceColumnSize.narrow),
        _textColumn(id: 'operator', label: 'Operater'),
        _standardStatusColumn,
      ];
  }
  return _appendStandardDetailsColumn(profileColumns);
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

String _formatMeasuredAt(DateTime? when) {
  if (when == null) return '—';
  return '${when.day.toString().padLeft(2, '0')}.'
      '${when.month.toString().padLeft(2, '0')}.'
      '${when.year}. '
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
}

String _cellText(
  CatalogEvidenceTableColumn column,
  ProductionStationWorkSession session,
  ProductionStationProfileCatalogEntry profile,
) {
  final values = session.fieldValues ?? const {};
  final when = session.endedAt ?? session.createdAt;
  switch (column.id) {
    case 'measured_at':
      final measured = _parseMeasuredAtValue(values['measuredAt']);
      return _formatMeasuredAt(measured ?? when);
    case 'work_bath':
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
    case 'date':
      return when == null
          ? '—'
          : '${when.day.toString().padLeft(2, '0')}.'
              '${when.month.toString().padLeft(2, '0')}.'
              '${when.year}.';
    case 'time':
      return when == null
          ? '—'
          : '${when.hour.toString().padLeft(2, '0')}:'
              '${when.minute.toString().padLeft(2, '0')}';
    case 'order':
      final code = (values['productionOrderCode'] ?? '').toString().trim();
      if (code.isNotEmpty) return code;
      return (values['productionOrderId'] ?? '').toString().trim().isEmpty
          ? '—'
          : (values['productionOrderId'] ?? '').toString().trim();
    case 'product':
      final name = (values['productNameSnapshot'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final code = (values['productCode'] ?? '').toString().trim();
      if (code.isNotEmpty) return code;
      return '—';
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
    case 'operator':
      final name = (session.operatorDisplayName ?? '').trim();
      if (name.isNotEmpty) return name;
      final created = (session.createdByDisplayName ?? '').trim();
      return created.isEmpty ? '—' : created;
    case 'status':
      return catalogEvidenceSessionStatusLabel(session.status);
    default:
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
    this.activeSession,
    this.loading = false,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationProfileCatalogEntry profile;
  final List<ProductionStationWorkSession> sessions;
  final ProductionStationWorkSession? activeSession;
  final bool loading;

  List<ProductionStationWorkSession> get _rows {
    final rows = List<ProductionStationWorkSession>.from(sessions);
    if (activeSession != null && activeSession!.isActive) {
      rows.insert(0, activeSession!);
    }
    return rows;
  }

  double _tableLayoutWidth(List<CatalogEvidenceTableColumn> columns) {
    return columns.fold<double>(
      0,
      (sum, column) => sum + column.layoutWidth,
    );
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
        final tableLayoutWidth = _tableLayoutWidth(columns);
        final useFixedWidths =
            tableLayoutWidth > constraints.maxWidth + 1 ||
            constraints.maxWidth < _catalogEvidenceNarrowTableBreakpoint;

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
                        child: ListView.builder(
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
          child: Text(
            'Pregled evidencija',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            loading
                ? 'Učitavanje…'
                : rows.isEmpty
                ? 'Nema zapisa za prikaz.'
                : '${rows.length} zapisa',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
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
