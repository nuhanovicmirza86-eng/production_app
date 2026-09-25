import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/features/station_evidence/models/profile_driven_evidence_session.dart';
import 'package:production_app/features/station_evidence/utils/evidence_order_context_display.dart';
import 'package:production_app/modules/production/station_work/models/production_station_work_session.dart';

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

  const ctx = ProfileDrivenEvidenceOrderContext(
    hasSnapshot: true,
    productionOrderCode: 'PN-2026-001',
    productCode: 'ART-100',
    productName: 'Proizvod A',
    routingId: 'unspecified',
    routingVersion: '2',
    operationName: 'Montaža',
    workCenterCode: 'WC-01',
    workCenterName: 'Linija 1',
    bomVersion: '3',
  );

  test('operationLabelFromSnapshot hides unspecified routing id', () {
    expect(
      EvidenceOrderContextDisplay.operationLabelFromSnapshot(snap),
      'Montaža',
    );
  });

  test('list context without snapshot shows Nije evidentirano', () {
    const empty = ProfileDrivenEvidenceOrderContext(hasSnapshot: false);
    expect(
      EvidenceOrderContextDisplay.orderCode(empty),
      EvidenceOrderContextDisplay.notRecorded,
    );
    expect(
      EvidenceOrderContextDisplay.productLabel(empty),
      EvidenceOrderContextDisplay.notRecorded,
    );
    expect(
      EvidenceOrderContextDisplay.operationLabel(empty),
      EvidenceOrderContextDisplay.notRecorded,
    );
  });

  test('list context with snapshot shows business labels', () {
    expect(EvidenceOrderContextDisplay.orderCode(ctx), 'PN-2026-001');
    expect(
      EvidenceOrderContextDisplay.productLabel(ctx),
      'ART-100 — Proizvod A',
    );
    expect(EvidenceOrderContextDisplay.bomVersionLabel(ctx), 'Verzija 3');
  });

  test('ProfileDrivenEvidenceOrderContext.fromMap', () {
    final parsed = ProfileDrivenEvidenceOrderContext.fromMap({
      'hasSnapshot': true,
      'productionOrderCode': 'PN-1',
      'bomVersion': '5',
    });
    expect(parsed.hasSnapshot, isTrue);
    expect(parsed.productionOrderCode, 'PN-1');
    expect(parsed.bomVersion, '5');
  });
}
