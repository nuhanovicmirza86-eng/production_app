import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/production/station_work/models/production_station_work_session.dart';
import 'package:production_app/features/station_evidence/utils/evidence_order_context_display.dart';

void main() {
  const snap = ProductionStationWorkOrderSnapshot(
    productionOrderCode: 'PN-2026-001',
    productCode: 'ART-100',
    productName: 'Proizvod A',
    plannedQty: 10,
    producedGoodQty: 2,
    unit: 'kom',
    bomVersion: '3',
    routingId: 'unspecified',
    routingVersion: '2',
    operationName: 'Montaža',
    workCenterCode: 'WC-01',
    workCenterName: 'Linija 1',
  );

  test('operationLabelFromSnapshot hides unspecified routing id', () {
    expect(
      EvidenceOrderContextDisplay.operationLabelFromSnapshot(snap),
      '2 · Montaža',
    );
  });

  test('workCenterLabelFromSnapshot uses code and name', () {
    expect(
      EvidenceOrderContextDisplay.workCenterLabelFromSnapshot(snap),
      'WC-01 — Linija 1',
    );
  });

  test('bomVersionLabelFromSnapshot shows version only', () {
    expect(
      EvidenceOrderContextDisplay.bomVersionLabelFromSnapshot(snap),
      'Verzija 3',
    );
  });

  test('productLabelFromSnapshot combines code and name', () {
    expect(
      EvidenceOrderContextDisplay.productLabelFromSnapshot(snap),
      'ART-100 — Proizvod A',
    );
  });
}
