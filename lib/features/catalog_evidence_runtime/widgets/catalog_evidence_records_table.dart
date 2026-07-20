import 'package:flutter/material.dart';

import '../../../core/ui/standard_table_components.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';

class CatalogEvidenceTableColumn {
  const CatalogEvidenceTableColumn({
    required this.id,
    required this.label,
    this.flex = 8,
    this.align = TextAlign.left,
    this.numeric = false,
  });

  final String id;
  final String label;
  final int flex;
  final TextAlign align;
  final bool numeric;
}

List<CatalogEvidenceTableColumn> catalogEvidenceTableColumnsForProfile(
  ProductionStationProfileCatalogEntry profile,
) {
  switch (profile.profileKey.trim()) {
    case 'production_counting':
      return const [
        CatalogEvidenceTableColumn(id: 'date', label: 'Datum', flex: 7),
        CatalogEvidenceTableColumn(id: 'time', label: 'Vrijeme', flex: 6),
        CatalogEvidenceTableColumn(id: 'order', label: 'Nalog', flex: 9),
        CatalogEvidenceTableColumn(id: 'product', label: 'Proizvod', flex: 11),
        CatalogEvidenceTableColumn(
          id: 'good_qty',
          label: 'Dobra',
          flex: 6,
          align: TextAlign.right,
          numeric: true,
        ),
        CatalogEvidenceTableColumn(
          id: 'scrap_qty',
          label: 'Škart',
          flex: 6,
          align: TextAlign.right,
          numeric: true,
        ),
        CatalogEvidenceTableColumn(
          id: 'rework_qty',
          label: 'Dorada',
          flex: 6,
          align: TextAlign.right,
          numeric: true,
        ),
        CatalogEvidenceTableColumn(id: 'unit', label: 'Jedinica', flex: 6),
        CatalogEvidenceTableColumn(id: 'operator', label: 'Operater', flex: 10),
        CatalogEvidenceTableColumn(id: 'status', label: 'Status', flex: 8),
      ];
    case 'packaging_control':
      return const [
        CatalogEvidenceTableColumn(id: 'date', label: 'Datum', flex: 7),
        CatalogEvidenceTableColumn(id: 'time', label: 'Vrijeme', flex: 6),
        CatalogEvidenceTableColumn(id: 'order', label: 'Nalog', flex: 9),
        CatalogEvidenceTableColumn(id: 'product', label: 'Proizvod', flex: 11),
        CatalogEvidenceTableColumn(
          id: 'disposition',
          label: 'Dispozicija',
          flex: 10,
        ),
        CatalogEvidenceTableColumn(id: 'operator', label: 'Operater', flex: 10),
        CatalogEvidenceTableColumn(id: 'status', label: 'Status', flex: 8),
      ];
    case 'first_piece_approval':
      return const [
        CatalogEvidenceTableColumn(id: 'date', label: 'Datum', flex: 7),
        CatalogEvidenceTableColumn(id: 'time', label: 'Vrijeme', flex: 6),
        CatalogEvidenceTableColumn(id: 'order', label: 'Nalog', flex: 9),
        CatalogEvidenceTableColumn(id: 'product', label: 'Proizvod', flex: 11),
        CatalogEvidenceTableColumn(
          id: 'qty_submitted',
          label: 'Predato',
          flex: 7,
          align: TextAlign.right,
          numeric: true,
        ),
        CatalogEvidenceTableColumn(
          id: 'disposition',
          label: 'Dispozicija',
          flex: 10,
        ),
        CatalogEvidenceTableColumn(id: 'operator', label: 'Operater', flex: 10),
        CatalogEvidenceTableColumn(id: 'status', label: 'Status', flex: 8),
      ];
    default:
      return const [
        CatalogEvidenceTableColumn(id: 'date', label: 'Datum', flex: 7),
        CatalogEvidenceTableColumn(id: 'time', label: 'Vrijeme', flex: 6),
        CatalogEvidenceTableColumn(id: 'operator', label: 'Operater', flex: 12),
        CatalogEvidenceTableColumn(id: 'status', label: 'Status', flex: 8),
      ];
  }
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

String _cellText(
  CatalogEvidenceTableColumn column,
  ProductionStationWorkSession session,
  ProductionStationProfileCatalogEntry profile,
) {
  final values = session.fieldValues ?? const {};
  final when = session.endedAt ?? session.createdAt;
  switch (column.id) {
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

/// Donji tabelarni pregled zatvorenih evidencija (M1-F0 standard).
class CatalogEvidenceRecordsTable extends StatelessWidget {
  const CatalogEvidenceRecordsTable({
    super.key,
    required this.profile,
    required this.sessions,
    this.activeSession,
    this.loading = false,
  });

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < columns.length; i++)
                          StandardTableFlexCell(
                            flex: columns[i].flex,
                            borderColor: borderColor,
                            isLastColumn: i == columns.length - 1,
                            backgroundColor: headerBackground,
                            align: columns[i].align,
                            padding: const EdgeInsets.symmetric(
                              horizontal: StandardTableMetrics.padH,
                              vertical: StandardTableMetrics.headerPadV,
                            ),
                            child: Text(
                              columns[i].label,
                              style: headerStyle,
                              textAlign: columns[i].align,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(
                              'Završene evidencije pojavit će se ovdje.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final session = rows[index];
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (var i = 0; i < columns.length; i++)
                                        StandardTableFlexCell(
                                          flex: columns[i].flex,
                                          borderColor: borderColor,
                                          isLastColumn: i == columns.length - 1,
                                          backgroundColor: rowBackground,
                                          align: columns[i].align,
                                          child: columns[i].id == 'status'
                                              ? StandardTableStatusBadge(
                                                  label: _cellText(
                                                    columns[i],
                                                    session,
                                                    profile,
                                                  ),
                                                )
                                              : Text(
                                                  _cellText(
                                                    columns[i],
                                                    session,
                                                    profile,
                                                  ),
                                                  style: cellStyle,
                                                  textAlign: columns[i].align,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
