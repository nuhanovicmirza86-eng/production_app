import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../ai_advisory/models/finance_ai_outcome_evidence.dart';
import '../bank_reconciliation/models/finance_bank_match_confirmation.dart';
import 'finance_money_format.dart';
import 'finance_strings.dart';

class FinanceDisplayLabels {
  FinanceDisplayLabels._();

  static String accountType(BuildContext context, String accountType) {
    switch (accountType.trim().toLowerCase()) {
      case 'transactional':
        return FinanceStrings.t(context, 'type_transactional');
      case 'foreign_currency':
        return FinanceStrings.t(context, 'type_foreign_currency');
      case 'cash_register':
        return FinanceStrings.t(context, 'type_cash_register');
      case 'virtual':
        return FinanceStrings.t(context, 'type_virtual');
      case 'credit_line':
        return FinanceStrings.t(context, 'type_credit_line');
      default:
        return accountType;
    }
  }

  static String activityType(BuildContext context, String activityType) {
    switch (activityType.trim().toLowerCase()) {
      case 'operating':
        return FinanceStrings.t(context, 'activity_operating');
      case 'investing':
        return FinanceStrings.t(context, 'activity_investing');
      case 'financing':
        return FinanceStrings.t(context, 'activity_financing');
      default:
        return activityType;
    }
  }

  static const accountTypeCodes = <String>[
    'transactional',
    'foreign_currency',
    'cash_register',
    'virtual',
    'credit_line',
  ];

  static const activityTypeCodes = <String>[
    'operating',
    'investing',
    'financing',
  ];

