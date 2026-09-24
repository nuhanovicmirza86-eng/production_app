import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import 'package:production_app/features/profile_driven_structured_runtime/services/production_evidence_entity_search_service.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_field.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_entity_search_result_appearance.dart';

void main() {
  test('searchWorkCenters uses evidence plant and is a supported callable', () {
    expect(
      ProductionEvidenceEntitySearchCallableService.usesAssignedPlantKey(
        'searchWorkCenters',
      ),
      isTrue,
    );
    expect(
      ProductionEvidenceEntitySearchCallableService.usesAssignedPlantKey(
        'searchProducts',
      ),
      isFalse,
    );
  });

  test('work center search result label uses code and name, not raw id', () {
    final item = StructuredEntitySearchResult.fromMap({
      'id': 'AbCdEfGhIjKlMnOpQrSt',
      'workCenterCode': 'BR-L1',
      'displayName': 'Linija brizganje 1',
    });
    expect(item.displayLabel, 'BR-L1 — Linija brizganje 1');
    expect(item.displayLabel.contains('AbCdEfGh'), isFalse);
  });

  test('unsupported search error never shows callable name', () {
    expect(
      productionEvidenceEntitySearchErrorMessage(
        Exception('Nepodržana pretraga: searchWorkCenters'),
      ),
      'Pretraga nije dostupna. Ako radni centar nije u šifrarniku, unesite Naziv linije.',
    );
    expect(
      productionEvidenceEntitySearchErrorMessage(
        Exception('Nepodržana pretraga: searchWorkCenters'),
      ).toLowerCase().contains('searchworkcenters'),
      isFalse,
    );
  });

  test('work center picker badge is BCS', () {
    final field = ProductionStationProfileField.fromMap(const {
      'key': 'workCenterId',
      'label': 'Radni centar / linija',
      'type': 'entity_search_select',
      'entityCollection': 'work_centers',
    });
    final item = StructuredEntitySearchResult.fromMap({
      'id': 'x',
      'workCenterCode': 'BR-L1',
      'displayName': 'Linija 1',
    });
    expect(
      StructuredEntitySearchResultAppearance.badgeLabel(
        field: field,
        item: item,
      ),
      'Radni centar',
    );
  });
}
