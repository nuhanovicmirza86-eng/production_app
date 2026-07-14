import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../models/aps_scenario_view.dart';
import 'aps_pilot_validation_badge.dart';
/// Odabir APS scenarija — prikaz [scenarioName] / [scenarioCode], ne doc id.
class ApsScenarioPicker extends StatelessWidget {
  const ApsScenarioPicker({
    super.key,
    required this.scenarios,
    required this.selected,
    required this.onChanged,
    this.loading = false,
  });

  final List<ApsScenarioView> scenarios;
  final ApsScenarioView? selected;
  final ValueChanged<ApsScenarioView?> onChanged;
  final bool loading;

  static final _dateFmt = DateFormat('d.M.yyyy.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Scenarij', style: theme.textTheme.titleSmall),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Period scenarija',
                  icon: const Icon(Icons.info_outline, size: 18),
                  onPressed: () => showApsGanttInfoDialog(
                    context,
                    title: 'Scenarij planiranja',
                    body: ApsGanttInfoCopy.scenarioPickerScheduleInfoBody,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ApsScenarioView>(
              isExpanded: true,
              value: selected,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              hint: const Text('Odaberite scenarij'),
              items: scenarios
                  .map(
                    (s) => DropdownMenuItem<ApsScenarioView>(
                      value: s,
                      child: Text(s.displayLabel, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : onChanged,
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              _HorizonLine(
                scenario: selected!,
                dateFmt: _dateFmt,
              ),
              if (selected!.isPilotReleasedToMes) ...[
                const SizedBox(height: 8),
                const ApsPilotValidationBadge(compact: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HorizonLine extends StatelessWidget {
  const _HorizonLine({required this.scenario, required this.dateFmt});

  final ApsScenarioView scenario;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final start = scenario.periodStart;
    final end = scenario.periodEnd;
    final theme = Theme.of(context);
    String horizonText;
    if (start != null && end != null) {
      horizonText = 'Period: ${dateFmt.format(start)} – ${dateFmt.format(end)}';
    } else {
      horizonText = ApsGanttInfoCopy.missingHorizonMessage;
    }
    return Text(
      horizonText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: start != null && end != null
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.error,
      ),
    );
  }
}