  static String transactionStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'draft':
        return FinanceStrings.t(context, 'tx_status_draft');
      case 'planned':
        return FinanceStrings.t(context, 'tx_status_planned');
      case 'posted':
        return FinanceStrings.t(context, 'tx_status_posted');
      case 'reconciled':
        return FinanceStrings.t(context, 'tx_status_reconciled');
      case 'cancelled':
        return FinanceStrings.t(context, 'tx_status_cancelled');
      default:
        return status;
    }
  }

  static String transactionDirection(BuildContext context, String direction) {
    switch (direction.trim().toLowerCase()) {
      case 'inflow':
        return FinanceStrings.t(context, 'direction_inflow');
      case 'outflow':
        return FinanceStrings.t(context, 'direction_outflow');
      default:
        return direction;
    }
  }

  static const transactionStatusCodes = <String>[
    'draft',
    'posted',
    'reconciled',
    'cancelled',
  ];

  static const transactionDirectionCodes = <String>[
    'inflow',
    'outflow',
  ];

  static String invoiceStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'draft':
        return FinanceStrings.t(context, 'inv_status_draft');
      case 'open':
        return FinanceStrings.t(context, 'inv_status_open');
      case 'partial':
        return FinanceStrings.t(context, 'inv_status_partial');
      case 'paid':
        return FinanceStrings.t(context, 'inv_status_paid');
      case 'cancelled':
        return FinanceStrings.t(context, 'inv_status_cancelled');
      default:
        return status;
    }
  }

  static const invoiceStatusCodes = <String>[
    'draft',
    'open',
    'partial',
    'paid',
    'cancelled',
  ];

  static String allocationStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
        return FinanceStrings.t(context, 'allocation_status_active');
      case 'cancelled':
        return FinanceStrings.t(context, 'allocation_status_cancelled');
      default:
        return status;
    }
  }

  static String plannedCashItemStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'draft':
        return FinanceStrings.t(context, 'planned_status_draft');
      case 'approved':
        return FinanceStrings.t(context, 'planned_status_approved');
      case 'cancelled':
        return FinanceStrings.t(context, 'planned_status_cancelled');
      default:
        return status;
    }
  }

  static const plannedCashItemStatusCodes = <String>[
    'draft',
    'approved',
    'cancelled',
  ];

  static String probabilitySource(BuildContext context, String source) {
    switch (source.trim().toLowerCase()) {
      case 'manual_confirmed':
        return FinanceStrings.t(context, 'prob_source_manual_confirmed');
      case 'company_rule':
        return FinanceStrings.t(context, 'prob_source_company_rule');
      case 'system_default':
        return FinanceStrings.t(context, 'prob_source_system_default');
      default:
        return source;
    }
  }

  static const probabilitySourceCodes = <String>[
    'manual_confirmed',
    'company_rule',
    'system_default',
  ];

  static String forecastBucketType(BuildContext context, String bucketType) {
    switch (bucketType.trim().toLowerCase()) {
      case 'day':
        return FinanceStrings.t(context, 'forecast_bucket_day');
      case 'week':
        return FinanceStrings.t(context, 'forecast_bucket_week');
      case 'month':
        return FinanceStrings.t(context, 'forecast_bucket_month');
      default:
        return bucketType;
    }
  }

  static const forecastBucketTypeCodes = <String>['day', 'week', 'month'];

  static String advisorySeverity(BuildContext context, String severity) {
    switch (severity.trim().toLowerCase()) {
      case 'info':
        return FinanceStrings.t(context, 'advisory_severity_info');
      case 'medium':
        return FinanceStrings.t(context, 'advisory_severity_medium');
      case 'high':
        return FinanceStrings.t(context, 'advisory_severity_high');
      case 'critical':
        return FinanceStrings.t(context, 'advisory_severity_critical');
      default:
        return severity;
    }
  }

  static const advisorySeverityCodes = <String>[
    'info',
    'medium',
    'high',
    'critical',
  ];

  static String advisoryStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return FinanceStrings.t(context, 'advisory_status_open');
      case 'acknowledged':
        return FinanceStrings.t(context, 'advisory_status_acknowledged');
      case 'resolved':
        return FinanceStrings.t(context, 'advisory_status_resolved');
      case 'dismissed':
        return FinanceStrings.t(context, 'advisory_status_dismissed');
      default:
        return status;
    }
  }

  static const advisoryStatusCodes = <String>[
    'open',
    'acknowledged',
    'resolved',
    'dismissed',
  ];

  static String notificationDeliveryStatus(
    BuildContext context,
    String status,
  ) {
    switch (status.trim().toLowerCase()) {
      case 'unread':
        return FinanceStrings.t(context, 'notification_status_unread');
      case 'read':
        return FinanceStrings.t(context, 'notification_status_read');
      case 'acknowledged':
        return FinanceStrings.t(context, 'notification_status_acknowledged');
      case 'superseded':
        return FinanceStrings.t(context, 'notification_status_superseded');
      case 'closed':
        return FinanceStrings.t(context, 'notification_status_closed');
      default:
        return status;
    }
  }

  static const notificationDeliveryStatusCodes = <String>[
    'unread',
    'read',
    'acknowledged',
    'superseded',
    'closed',
  ];

  static String advisoryRuleId(BuildContext context, String ruleId) {
    final key = 'advisory_rule_${ruleId.replaceAll('.', '_')}';
    final translated = FinanceStrings.t(context, key);
    if (translated != key) return translated;
    return ruleId;
  }

  static String advisoryConfidenceOrigin(BuildContext context, String origin) {
    switch (origin.trim().toLowerCase()) {
      case 'deterministic_only':
        return FinanceStrings.t(context, 'advisory_origin_deterministic_only');
      case 'deterministic_with_ai_interpretation':
        return FinanceStrings.t(
          context,
          'advisory_origin_deterministic_with_ai_interpretation',
        );
      case 'insufficient_facts':
        return FinanceStrings.t(context, 'advisory_origin_insufficient_facts');
      default:
        return origin;
    }
  }

  static String advisoryFactType(BuildContext context, String factType) {
    final key = 'advisory_fact_${factType.trim()}';
    final translated = FinanceStrings.t(context, key);
    if (translated != key) return translated;
    return factType;
  }

  static const _advisorySnapshotStringKeys = <String, String>{
    'accountCode': 'account_code',
    'currentBalance': 'current_balance',
    'currency': 'currency',
    'threshold': 'advisory_snapshot_threshold',
    'minimumCashReserve': 'advisory_snapshot_minimum_cash_reserve',
    'baseCurrency': 'advisory_snapshot_base_currency',
    'firstNominalBelowReserveDate':
        'advisory_snapshot_first_nominal_below_reserve_date',
    'firstWeightedBelowReserveDate':
        'advisory_snapshot_first_weighted_below_reserve_date',
    'minimumNominalBalance': 'advisory_snapshot_minimum_nominal_balance',
    'minimumWeightedBalance': 'advisory_snapshot_minimum_weighted_balance',
    'nominalNegativeBalanceExpected':
        'advisory_snapshot_nominal_negative_balance_expected',
    'weightedNegativeBalanceExpected':
        'advisory_snapshot_weighted_negative_balance_expected',
    'openAmount': 'open_amount',
    'dueDate': 'due_date',
    'customerName': 'advisory_snapshot_customer_name',
    'supplierName': 'advisory_snapshot_supplier_name',
    'direction': 'advisory_snapshot_direction',
    'amount': 'amount',
    'allocatedAmount': 'advisory_snapshot_allocated_amount',
    'unallocatedAmount': 'advisory_snapshot_unallocated_amount',
    'nominalAmount': 'advisory_snapshot_nominal_amount',
    'status': 'advisory_snapshot_status',
  };

  static const _advisoryConfidenceFactorStringKeys = <String, String>{
    'factCompleteness': 'advisory_factor_fact_completeness',
    'forecastHorizonDays': 'advisory_factor_forecast_horizon_days',
    'signalStrength': 'advisory_factor_signal_strength',
    'dataFreshnessMinutes': 'advisory_factor_data_freshness',
  };

  static String advisorySnapshotKey(BuildContext context, String key) {
    final trimmed = key.trim();
    final stringKey = _advisorySnapshotStringKeys[trimmed];
    if (stringKey != null) {
      return FinanceStrings.t(context, stringKey);
    }
    final snake = _camelToSnake(trimmed);
    final translated = FinanceStrings.t(context, snake);
    if (translated != snake) return translated;
    return _humanizeCamelCase(trimmed);
  }

  static String advisoryConfidenceFactorKey(BuildContext context, String key) {
    final trimmed = key.trim();
    final stringKey = _advisoryConfidenceFactorStringKeys[trimmed];
    if (stringKey != null) {
      return FinanceStrings.t(context, stringKey);
    }
    final snake = _camelToSnake(trimmed);
    final translated = FinanceStrings.t(context, snake);
    if (translated != snake) return translated;
    return _humanizeCamelCase(trimmed);
  }

  static String advisoryConfidenceFactorValue(
    BuildContext context,
    String key,
    dynamic value,
  ) {
    if (value is! num) return value?.toString() ?? '';
    final n = value.toDouble();
    switch (key.trim()) {
      case 'factCompleteness':
      case 'signalStrength':
        return '${n.round()}%';
      case 'forecastHorizonDays':
        final days = n.round();
        if (days == 1) {
          return FinanceStrings.t(context, 'advisory_factor_days_one');
        }
        return FinanceStrings.t(context, 'advisory_factor_days_many')
            .replaceAll('{count}', '$days');
      case 'dataFreshnessMinutes':
        if (n <= 0) {
          return FinanceStrings.t(context, 'advisory_freshness_current');
        }
        final minutes = n.round();
        if (minutes < 60) {
          return FinanceStrings.t(context, 'advisory_freshness_minutes')
              .replaceAll('{count}', '$minutes');
        }
        final hours = (minutes / 60).round();
        return FinanceStrings.t(context, 'advisory_freshness_hours')
            .replaceAll('{count}', '$hours');
      default:
        return n == n.roundToDouble()
            ? n.toStringAsFixed(0)
            : n.toStringAsFixed(2);
    }
  }

  static String advisorySnapshotValue(
    BuildContext context,
    String key,
    dynamic value,
  ) {
    if (value == null) return '';
    final k = key.trim().toLowerCase();
    if (value is bool) {
      return value
          ? FinanceStrings.t(context, 'forecast_yes')
          : FinanceStrings.t(context, 'forecast_no');
    }
    if (k == 'direction' && value is String) {
      return transactionDirection(context, value);
    }
    if (k == 'status' && value is String) {
      final status = value.trim().toLowerCase();
      if (status == 'draft') {
        return plannedCashItemStatus(context, value);
      }
      return invoiceStatus(context, value);
    }
    if (value is num &&
        (k.contains('amount') ||
            k.contains('balance') ||
            k.contains('threshold') ||
            k.contains('reserve'))) {
      return FinanceMoneyFormat.format(value.toDouble(), null);
    }
    if (k.contains('date') && value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        final locale = Localizations.localeOf(context).toString();
        return DateFormat.yMMMd(locale).format(parsed.toLocal());
      }
    }
    return value.toString();
  }

  static String _camelToSnake(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]?.toLowerCase()}',
        )
        .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'),
          (m) => '${m[1]?.toLowerCase()}_${m[2]}',
        )
        .toLowerCase();
  }

  static String _humanizeCamelCase(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' ')
        .trim();
  }

  static String humanizeToken(String key) => _humanizeCamelCase(key);

  static String advisoryOutcomeStatus(BuildContext context, String status) {
    final key = 'advisory_outcome_status_${status.trim()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return _humanizeCamelCase(status);
  }

  static String advisoryOutcomeStatusMessage(BuildContext context, String status) {
    final key = 'advisory_outcome_message_${status.trim()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return advisoryOutcomeStatus(context, status);
  }

  static String advisoryOutcomeAttribution(BuildContext context, String level) {
    switch (level.trim().toLowerCase()) {
      case 'direct':
        return FinanceStrings.t(context, 'advisory_outcome_attribution_direct');
      case 'contributing':
        return FinanceStrings.t(
          context,
          'advisory_outcome_attribution_contributing',
        );
      case 'uncertain':
        return FinanceStrings.t(context, 'advisory_outcome_attribution_uncertain');
      case 'not_attributable':
        return FinanceStrings.t(
          context,
          'advisory_outcome_attribution_not_attributable',
        );
      default:
        return _humanizeCamelCase(level);
    }
  }

  static String advisoryOutcomeConfirmationMethod(
    BuildContext context,
    String method,
  ) {
    switch (method.trim().toLowerCase()) {
      case 'overdue_amount_reduction':
        return FinanceStrings.t(
          context,
          'advisory_outcome_confirmation_overdue_amount_reduction',
        );
      case 'invoice_payment_timing':
        return FinanceStrings.t(
          context,
          'advisory_outcome_confirmation_invoice_payment_timing',
        );
      case 'forecast_risk_removed':
        return FinanceStrings.t(
          context,
          'advisory_outcome_confirmation_forecast_risk_removed',
        );
      default:
        return _humanizeCamelCase(method);
    }
  }

  static String advisoryOutcomeEvidenceMeasured(
    BuildContext context,
    FinanceAiOutcomeEvidence evidence,
  ) {
    final field = evidence.sourceFieldPath.trim().toLowerCase();
    if (field.contains('overdue')) {
      return FinanceStrings.t(context, 'advisory_outcome_evidence_overdue_amount');
    }
    if (field.contains('openamount') || field == 'open_amount') {
      return FinanceStrings.t(context, 'advisory_outcome_evidence_open_amount');
    }
    if (evidence.evidenceType.trim().toLowerCase().contains('forecast')) {
      return FinanceStrings.t(context, 'advisory_outcome_evidence_forecast_signal');
    }
    final type = evidence.evidenceType.trim();
    if (type.isNotEmpty) {
      final key = 'advisory_outcome_evidence_${type.replaceAll('.', '_')}';
      final localized = FinanceStrings.t(context, key);
      if (localized != key) return localized;
      return _humanizeCamelCase(type);
    }
    if (field.isNotEmpty) return _humanizeCamelCase(field);
    return FinanceStrings.t(context, 'advisory_outcome_evidence_title');
  }

  static const bankStatementStatusCodes = <String>[
    'imported',
    'unmatched',
    'suggested',
    'confirmed',
    'posted',
    'partially_reconciled',
    'reconciled',
    'ignored',
  ];

  static String bankStatementStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'imported':
        return FinanceStrings.t(context, 'bank_status_imported');
      case 'unmatched':
        return FinanceStrings.t(context, 'bank_status_unmatched');
      case 'suggested':
        return FinanceStrings.t(context, 'bank_status_suggested');
      case 'confirmed':
        return FinanceStrings.t(context, 'bank_status_confirmed');
      case 'posted':
        return FinanceStrings.t(context, 'bank_status_posted');
      case 'partially_reconciled':
        return FinanceStrings.t(context, 'bank_status_partially_reconciled');
      case 'reconciled':
        return FinanceStrings.t(context, 'bank_status_reconciled');
      case 'ignored':
        return FinanceStrings.t(context, 'bank_status_ignored');
      default:
        return status;
    }
  }

  static String matchConfidence(BuildContext context, String level) {
    switch (level.trim().toLowerCase()) {
      case 'high':
        return FinanceStrings.t(context, 'bank_match_confidence_high');
      case 'medium':
        return FinanceStrings.t(context, 'bank_match_confidence_medium');
      case 'low':
        return FinanceStrings.t(context, 'bank_match_confidence_low');
      default:
        return level;
    }
  }

  static String matchSignal(BuildContext context, String signal) {
    final key = 'bank_signal_${signal.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return _humanizeCamelCase(signal);
  }

  static String blockingReason(BuildContext context, String reason) {
    final key = 'bank_blocking_${reason.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return _humanizeCamelCase(reason);
  }

  static String reconciliationStatus(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'reconciled':
        return FinanceStrings.t(context, 'bank_status_reconciled');
      case 'partially_reconciled':
        return FinanceStrings.t(context, 'bank_status_partially_reconciled');
      default:
        return status;
    }
  }

  static String bankMatchConfirmationStatus(
    BuildContext context,
    FinanceBankMatchConfirmation confirmation,
  ) {
    if (confirmation.isCancelled) {
      return FinanceStrings.t(context, 'tx_status_cancelled');
    }
    return reconciliationStatus(context, confirmation.reconciliationStatus);
  }
}
