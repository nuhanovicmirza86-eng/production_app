import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_budget_actual_working_capital_snapshot.dart';

/// Prikaz backend vrijednosti — bez lokalnih finansijskih formula.
abstract final class FinanceBawcDisplay {
  FinanceBawcDisplay._();

  static const favorableGreen = Color(0xFF1B5E20);
  static const unfavorableOrange = Color(0xFFE65100);
  static const unfavorableRed = Color(0xFFC62828);

  static String formatMoney(double amount, String currency) {
    return FinanceMoneyFormat.format(amount, currency);
  }

  static String formatPercent(BuildContext context, double? percent) {
    if (percent == null) {
      return FinanceStrings.t(context, 'bawc_variance_not_applicable');
    }
    final fmt = NumberFormat('#,##0.##', 'en_US');
    return '${fmt.format(percent)}%';
  }

  static String formatDays(BuildContext context, double? days) {
    if (days == null) {
      return FinanceStrings.t(context, 'bawc_metric_unavailable');
    }
    final fmt = NumberFormat('#,##0.##', 'en_US');
    return '${fmt.format(days)} ${FinanceStrings.t(context, 'scenario_unit_days')}';
  }

  static Color? varianceColor({
    required double varianceAmount,
    required bool higherIsFavorable,
  }) {
    if (varianceAmount.abs() < 0.005) return null;
    final favorable = higherIsFavorable
        ? varianceAmount > 0
        : varianceAmount < 0;
    if (favorable) return favorableGreen;
    return varianceAmount.abs() > 0 ? unfavorableOrange : null;
  }

  static String formatVarianceAmount(double amount, String currency) {
    final prefix = amount > 0 ? '+' : '';
    return '$prefix${FinanceMoneyFormat.format(amount, currency)}';
  }

  /// Ne prikazivati Firestore ID-jeve ili interne ključeve u breakdownu.
  static bool looksLikeInternalRecordId(String value) {
    final s = value.trim();
    if (s.isEmpty || s == '_uncategorized' || s == '_company_wide') {
      return true;
    }
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(s)) return false;
    return RegExp(r'^[A-Za-z0-9_-]{15,}$').hasMatch(s);
  }

  static String categoryBreakdownLabel(
    BuildContext context,
    FinanceBudgetActualBreakdownRow row,
  ) {
    final uncategorized = FinanceStrings.t(context, 'bawc_uncategorized');
    if (row.key == '_uncategorized') return uncategorized;

    final name = row.categoryName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        !looksLikeInternalRecordId(name)) {
      return name;
    }
    return uncategorized;
  }
}

class FinanceBawcVarianceRow extends StatelessWidget {
  const FinanceBawcVarianceRow({
    super.key,
    required this.label,
    required this.planned,
    required this.actual,
    required this.varianceAmount,
    required this.variancePercent,
    required this.currency,
    required this.higherActualIsFavorable,
  });

  final String label;
  final double planned;
  final double actual;
  final double varianceAmount;
  final double? variancePercent;
  final String currency;
  final bool higherActualIsFavorable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final varianceColor = FinanceBawcDisplay.varianceColor(
      varianceAmount: varianceAmount,
      higherIsFavorable: higherActualIsFavorable,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _line(
            context,
            FinanceStrings.t(context, 'bawc_planned'),
            FinanceBawcDisplay.formatMoney(planned, currency),
          ),
          _line(
            context,
            FinanceStrings.t(context, 'bawc_actual'),
            FinanceBawcDisplay.formatMoney(actual, currency),
          ),
          _line(
            context,
            FinanceStrings.t(context, 'bawc_variance_amount'),
            FinanceBawcDisplay.formatVarianceAmount(varianceAmount, currency),
            valueColor: varianceColor,
          ),
          _line(
            context,
            FinanceStrings.t(context, 'bawc_variance_percent'),
            FinanceBawcDisplay.formatPercent(context, variancePercent),
            valueColor: variancePercent == null ? null : varianceColor,
          ),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceBawcMetricTile extends StatelessWidget {
  const FinanceBawcMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tooltip != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: tooltip!,
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceBawcBreakdownTable extends StatelessWidget {
  const FinanceBawcBreakdownTable({
    super.key,
    required this.title,
    required this.dimensionLabel,
    required this.rows,
    required this.currency,
    required this.labelForRow,
  });

  final String title;
  final String dimensionLabel;
  final List<FinanceBudgetActualBreakdownRow> rows;
  final String currency;
  final String Function(FinanceBudgetActualBreakdownRow row) labelForRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 44,
            columns: [
              DataColumn(label: Text(dimensionLabel)),
              DataColumn(
                label: Text(FinanceStrings.t(context, 'bawc_currency')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_planned_inflow')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_actual_inflow')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_planned_outflow')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_actual_outflow')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_planned_net')),
              ),
              DataColumn(
                numeric: true,
                label: Text(FinanceStrings.t(context, 'bawc_actual_net')),
              ),
            ],
            rows: rows.map((row) {
              final t = row.totals;
              return DataRow(
                cells: [
                  DataCell(Text(labelForRow(row))),
                  DataCell(Text(currency)),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.plannedInflow, currency))),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.actualInflow, currency))),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.plannedOutflow, currency))),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.actualOutflow, currency))),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.plannedNetCashFlow, currency))),
                  DataCell(Text(FinanceBawcDisplay.formatMoney(t.actualNetCashFlow, currency))),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
