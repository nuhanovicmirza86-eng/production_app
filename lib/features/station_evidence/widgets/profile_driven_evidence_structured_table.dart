import 'package:flutter/material.dart';

import '../models/profile_driven_evidence_session.dart';

class ProfileDrivenEvidenceStructuredColumn {
  const ProfileDrivenEvidenceStructuredColumn(this.label, this.key);

  final String label;
  final String key;
}

/// Read-only tablica structured redova na detalju evidencije.
class ProfileDrivenEvidenceStructuredTable extends StatelessWidget {
  const ProfileDrivenEvidenceStructuredTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellBuilder,
  });

  final List<ProfileDrivenEvidenceStructuredColumn> columns;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic> row, String columnKey) cellBuilder;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Nema redova za prikaz.');
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 56,
        columnSpacing: 16,
        headingTextStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        columns: columns
            .map((c) => DataColumn(label: Text(c.label)))
            .toList(growable: false),
        rows: rows
            .map(
              (row) => DataRow(
                cells: columns
                    .map(
                      (col) => DataCell(
                        Text(
                          cellBuilder(row, col.key),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

String evidenceRowText(dynamic v) => formatFieldValue(v);

String evidenceRowDateTime(dynamic v) {
  final dt = _ts(v);
  return dt == null ? '—' : formatEvidenceDateTime(dt);
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is Map) {
    final seconds = v['seconds'] ?? v['_seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
  }
  if (v is String && v.trim().isNotEmpty) {
    return DateTime.tryParse(v.trim())?.toLocal();
  }
  return null;
}
