import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/quality/utils/ncr_rework_execution_choice_options.dart';

import 'package:production_app/modules/quality/utils/ncr_rework_qty_validation.dart';



void main() {

  group('ncrReworkQtySumDetailError', () {

    test('explains mismatch with totals', () {

      final msg = ncrReworkQtySumDetailError(

        reworked: 150,

        separated: 1,

        toRecheck: 150,

      );

      expect(msg, isNotNull);

      expect(msg!, contains('1 + 150 = 151'));

      expect(msg, contains('dorađeno je 150'));

    });



    test('is null when sum matches', () {

      expect(

        ncrReworkQtySumDetailError(

          reworked: 150,

          separated: 1,

          toRecheck: 149,

        ),

        isNull,

      );

    });

  });



  group('resolveNcrEvidenceChoiceValue', () {

    test('returns selected label for preset option', () {

      expect(

        resolveNcrEvidenceChoiceValue(

          selected: 'Sortiranje',

          otherText: '',

        ),

        'Sortiranje',

      );

    });



    test('returns custom text for Drugo when long enough', () {

      expect(

        resolveNcrEvidenceChoiceValue(

          selected: ncrReworkChoiceOther,

          otherText: 'Ručna dorada ivice',

        ),

        'Ručna dorada ivice',

      );

    });



    test('returns null when Drugo without text', () {

      expect(

        resolveNcrEvidenceChoiceValue(

          selected: ncrReworkChoiceOther,

          otherText: ' ',

        ),

        isNull,

      );

    });



    test('returns null when nothing selected', () {

      expect(

        resolveNcrEvidenceChoiceValue(selected: null, otherText: ''),

        isNull,

      );

    });

  });

}

