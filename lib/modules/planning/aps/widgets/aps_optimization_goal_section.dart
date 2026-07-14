import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_optimization_goal.dart';
import '../models/aps_objective_profile_view.dart';
import 'aps_info_icon_button.dart';

/// Odabir cilja optimizacije — poslovni nazivi + opcionalni automatski prijedlog.
class ApsOptimizationGoalSection extends StatelessWidget {
  const ApsOptimizationGoalSection({
    super.key,
    required this.profiles,
    required this.objectiveProfileId,
    required this.suggestion,
    required this.suggestionDismissed,
    required this.busy,
    required this.onKindSelected,
    required this.onAcceptSuggestion,
    required this.onDismissSuggestion,
  });

  final List<ApsObjectiveProfileView> profiles;
  final String? objectiveProfileId;
  final ApsOptimizationGoalSuggestion? suggestion;
  final bool suggestionDismissed;
  final bool busy;
  final ValueChanged<ApsOptimizationGoalKind> onKindSelected;
  final VoidCallback onAcceptSuggestion;
  final VoidCallback onDismissSuggestion;

  bool get _hasProfiles => profiles.isNotEmpty;

  List<ApsOptimizationGoalKind> get _availableKinds =>
      ApsOptimizationGoalCatalog.allKinds
          .where((k) => ApsOptimizationGoalCatalog.profileForKind(k, profiles) != null)
          .toList();

  ApsOptimizationGoalKind? get _selectedKind =>
      ApsOptimizationGoalCatalog.kindForProfileId(objectiveProfileId, profiles);

  bool get _showSuggestionBanner {
    if (suggestionDismissed) return false;
    final s = suggestion;
    if (s == null || !_hasProfiles) return false;
    final current = _selectedKind;
    if (current == null) return true;
    return current != s.kind;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedKind = _selectedKind;
    final kinds = _availableKinds;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ApsGanttInfoCopy.optimizationGoalLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ApsInfoIconButton(
                  tooltip: 'O cilju optimizacije',
                  title: ApsGanttInfoCopy.optimizationGoalLabel,
                  body: ApsOptimizationGoalCatalog.generalInfoBody,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_hasProfiles || kinds.isEmpty)
              Text(
                ApsGanttInfoCopy.optimizationGoalMissingForCreate,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              )
            else ...[
              DropdownButtonFormField<ApsOptimizationGoalKind>(
                isExpanded: true,
                value: selectedKind != null && kinds.contains(selectedKind)
                    ? selectedKind
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Odaberite cilj',
                ),
                items: kinds
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(ApsOptimizationGoalCatalog.label(k)),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (kind) {
                        if (kind != null) onKindSelected(kind);
                      },
              ),
              if (selectedKind != null) ...[
                const SizedBox(height: 8),
                Text(
                  ApsOptimizationGoalCatalog.infoBody(selectedKind),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  ApsGanttInfoCopy.optimizationGoalMissingHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
            ],
            if (_showSuggestionBanner && suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predloženo: ${ApsOptimizationGoalCatalog.label(suggestion!.kind)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zašto: ${suggestion!.reason}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: busy ? null : onAcceptSuggestion,
                          child: const Text('Prihvati prijedlog'),
                        ),
                        TextButton(
                          onPressed: busy ? null : onDismissSuggestion,
                          child: const Text('Promijeni'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
