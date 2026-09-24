import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/utils/ncr_recheck_execution_choice_options.dart';
import 'package:production_app/modules/quality/utils/ncr_recheck_qty_validation.dart';

void main() {
  group('ncrRecheckQtySumDetailError', () {
    test('explains mismatch with totals', () {
      final msg = ncrRecheckQtySumDetailError(
        checked: 149,
        ok: 100,
        rejected: 40,
        separated: 0,
      );
      expect(msg, isNotNull);
      expect(msg!, contains('100 + 40 + 0 = 140'));
      expect(msg, contains('kontrolisano je 149'));
    });

    test('is null when sum matches', () {
      expect(
        ncrRecheckQtySumDetailError(
          checked: 149,
          ok: 148,
          rejected: 1,
          separated: 0,
        ),
        isNull,
      );
    });
  });

  group('ncrRecheckOutcomeMismatchError', () {
    test('Odobreno requires zero rejected', () {
      expect(
        ncrRecheckOutcomeMismatchError(
          outcome: 'Odobreno',
          ok: 149,
          rejected: 1,
        ),
        isNotNull,
      );
    });

    test('Djelimično odobreno requires both ok and rejected', () {
      expect(
        ncrRecheckOutcomeMismatchError(
          outcome: 'Djelimično odobreno',
          ok: 100,
          rejected: 0,
        ),
        isNotNull,
      );
      expect(
        ncrRecheckOutcomeMismatchError(
          outcome: 'Djelimično odobreno',
          ok: 100,
          rejected: 49,
        ),
        isNull,
      );
    });
  });

  group('resolveNcrRecheckCheckDescription', () {
    test('returns preset label', () {
      expect(
        resolveNcrRecheckCheckDescription(
          selected: 'Dimenzije',
          otherText: '',
        ),
        'Dimenzije',
      );
    });
  });
}
