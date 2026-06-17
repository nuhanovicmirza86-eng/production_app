import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/bank_reconciliation/models/finance_bank_match_suggestion.dart';
import 'package:production_app/modules/finance/bank_reconciliation/models/finance_bank_statement_transaction.dart';
import 'package:production_app/modules/finance/bank_reconciliation/utils/finance_bank_match_suggestion_ui_helper.dart';
import 'package:production_app/modules/finance/bank_reconciliation/utils/finance_bank_reconciliation_revision.dart';
import 'package:production_app/modules/finance/payment_allocations/widgets/finance_allocation_amount_field.dart';
import 'package:production_app/modules/finance/shared/finance_callable_utils.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

void main() {
  group('FinanceCallableUtils', () {
    test('parseTimestamp accepts Firestore _seconds map from Callable JSON', () {
      final dt = FinanceCallableUtils.parseTimestamp({
        '_seconds': 1_700_000_000,
        '_nanoseconds': 0,
      });
      expect(dt, isNotNull);
      expect(dt!.millisecondsSinceEpoch, isPositive);
    });

    test('fromCallableMap parses bookingDate from _seconds map', () {
      final txn = FinanceBankStatementTransaction.fromCallableMap('t1', {
        'companyId': 'c1',
        'status': 'unmatched',
        'direction': 'inflow',
        'amount': 100,
        'currency': 'BAM',
        'bookingDate': {'_seconds': 1_700_000_000, '_nanoseconds': 0},
      });
      expect(txn.bookingDate, isNotNull);
    });

    test('reconciled line cannot be ignored or re-confirmed', () {
      const txn = FinanceBankStatementTransaction(
        id: 't1',
        companyId: 'c1',
        status: 'reconciled',
        direction: 'inflow',
        amount: 700,
        currency: 'EUR',
      );
      expect(txn.canIgnore, isFalse);
      expect(txn.canConfirmMatch, isFalse);
      expect(txn.isPostedLike, isTrue);
      expect(txn.canGenerateSuggestions, isFalse);
    });

    test('unmatched line can be ignored', () {
      const txn = FinanceBankStatementTransaction(
        id: 't1',
        companyId: 'c1',
        status: 'unmatched',
        direction: 'inflow',
        amount: 100,
        currency: 'EUR',
      );
      expect(txn.canIgnore, isTrue);
      expect(txn.canConfirmMatch, isTrue);
      expect(txn.canGenerateSuggestions, isTrue);
    });
  });

  group('FinanceBankReconciliationRevision', () {
    test('computeBankRevision is stable for known payload', () {
      final revision = FinanceBankReconciliationRevision.computeBankRevision({
        'updatedAt': {'seconds': 1_700_000_000},
        'sourceHash': 'abc',
        'status': 'unmatched',
        'amount': 1500,
        'currency': 'bam',
      });
      expect(revision.length, 32);
      expect(
        revision,
        FinanceBankReconciliationRevision.computeBankRevision({
          'updatedAt': {'seconds': 1_700_000_000},
          'sourceHash': 'abc',
          'status': 'unmatched',
          'amount': 1500,
          'currency': 'bam',
        }),
      );
    });

    test('computeInvoiceRevision uses canonicalOpenAmount when present', () {
      final withCanonical =
          FinanceBankReconciliationRevision.computeInvoiceRevision({
            'updatedAt': {'seconds': 1_700_000_000},
            'openAmount': 200,
            'canonicalOpenAmount': 150,
            'paidAmount': 50,
            'status': 'partial',
            'syncConflictStatus': '',
          });
      final withoutCanonical =
          FinanceBankReconciliationRevision.computeInvoiceRevision({
            'updatedAt': {'seconds': 1_700_000_000},
            'openAmount': 200,
            'paidAmount': 50,
            'status': 'partial',
            'syncConflictStatus': '',
          });
      expect(withCanonical, isNot(withoutCanonical));
    });
  });

  group('FinanceBankMatchSuggestionUiHelper', () {
    FinanceBankMatchSuggestion sug({
      required String id,
      required int score,
      String status = 'active',
    }) {
      return FinanceBankMatchSuggestion(
        id: id,
        companyId: 'c1',
        bankStatementTransactionId: 'b1',
        invoiceType: 'sales',
        invoiceId: 'inv$id',
        invoiceNumber: 'INV-$id',
        status: status,
        matchScore: score,
        confidenceLevel: score >= 80 ? 'high' : 'medium',
        invoiceOpenAmount: 1000,
        bankAmount: 1000,
        currency: 'BAM',
        direction: 'inflow',
        matchedSignals: const ['exact_amount'],
        blockingReasons: const [],
        partnerName: 'Partner $id',
      );
    }

    test('partitionActive keeps weak suggestions separate from primary list', () {
      final partition = FinanceBankMatchSuggestionUiHelper.partitionActive([
        sug(id: 'weak', score: 20),
        sug(id: 'med', score: 60),
        sug(id: 'high', score: 90),
      ]);
      expect(partition.primary.map((s) => s.id), ['high', 'med']);
      expect(partition.weak.map((s) => s.id), ['weak']);
    });

    test('partitionActive sorts high before medium and by score desc', () {
      final partition = FinanceBankMatchSuggestionUiHelper.partitionActive([
        sug(id: 'm1', score: 55),
        sug(id: 'h1', score: 95),
        sug(id: 'm2', score: 70),
        sug(id: 'h2', score: 85),
      ]);
      expect(partition.primary.map((s) => s.id), ['h1', 'h2', 'm2', 'm1']);
    });

    test('partitionActive caps primary list at 10 useful suggestions', () {
      final many = List.generate(
        12,
        (i) => sug(id: '$i', score: 80 + i),
      );
      final partition = FinanceBankMatchSuggestionUiHelper.partitionActive(many);
      expect(partition.primary.length, 10);
      expect(partition.hiddenUsefulCount, 2);
      expect(partition.primary.first.matchScore, 91);
    });

    test('partitionActive excludes dismissed suggestions from primary', () {
      final partition = FinanceBankMatchSuggestionUiHelper.partitionActive([
        sug(id: 'active', score: 90),
        sug(id: 'dismissed', score: 95, status: 'dismissed'),
      ]);
      expect(partition.primary.map((s) => s.id), ['active']);
    });
  });

  group('FinanceAllocationAmountUtils', () {
    test('parsePositive accepts decimal comma', () {
      expect(
        FinanceAllocationAmountUtils.parsePositive('550,00'),
        550.0,
      );
    });

    test('parsePositive accepts decimal dot', () {
      expect(
        FinanceAllocationAmountUtils.parsePositive('550.00'),
        550.0,
      );
    });
  });

  group('FinancePermissions bank reconciliation', () {
    const companyData = {'companyId': 'c1', 'enabledModules': ['finance_controlling']};

    test('clerk can view but not confirm', () {
      expect(
        FinancePermissions.canViewBankReconciliation(
          companyData: companyData,
          role: 'accounting_clerk',
        ),
        isTrue,
      );
      expect(
        FinancePermissions.canConfirmBankMatch(
          companyData: companyData,
          role: 'accounting_clerk',
        ),
        isFalse,
      );
    });

    test('manager can confirm and import', () {
      expect(
        FinancePermissions.canImportBankStatements(
          companyData: companyData,
          role: 'accounting_manager',
        ),
        isTrue,
      );
      expect(
        FinancePermissions.canConfirmBankMatch(
          companyData: companyData,
          role: 'accounting_manager',
        ),
        isTrue,
      );
    });
  });
}
