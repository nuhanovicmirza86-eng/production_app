import 'package:flutter/material.dart';

import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario_assumptions.dart';

class FinanceScenarioAssumptionsSection extends StatelessWidget {
  const FinanceScenarioAssumptionsSection({
    super.key,
    required this.assumptions,
    required this.readOnly,
    this.onWhatIfChanged,
  });

  final FinanceCashFlowScenarioAssumptions assumptions;
  final bool readOnly;
  final void Function(String key, double? value)? onWhatIfChanged;

  static const _fieldOrder = [
    'receivableDelayDays',
    'payableDelayDays',
    'receivableProbabilityAdjustment',
    'payableProbabilityAdjustment',
    'plannedInflowAdjustmentPercent',
    'plannedOutflowAdjustmentPercent',
    'minimumLiquidityThreshold',
  ];

  @override
  Widget build(BuildContext context) {
    final en = FinanceStrings.isEnglish(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceStrings.t(context, 'scenario_section_assumptions'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final key in _fieldOrder)
          if (assumptions.entries.containsKey(key))
            _AssumptionRow(
              keyName: key,
              entry: assumptions.entries[key]!,
              english: en,
              readOnly: readOnly,
              onChanged: onWhatIfChanged,
            ),
      ],
    );
  }
}

class _AssumptionRow extends StatelessWidget {
  const _AssumptionRow({
    required this.keyName,
    required this.entry,
    required this.english,
    required this.readOnly,
    this.onChanged,
  });

  final String keyName;
  final FinanceCashFlowScenarioAssumptionEntry entry;
  final bool english;
  final bool readOnly;
  final void Function(String key, double? value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = entry.labelForLocale(english);
    final sourceLabel = entry.isPreset
        ? FinanceStrings.t(context, 'scenario_assumption_preset')
        : FinanceStrings.t(context, 'scenario_assumption_user');
    final unitLabel = _unitLabel(context, entry.unit);
    final valueText = entry.value == null
        ? FinanceStrings.t(context, 'scenario_assumption_empty')
        : '${entry.value} $unitLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    FinanceHelpInfoButton(
                      titleKey: 'scenario_assumption_${keyName}_title',
                      bodyKey: 'scenario_assumption_${keyName}_body',
                      iconSize: 18,
                    ),
                  ],
                ),
                if (!readOnly && onChanged != null)
                  _WhatIfField(
                    keyName: keyName,
                    entry: entry,
                    onChanged: onChanged!,
                  )
                else
                  Text(
                    '$valueText · $sourceLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _unitLabel(BuildContext context, String unit) {
    switch (unit) {
      case 'days':
        return FinanceStrings.t(context, 'scenario_unit_days');
      case 'percent':
        return FinanceStrings.t(context, 'scenario_unit_percent');
      case 'currency':
        return FinanceStrings.t(context, 'scenario_unit_currency');
      default:
        return unit;
    }
  }
}

class _WhatIfField extends StatefulWidget {
  const _WhatIfField({
    required this.keyName,
    required this.entry,
    required this.onChanged,
  });

  final String keyName;
  final FinanceCashFlowScenarioAssumptionEntry entry;
  final void Function(String key, double? value) onChanged;

  @override
  State<_WhatIfField> createState() => _WhatIfFieldState();
}

class _WhatIfFieldState extends State<_WhatIfField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.entry.value?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: FinanceStrings.t(context, 'scenario_assumption_value'),
      ),
      onChanged: (v) {
        if (v.trim().isEmpty) {
          widget.onChanged(widget.keyName, null);
          return;
        }
        final n = double.tryParse(v.replaceAll(',', '.'));
        widget.onChanged(widget.keyName, n);
      },
    );
  }
}
