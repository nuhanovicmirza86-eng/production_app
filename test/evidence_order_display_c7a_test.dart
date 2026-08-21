import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';

void main() {
  group('M1-I5-C7A display labels', () {
    test('production order label never shows firestore id', () {
      expect(
        StructuredEntitySearchResult.productionOrderDisplayLabel({
          'productionOrderCode': 'PLANT_2-26063-93314',
          'id': 'CSnhR1055n6pjp0SQZW0',
        }),
        'PLANT_2-26063-93314',
      );
      expect(
        StructuredEntitySearchResult.productionOrderDisplayLabel({
          'id': 'CSnhR1055n6pjp0SQZW0',
        }),
        '—',
      );
    });

    test('product label uses code and name', () {
      expect(
        StructuredEntitySearchResult.productDisplayLabel({
          'productCode': 'GK400002',
          'productName': '1700-000025 - BOTTLE CAP MATT CROM',
          'id': 'AaRJQWEkdtCfoo5eDjnk',
        }),
        'GK400002 — 1700-000025 - BOTTLE CAP MATT CROM',
      );
      expect(
        StructuredEntitySearchResult.productDisplayLabel({
          'id': 'AaRJQWEkdtCfoo5eDjnk',
        }),
        '—',
      );
    });

    test('scan toSearchResult uses business order label', () {
      const scan = StructuredScanResolveResult(
        type: 'production_order',
        resolvedId: 'CSnhR1055n6pjp0SQZW0',
        displayCode: 'PLANT_2-26063-93314',
        productId: 'AaRJQWEkdtCfoo5eDjnk',
        productCode: 'GK400002',
        productName: '1700-000025 - BOTTLE CAP MATT CROM',
      );
      final item = scan.toSearchResult()!;
      expect(item.displayLabel, 'PLANT_2-26063-93314');
      expect(item.displayLabel, isNot(contains('CSnhR')));
      expect(
        item.secondaryLabel,
        'GK400002 — 1700-000025 - BOTTLE CAP MATT CROM',
      );
    });

    test('order search fromMap prefers order code', () {
      final item = StructuredEntitySearchResult.fromMap({
        'id': 'CSnhR1055n6pjp0SQZW0',
        'orderCode': 'PLANT_2-26063-93314',
        'productCode': 'GK400002',
        'productName': 'BOTTLE CAP',
      });
      expect(item.displayLabel, 'PLANT_2-26063-93314');
      expect(item.secondaryLabel, 'GK400002 — BOTTLE CAP');
    });
  });
}
