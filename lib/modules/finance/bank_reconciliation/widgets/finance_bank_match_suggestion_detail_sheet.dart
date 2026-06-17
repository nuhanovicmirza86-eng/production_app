import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_host.dart';
import '../../shared/finance_assistant/finance_module_assistant_scope.dart';
import '../../shared/finance_system_bottom_inset.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../../shared/finance_label_with_term_help.dart';
import '../models/finance_bank_match_suggestion.dart';
import '../models/finance_bank_statement_transaction.dart';
import '../utils/finance_bank_match_suggestion_ui_helper.dart';

Future<void> showFinanceBankMatchSuggestionDetailSheet({
  required BuildContext context,
  required String companyId,
  required String role,
  required FinanceBankStatementTransaction bankTransaction,
  required FinanceBankMatchSuggestion suggestion,
  required bool canManage,
  required bool canConfirm,
  required bool dismissed,
  required Future<void> Function() onDismiss,
  required Future<void> Function() onRestore,
  required VoidCallback onContinueConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final available = <String>[];
        final disabled = <String>[];
        if (!dismissed && canManage) {
          available.add(FinanceStrings.t(context, 'bank_match_dismiss'));
        } else if (dismissed && canManage) {
          available.add(FinanceStrings.t(context, 'bank_match_restore_suggestion'));
        } else {
          disabled.add(FinanceStrings.t(context, 'bank_match_dismiss'));
        }
        final blocked = suggestion.isBlocked;
        if (!dismissed && canConfirm && !blocked) {
          available.add(FinanceStrings.t(context, 'bank_match_continue_confirm'));
        } else {
          disabled.add(FinanceStrings.t(context, 'bank_match_continue_confirm'));
        }
        return FinanceAssistantHost(
          contextData: FinanceAssistantContext(
            companyId: companyId,
            screenKey: FinanceAssistantScreens.bankMatchSuggestionDetail,
            tabKey: FinanceAssistantTabs.cashFlow,
            tabLabelKey: 'help_cash_flow_tab_title',
            role: role,
            entityStatus: FinanceBankMatchSuggestionUiHelper.confidenceLabel(
              context,
              suggestion,
            ),
            availableActions: available,
            disabledActions: disabled,
          ),
          showFab: false,
          child: _FinanceBankMatchSuggestionDetailBody(
            scrollController: scrollController,
            bankTransaction: bankTransaction,
            suggestion: suggestion,
            canManage: canManage,
            canConfirm: canConfirm,
            dismissed: dismissed,
            onDismiss: onDismiss,
            onRestore: onRestore,
            onContinueConfirm: onContinueConfirm,
          ),
        );
      },
    ),
  );
}

class _FinanceBankMatchSuggestionDetailBody extends StatelessWidget {
  const _FinanceBankMatchSuggestionDetailBody({
    required this.scrollController,
    required this.bankTransaction,
    required this.suggestion,
    required this.canManage,
    required this.canConfirm,
    required this.dismissed,
    required this.onDismiss,
    required this.onRestore,
    required this.onContinueConfirm,
  });

  final ScrollController scrollController;
  final FinanceBankStatementTransaction bankTransaction;
  final FinanceBankMatchSuggestion suggestion;
  final bool canManage;
  final bool canConfirm;
  final bool dismissed;
  final Future<void> Function() onDismiss;
  final Future<void> Function() onRestore;
  final VoidCallback onContinueConfirm;

