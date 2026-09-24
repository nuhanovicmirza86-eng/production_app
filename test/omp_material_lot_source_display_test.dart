import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/omp_material_lot_source_display.dart';

void main() {
  test('manual lot without source → ručni label', () {
    final fv = <String, dynamic>{'materialLot': 'test'};
    expect(
      ompMaterialLotSourceDisplayLabel(fv),
      ompMaterialLotSourceManualLabel,
    );
    expect(ompMaterialLotListDisplay(fv), 'test (ručno)');
    expect(ompMaterialLotIsManualOrUnconfirmed(fv), isTrue);
  });

  test('explicit manual source', () {
    final fv = <String, dynamic>{
      'materialLot': 'LOT-1',
      'materialLotSource': 'manual',
    };
    expect(
      ompMaterialLotSourceDisplayLabel(fv),
      'Ručni unos — nije potvrđen kroz WMS',
    );
  });

  test('wms source with doc id', () {
    final fv = <String, dynamic>{
      'materialLot': 'LOT-W',
      'materialLotSource': 'wms',
      'inventoryLotDocId': 'abc123',
    };
    expect(
      ompMaterialLotSourceDisplayLabel(fv),
      ompMaterialLotSourceWmsLabel,
    );
    expect(ompMaterialLotListDisplay(fv), 'LOT-W');
  });

  test('empty lot → null label', () {
    expect(ompMaterialLotSourceDisplayLabel(const {}), isNull);
    expect(ompMaterialLotListDisplay(const {}), '—');
  });
}
