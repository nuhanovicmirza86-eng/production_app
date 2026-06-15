import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/invoices/models/finance_open_items_summary.dart';
import 'package:production_app/modules/finance/invoices/screens/finance_invoices_hub_tab_body.dart';
import 'package:production_app/modules/finance/invoices/models/finance_sales_invoice.dart';
import 'package:production_app/modules/finance/invoices/widgets/finance_invoice_widgets.dart';
import 'package:production_app/modules/finance/shared/finance_money_format.dart';
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

  Widget wrap(Widget child, {Locale locale = const Locale('bs')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bs'), Locale('en')],
      home: Scaffold(body: child),
    );
  }

  testWidgets('hub tab prikazuje 4 ulaza za manager', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceInvoicesHubTabBody(
          companyData: managerData,
          debugUnlockModule: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Izlazne fakture'), findsOneWidget);
    expect(find.text('Ulazne fakture'), findsOneWidget);
    expect(find.text('Potraživanja'), findsOneWidget);
    expect(find.text('Obaveze'), findsOneWidget);
  });

  testWidgets('EN lokalizacija hub kartica', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceInvoicesHubTabBody(
          companyData: managerData,
          debugUnlockModule: true,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sales invoices'), findsOneWidget);
    expect(find.text('Receivables'), findsOneWidget);
  });

  test('RBAC: clerk nema issue/approve/cancel', () {
    expect(
      FinancePermissions.canIssueSalesInvoice(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
    expect(
      FinancePermissions.canApprovePurchaseInvoice(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
    expect(
      FinancePermissions.canCancelFinanceInvoice(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
  });

  test('RBAC: manager ima issue/approve/cancel', () {
    expect(
      FinancePermissions.canIssueSalesInvoice(
        companyData: managerData,
        role: 'accounting_manager',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  test('ERP faktura model — isErpSynced i read-only semantika', () {
    const invoice = FinanceSalesInvoice(
      id: 'inv-erp',
      companyId: 'plamingo',
      invoiceNumber: 'SI-ERP-001',
      status: 'draft',
      totalAmount: 100,
      paidAmount: 0,
      openAmount: 100,
      currency: 'BAM',
      customerId: 'c1',
      erpSyncKey: 'erp:123',
      syncStatus: 'synced',
    );

    expect(invoice.isErpSynced, isTrue);
    expect(invoice.erpSyncKey, 'erp:123');
  });

  testWidgets('isOverdue chip — samo prikaz iz backend flag-a', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceInvoiceStatusChip(
          status: 'open',
          isOverdue: true,
          isErpSynced: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dospjelo'), findsOneWidget);
    expect(find.text('ERP'), findsOneWidget);
  });

  testWidgets('summary kartica prikazuje backend agregate', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceInvoiceSummaryCard(
          summary: FinanceOpenItemsSummary(
            companyId: 'plamingo',
            invoiceCount: 7,
            totalOpenAmount: 12345.67,
            overdueCount: 2,
            overdueAmount: 500,
          ),
          currencyHint: 'BAM',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('12,345.67'), findsOneWidget);
  });

  testWidgets('dugi broj i veliki iznos — Wrap chip bez overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        ListTile(
          title: const Text('SI-VERY-LONG-NUMBER-2026-0000123456789'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(FinanceMoneyFormat.format(1234567890.12, 'BAM')),
              const FinanceInvoiceStatusChip(
                status: 'partial',
                isOverdue: true,
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('FinanceMoneyFormat formatira velike iznose', () {
    final s = FinanceMoneyFormat.format(1234567890.12, 'BAM');
    expect(s, contains('1,234,567,890.12'));
    expect(s, contains('BAM'));
  });
}
