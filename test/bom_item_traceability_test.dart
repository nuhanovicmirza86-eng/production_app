import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/bom/bom_item_traceability.dart';

void main() {
  test('legacy BOM item → lot required + WMS lot default', () {
    final r = resolveBomItemTraceability({});
    expect(r.lotRequired, isTrue);
    expect(r.mode, bomTraceabilityWmsLot);
    expect(r.kind, bomItemKindRawMaterial);
  });

  test('Bez lota → lot nije obavezan', () {
    final r = resolveBomItemTraceability({
      bomItemFieldKind: bomItemKindPackaging,
      bomItemFieldTraceabilityMode: bomTraceabilityNone,
      bomItemFieldLotRequired: true, // konflikt → mode none forsira false
    });
    expect(r.lotRequired, isFalse);
    expect(r.mode, bomTraceabilityNone);
  });

  test('ompLotIsRequired reads snapshot', () {
    expect(
      ompLotIsRequired({ompLotRequiredSnapshot: false}),
      isFalse,
    );
    expect(
      ompLotIsRequired({ompLotRequiredSnapshot: true}),
      isTrue,
    );
    expect(ompLotIsRequired({}), isTrue);
  });

  test('BS labels only', () {
    expect(bomItemKindLabelBs(bomItemKindRawMaterial), 'Sirovina');
    expect(bomTraceabilityModeLabelBs(bomTraceabilityNone), 'Bez lota');
    expect(bomLotRequiredLabelBs(false), 'Ne');
  });

  test('validate save rejects lot required with none', () {
    expect(
      validateBomItemTraceabilityForSave(
        kind: bomItemKindAuxiliary,
        mode: bomTraceabilityNone,
        lotRequired: true,
      ),
      isNotNull,
    );
  });
}
