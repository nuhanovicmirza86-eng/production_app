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
}
