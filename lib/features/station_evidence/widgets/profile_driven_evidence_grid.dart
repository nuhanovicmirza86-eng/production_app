import 'package:flutter/material.dart';

import '../../../core/ui/standard_table_components.dart';

/// Kolona grid prikaza evidencije — [flex] određuje udio dostupne širine.
class ProfileDrivenEvidenceGridColumn {
  const ProfileDrivenEvidenceGridColumn({
    required this.id,
    required this.label,
    this.flex = 1,
    this.align = TextAlign.left,
    this.numeric = false,
  });

  final String id;
  final String label;
  final int flex;
  final TextAlign align;
  final bool numeric;
}

/// Header red tabele evidencija (standardni vizual kao Proizvodni nalozi).
class ProfileDrivenEvidenceGridTable extends StatelessWidget {
  const ProfileDrivenEvidenceGridTable({
    super.key,
    required this.columns,
  });

  final List<ProfileDrivenEvidenceGridColumn> columns;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = StandardTableMetrics.borderColor(cs);
    final headerStyle = StandardTableMetrics.headerStyle(cs);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++)
            StandardTableFlexCell(
              flex: columns[i].flex,
              borderColor: borderColor,
              isLastColumn: i == columns.length - 1,
              backgroundColor: StandardTableMetrics.headerBackground(cs),
              align: columns[i].align,
              padding: const EdgeInsets.symmetric(
                horizontal: StandardTableMetrics.padH,
                vertical: StandardTableMetrics.headerPadV,
              ),
              child: Text(
                columns[i].label,
                textAlign: columns[i].align,
                maxLines: columns[i].label.contains('\n') ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: headerStyle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Read-only tekstualna ćelija (nije klikabilna).
Widget profileEvidenceGridTextCell({
  required ProfileDrivenEvidenceGridColumn column,
  required String text,
  required Color borderColor,
  required Color rowBackground,
  required TextStyle cellStyle,
  bool isLast = false,
}) {
  return StandardTableFlexCell(
    flex: column.flex,
    borderColor: borderColor,
    isLastColumn: isLast,
    backgroundColor: rowBackground,
    align: column.align,
    child: Text(
      text,
      textAlign: column.align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: cellStyle,
    ),
  );
}

/// Widget ćelija (status badge ili dugme Detalji).
Widget profileEvidenceGridWidgetCell({
  required ProfileDrivenEvidenceGridColumn column,
  required Widget child,
  required Color borderColor,
  required Color rowBackground,
  bool isLast = false,
  Alignment alignment = Alignment.center,
}) {
  return StandardTableFlexCell(
    flex: column.flex,
    borderColor: borderColor,
    isLastColumn: isLast,
    backgroundColor: rowBackground,
    align: TextAlign.center,
    padding: const EdgeInsets.symmetric(
      horizontal: StandardTableMetrics.padH,
      vertical: 4,
    ),
    child: Align(alignment: alignment, child: child),
  );
}
