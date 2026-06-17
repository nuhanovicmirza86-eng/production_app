import 'package:flutter/material.dart';

import 'finance_help_info_button.dart';

/// Red s labelom, vrijednošću i info ikonom za pojedinačni poslovni pojam (nivo 2 pomoći).
class FinanceLabelWithTermHelp extends StatelessWidget {
  const FinanceLabelWithTermHelp({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 150,
    this.helpTitleKey,
    this.helpBodyKey,
  });

  final String label;
  final String value;
  final double labelWidth;
  final String? helpTitleKey;
  final String? helpBodyKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (helpTitleKey != null && helpBodyKey != null)
                  FinanceHelpInfoButton(
                    titleKey: helpTitleKey!,
                    bodyKey: helpBodyKey!,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 2),
                  ),
              ],
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
