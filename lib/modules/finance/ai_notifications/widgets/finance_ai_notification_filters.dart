import 'package:flutter/material.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_plant_filter_dropdown.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';

class FinanceAiNotificationFilters extends StatelessWidget {
  const FinanceAiNotificationFilters({
    super.key,
    required this.companyId,
    required this.companyData,
    required this.role,
    required this.profilePlantKey,
    required this.filterPlantKey,
    required this.showHistory,
    required this.unreadOnly,
    required this.severityMin,
    required this.onPlantChanged,
    required this.onHistoryChanged,
    required this.onUnreadOnlyChanged,
    required this.onSeverityChanged,
  });

  final String companyId;
  final Map<String, dynamic> companyData;
  final String role;
  final String profilePlantKey;
  final String filterPlantKey;
  final bool showHistory;
  final bool unreadOnly;
  final String? severityMin;
  final ValueChanged<String> onPlantChanged;
  final ValueChanged<bool> onHistoryChanged;
  final ValueChanged<bool> onUnreadOnlyChanged;
  final ValueChanged<String?> onSeverityChanged;

  bool get _canPickPlant => FinancePermissions.shouldUseHubPlantScopeSelector(
        role: role,
        profilePlantKey: profilePlantKey,
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                FinanceStrings.t(context, 'notification_filter_active'),
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                FinanceStrings.t(context, 'notification_filter_history'),
              ),
            ),
          ],
          selected: {showHistory},
          onSelectionChanged: (s) => onHistoryChanged(s.first),
        ),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                FinanceStrings.t(context, 'notification_filter_all'),
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                FinanceStrings.t(context, 'notification_filter_unread'),
              ),
            ),
          ],
          selected: {unreadOnly},
          onSelectionChanged: (s) => onUnreadOnlyChanged(s.first),
        ),
        DropdownButton<String?>(
          value: severityMin,
          hint: Text(FinanceStrings.t(context, 'advisory_filter_severity')),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                FinanceStrings.t(context, 'advisory_filter_all_severities'),
              ),
            ),
            ...FinanceDisplayLabels.advisorySeverityCodes.map(
              (code) => DropdownMenuItem<String?>(
                value: code,
                child: Text(
                  FinanceDisplayLabels.advisorySeverity(context, code),
                ),
              ),
            ),
          ],
          onChanged: onSeverityChanged,
        ),
        if (_canPickPlant)
          FinancePlantFilterDropdown(
            companyId: companyId,
            selectedPlantKey: filterPlantKey,
            onChanged: onPlantChanged,
          ),
      ],
    );
  }
}