  String _formatDate(BuildContext context, DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    final snap = suggestion.sourceSnapshot;
    final warnings = FinanceBankMatchSuggestionUiHelper.buildWarnings(
      context,
      suggestion,
    );
    final reasons = suggestion.matchedSignals
        .map((s) => FinanceBankMatchSuggestionUiHelper.signalSentence(context, s))
        .toList();
    final blocked = suggestion.isBlocked;
    final theme = Theme.of(context);

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        FinanceSystemBottomInset.scrollEnd(context),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                FinanceStrings.t(context, 'bank_match_detail_title'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: FinanceStrings.t(context, 'finance_assistant_fab_title'),
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () =>
                  FinanceModuleAssistantScope.maybeOf(context)?.openAssistant(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          FinanceStrings.t(context, 'bank_match_detail_bank_section'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _row(
          context,
          FinanceStrings.t(context, 'bank_match_bank_amount'),
          FinanceMoneyFormat.format(bankTransaction.amount, bankTransaction.currency),
        ),
        _row(context, FinanceStrings.t(context, 'filter_currency'), bankTransaction.currency),
        _row(
          context,
          FinanceStrings.t(context, 'bank_booking_date'),
          _formatDate(context, bankTransaction.bookingDate ?? snap?.bookingDate),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_value_date'),
          _formatDate(context, bankTransaction.valueDate),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_counterparty'),
          bankTransaction.counterpartyName ?? snap?.counterpartyName ?? '—',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_match_detail_partner_account'),
          snap?.counterpartyAccount ?? '—',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_reference'),
          bankTransaction.paymentReference ?? snap?.paymentReference ?? '—',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_description'),
          bankTransaction.rawDescription ?? snap?.rawDescription ?? '—',
        ),
        const SizedBox(height: 16),
        Text(
          FinanceStrings.t(context, 'bank_match_detail_invoice_section'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _row(
          context,
          FinanceStrings.t(context, 'bank_match_detail_invoice_number'),
          suggestion.invoiceNumber,
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_counterparty'),
          suggestion.displayPartnerName,
        ),
        if (snap?.invoiceTotalAmount != null && (snap!.invoiceTotalAmount! > 0))
          _row(
            context,
            FinanceStrings.t(context, 'bank_match_detail_invoice_total'),
            FinanceMoneyFormat.format(
              snap.invoiceTotalAmount!,
              suggestion.currency,
            ),
          ),
        FinanceLabelWithTermHelp(
          label: FinanceStrings.t(context, 'bank_match_open_amount'),
          value: FinanceMoneyFormat.format(
            suggestion.invoiceOpenAmount,
            suggestion.currency,
          ),
          helpTitleKey: 'help_term_open_amount_title',
          helpBodyKey: 'help_term_open_amount_body',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'bank_match_detail_invoice_due'),
          _formatDate(context, snap?.dueDate),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'filter_direction'),
          suggestion.isSales
              ? FinanceStrings.t(context, 'bank_match_detail_invoice_type_sales')
              : FinanceStrings.t(context, 'bank_match_detail_invoice_type_purchase'),
        ),
        FinanceLabelWithTermHelp(
          label: FinanceStrings.t(context, 'bank_match_confidence'),
          value: FinanceBankMatchSuggestionUiHelper.confidenceLabel(
            context,
            suggestion,
          ),
          helpTitleKey: 'help_term_match_confidence_title',
          helpBodyKey: 'help_term_match_confidence_body',
        ),
        const SizedBox(height: 16),
        Text(
          FinanceStrings.t(context, 'bank_match_detail_why'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (reasons.isEmpty)
          Text(FinanceStrings.t(context, 'bank_match_generate_none'))
        else
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $r'),
              )),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            FinanceStrings.t(context, 'bank_match_detail_warnings'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $w',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
        if (blocked) ...[
          const SizedBox(height: 16),
          Text(
            FinanceStrings.t(context, 'bank_match_detail_blocked_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          ...suggestion.blockingReasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${FinanceBankMatchSuggestionUiHelper.blockingSentence(context, r)}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          if (suggestion.blockingReasons.isEmpty)
            Text(
              FinanceStrings.t(context, 'bank_match_blocked_hint'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
        const SizedBox(height: 20),
        if (!dismissed && canManage)
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onDismiss();
            },
            child: Text(FinanceStrings.t(context, 'bank_match_dismiss')),
          ),
        if (dismissed && canManage)
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onRestore();
            },
            child: Text(FinanceStrings.t(context, 'bank_match_restore_suggestion')),
          ),
        if (!dismissed && canConfirm && !blocked) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onContinueConfirm();
            },
            child: Text(FinanceStrings.t(context, 'bank_match_continue_confirm')),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(FinanceStrings.t(context, 'bank_match_detail_back')),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
