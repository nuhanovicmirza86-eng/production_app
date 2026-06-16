import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';

/// Prikaz backend metrika — bez lokalnog KPI računanja.
class FinanceAiKpiFormatters {
  FinanceAiKpiFormatters._();

  static String rateLabel(
    BuildContext context,
    FinanceAiKpiRateMetric metric, {
    required String percentTitle,
    required String numeratorLabel,
    required String denominatorLabel,
  }) {
    if (metric.rate == null) {
      return FinanceStrings.t(context, 'kpi_insufficient_data');
    }
    final pct = NumberFormat.decimalPercentPattern(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 0,
    ).format(metric.rate);
    return '$percentTitle: $pct\n'
        '${metric.numerator} $numeratorLabel / ${metric.denominator} $denominatorLabel';
  }

  static String percentOnly(BuildContext context, FinanceAiKpiRateMetric metric) {
    if (metric.rate == null) {
      return FinanceStrings.t(context, 'kpi_insufficient_data');
    }
    return NumberFormat.decimalPercentPattern(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 0,
    ).format(metric.rate);
  }

  static String durationMs(BuildContext context, int? ms) {
    if (ms == null) {
      return FinanceStrings.t(context, 'kpi_insufficient_data');
    }
    final totalMinutes = ms ~/ 60000;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return FinanceStrings.t(context, 'kpi_duration_hours_minutes')
          .replaceAll('{hours}', '$hours')
          .replaceAll('{minutes}', '$minutes');
    }
    if (minutes > 0) {
      return FinanceStrings.t(context, 'kpi_duration_minutes')
          .replaceAll('{minutes}', '$minutes');
    }
    return FinanceStrings.t(context, 'kpi_duration_under_minute');
  }

  static String formatAmount(BuildContext context, double amount, String currency) {
    final locale = Localizations.localeOf(context).toString();
    final numFmt = NumberFormat('#,##0.00', locale);
    final cur = currency.trim().isEmpty ? '' : currency.trim().toUpperCase();
    if (cur.isEmpty) return numFmt.format(amount);
    return '$cur: ${numFmt.format(amount)}';
  }
}
