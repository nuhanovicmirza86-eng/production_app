import 'package:flutter/material.dart';

import '../widgets/profile_driven_evidence_grid.dart';

/// M1-I14-C — zajedničke kolone order/routing konteksta u supervision pregledu.
class EvidenceOrderContextGridColumns {
  EvidenceOrderContextGridColumns._();

  static const all = [
    ProfileDrivenEvidenceGridColumn(id: 'order_code', label: 'Nalog', flex: 9),
    ProfileDrivenEvidenceGridColumn(id: 'product', label: 'Proizvod', flex: 12),
    ProfileDrivenEvidenceGridColumn(
      id: 'operation',
      label: 'Operacija',
      flex: 10,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'work_center',
      label: 'Radni centar',
      flex: 10,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'bom_version',
      label: 'BOM\nverzija',
      flex: 8,
    ),
  ];

  static const orderContextColumnIds = {
    'order_code',
    'product',
    'operation',
    'work_center',
    'bom_version',
  };

  static List<ProfileDrivenEvidenceGridColumn> mergeAfterDateTime(
    List<ProfileDrivenEvidenceGridColumn> base,
  ) {
    ProfileDrivenEvidenceGridColumn? dateCol;
    ProfileDrivenEvidenceGridColumn? timeCol;
    final rest = <ProfileDrivenEvidenceGridColumn>[];
    for (final col in base) {
      if (col.id == 'date') {
        dateCol = col;
      } else if (col.id == 'time') {
        timeCol = col;
      } else if (!orderContextColumnIds.contains(col.id)) {
        rest.add(col);
      }
    }
    return [
      if (dateCol != null) dateCol,
      if (timeCol != null) timeCol,
      ...all,
      ...rest,
    ];
  }
}

/// Profili s catalog evidence gridom (M1-F2 + final_control).
const profileDrivenEvidenceCatalogRecordsProfiles = {
  'packaging_control',
  'material_preparation',
  'operation_material_preparation',
  'in_process_quality_check',
  'final_control',
  'line_clearance',
  'tool_changeover',
  'first_piece_approval',
  'batch_mixing',
  'production_counting',
};

bool profileUsesCatalogEvidenceRecordsGrid(String profileType) {
  return profileDrivenEvidenceCatalogRecordsProfiles.contains(
    profileType.trim(),
  );
}

const catalogEvidenceRecordsColumns = [
  ProfileDrivenEvidenceGridColumn(id: 'date', label: 'Datum', flex: 7),
  ProfileDrivenEvidenceGridColumn(id: 'time', label: 'Vrijeme', flex: 6),
  ...EvidenceOrderContextGridColumns.all,
  ProfileDrivenEvidenceGridColumn(id: 'operator', label: 'Operater', flex: 10),
  ProfileDrivenEvidenceGridColumn(id: 'status', label: 'Status', flex: 7),
  ProfileDrivenEvidenceGridColumn(
    id: 'details',
    label: 'Detalji',
    flex: 7,
    align: TextAlign.center,
  ),
];
