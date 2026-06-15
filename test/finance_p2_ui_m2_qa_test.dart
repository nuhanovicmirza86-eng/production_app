import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/cash_transactions/models/finance_cash_transaction.dart';
import 'package:production_app/modules/finance/payment_allocations/widgets/finance_allocation_amount_field.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

void main() {
  const managerData = {
    'companyId': 'plamingo',
    'role': 'accounting_manager',
    'userId': 'mgr-1',
    'enabledModules': ['finance_controlling'],
  };

  const clerkData = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-1',
    'enabledModules': ['finance_controlling'],
  };

  test('RBAC: clerk može pregled/kreiranje, ne poništenje', () {
    expect(
      FinancePermissions.canViewPaymentAllocations(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
    expect(
      FinancePermissions.canCreatePaymentAllocation(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
    expect(
      FinancePermissions.canCancelPaymentAllocation(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
  });

  test('RBAC: manager može poništenje', () {
    expect(
      FinancePermissions.canCancelPaymentAllocation(
        companyData: managerData,
        role: 'accounting_manager',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  test('canAllocateToInvoices — posted, isActual, unallocated > 0', () {
    const tx = FinanceCashTransaction(
      id: 'tx1',
      companyId: 'plamingo',
      transactionCode: 'TX-1',
      status: 'posted',
      direction: 'inflow',
      amount: 1000,
      currency: 'BAM',
      baseCurrencyAmount: 1000,
      accountId: 'a1',
      cashFlowCategoryId: 'c1',
      isActual: true,
      allocatedAmount: 200,
      unallocatedAmount: 800,
    );
    expect(tx.canAllocateToInvoices, isTrue);
  });

  test('canAllocateToInvoices — draft isključen', () {
    const tx = FinanceCashTransaction(
      id: 'tx2',
      companyId: 'plamingo',
      transactionCode: 'TX-2',
      status: 'draft',
      direction: 'inflow',
      amount: 1000,
      currency: 'BAM',
      baseCurrencyAmount: 1000,
      accountId: 'a1',
      cashFlowCategoryId: 'c1',
      isActual: false,
    );
    expect(tx.canAllocateToInvoices, isFalse);
  });

  test('FinanceAllocationAmountUtils — zbir i granice', () {
    expect(FinanceAllocationAmountUtils.parsePositive('100.50'), 100.5);
    expect(FinanceAllocationAmountUtils.hasAtMostTwoDecimals('99.99'), isTrue);
    expect(FinanceAllocationAmountUtils.hasAtMostTwoDecimals('99.999'), isFalse);

    const openAmount = 250.0;
    const line1 = 150.0;
    const line2 = 100.0;
    final sum = FinanceAllocationAmountUtils.round2(line1 + line2);
    expect(sum <= openAmount + FinanceAllocationAmountUtils.tolerance, isTrue);

    const unallocated = 300.0;
    expect(sum <= unallocated + FinanceAllocationAmountUtils.tolerance, isTrue);
    expect(
      FinanceAllocationAmountUtils.round2(350.0) >
          unallocated + FinanceAllocationAmountUtils.tolerance,
      isTrue,
    );
  });
}
