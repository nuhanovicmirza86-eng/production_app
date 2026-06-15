import 'package:flutter/widgets.dart';

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

  static String advisorySnapshotKey(BuildContext context, String key) {
    switch (key.trim()) {
      case 'amount':
      case 'nominalAmount':
      case 'weightedAmount':
      case 'balance':
      case 'threshold':
      case 'minimumCashReserve':
        return FinanceStrings.t(context, key);
      default:
        return key.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim();
    }
  }

  static String advisoryConfidenceFactorKey(BuildContext context, String key) {
    return key.replaceAll('_', ' ');
  }
}
