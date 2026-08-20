import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_piece_quantity.dart';

void main() {
  group('M1-I5-C4B controlled items qty balance', () {
    test('rejects unbalanced row with BS message and counts', () {
      final issue = controlledItemsQtyBalanceIssue(
        inspectedQty: 650,
        goodQty: 625,
        scrapQty: 50,
        reworkQty: 1,
      );
      expect(issue, isNotNull);
      expect(issue!.message, contains('Količine se ne poklapaju'));
      expect(issue.message, contains('Kontrolisano: 650'));
      expect(issue.message, contains('Zbir OK + škart + dorada: 676'));
      expect(issue.message, contains('Razlika: 26'));
      expect(
        issue.errorFieldKeys,
        containsAll(['inspectedQty', 'goodQty', 'scrapQty', 'reworkQty']),
      );
    });

    test('rejects 198 / 144 / 120 / 1 (live FAIL case)', () {
      final issue = controlledItemsQtyBalanceIssue(
        inspectedQty: 198,
        goodQty: 144,
        scrapQty: 120,
        reworkQty: 1,
      );
      expect(issue, isNotNull);
      expect(issue!.message, contains('Kontrolisano: 198'));
      expect(issue.message, contains('Zbir OK + škart + dorada: 265'));
      expect(issue.message, contains('Razlika: 67'));
    });

    test('needsControlledItemsQtyBalance detects by profile/columns', () {
      expect(
        needsControlledItemsQtyBalance(
          tableKey: 'unknown_table',
          profileKey: 'final_control',
        ),
        isTrue,
      );
      expect(
        needsControlledItemsQtyBalance(
          tableKey: '',
          columnKeys: const [
            'inspectedQty',
            'goodQty',
            'scrapQty',
            'reworkQty',
          ],
        ),
        isTrue,
      );
    });

    test('accepts balanced row 650 = 599 + 50 + 1', () {
      expect(
        controlledItemsQtyBalanceIssue(
          inspectedQty: 650,
          goodQty: 599,
          scrapQty: 50,
          reworkQty: 1,
        ),
        isNull,
      );
    });
  });
}
