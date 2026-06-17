import 'package:flutter/widgets.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';

class FinanceBankAuditTrailLabels {
  FinanceBankAuditTrailLabels._();

  static String actionLabel(BuildContext context, String action) {
    final key = 'audit_action_${action.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return FinanceDisplayLabels.humanizeToken(action);
  }

  static String entityTypeLabel(BuildContext context, String entityType) {
    final key = 'audit_entity_${entityType.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return FinanceDisplayLabels.humanizeToken(entityType);
  }

  static String sourceLabel(BuildContext context, String? source) {
    if (source == null || source.trim().isEmpty) return '—';
    final key = 'audit_source_${source.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return source;
  }

  static String performerLabel({
    required String? email,
    required String? role,
  }) {
    final parts = <String>[];
    if (email != null && email.isNotEmpty) parts.add(email);
    if (role != null && role.isNotEmpty) parts.add(role);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static String fieldLabel(BuildContext context, String key) {
    const keyMap = <String, String>{
      'status': 'filter_status',
      'reconciliationStatus': 'filter_status',
      'transactionCode': 'transaction_code',
      'confirmationCode': 'bank_match_confirmation_unlabeled',
      'allocationCode': 'allocation_line_amount',
      'invoiceNumber': 'invoice_number',
      'amount': 'amount',
      'currency': 'currency',
      'direction': 'filter_direction',
      'totalBankAmount': 'bank_match_bank_amount',
      'totalAllocatedAmount': 'bank_match_allocated',
      'unallocatedAmount': 'bank_match_unallocated',
      'counterpartyName': 'bank_counterparty',
      'rawDescription': 'description',
      'paymentReference': 'bank_signal_payment_reference_exact',
      'confidence': 'bank_match_confidence',
      'cancelReason': 'bank_match_cancel_reason',
      'confirmReason': 'bank_match_note',
      'invoiceType': 'invoice_number',
      'cashFlowCategoryCode': 'help_term_cash_flow_category_title',
    };
    final stringKey = keyMap[key];
    if (stringKey != null) {
      return FinanceStrings.t(context, stringKey);
    }
    return FinanceDisplayLabels.humanizeToken(key);
  }

  static String formatDisplayMap(BuildContext context, Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    final lines = <String>[];
    for (final key in keys) {
      final value = map[key];
      if (value == null || '$value'.trim().isEmpty) continue;
      final label = fieldLabel(context, key);
      var rendered = '$value';
      if (key == 'status' || key == 'reconciliationStatus') {
        rendered = FinanceDisplayLabels.reconciliationStatus(context, '$value');
      } else if (key == 'direction') {
        rendered = FinanceDisplayLabels.transactionDirection(context, '$value');
      }
      lines.add('$label: $rendered');
    }
    return lines.join('\n');
  }

  static String? summaryFromAfter(Map<String, dynamic>? after) {
    if (after == null || after.isEmpty) return null;
    final status = (after['status'] ?? '').toString().trim();
    if (status.isNotEmpty) return status;
    final reconciliationStatus =
        (after['reconciliationStatus'] ?? '').toString().trim();
    if (reconciliationStatus.isNotEmpty) return reconciliationStatus;
    return null;
  }
}
