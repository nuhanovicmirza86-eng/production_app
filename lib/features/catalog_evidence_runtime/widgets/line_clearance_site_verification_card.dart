import 'package:flutter/material.dart';

import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../utils/line_clearance_verification.dart';

/// HOTFIX-27 — zaključani sažetak predaje + samo terenska potvrda.
class LineClearanceSiteVerificationCard extends StatelessWidget {
  const LineClearanceSiteVerificationCard({
    super.key,
    required this.state,
    required this.enabled,
    required this.placeLabel,
    required this.clearanceTypeLabel,
    required this.shiftLabel,
    required this.performedByName,
    required this.correctionController,
    required this.onChanged,
  });

  final StructuredProfileSessionState state;
  final bool enabled;
  final String placeLabel;
  final String clearanceTypeLabel;
  final String shiftLabel;
  final String performedByName;
  final TextEditingController correctionController;
  final VoidCallback onChanged;

  bool? get _siteChecked =>
      parseEvidenceYesNo(state.fieldValues[lineClearanceSiteConditionCheckedKey]);

  bool? get _ready =>
      parseEvidenceYesNo(state.fieldValues[lineClearanceReadyForWorkKey]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final comment = (state.fieldValues['operatorComment'] ?? '')
        .toString()
        .trim();
    final showCorrection = _ready == false;

    return Card(
      color: cs.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lineClearanceSiteVerificationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              lineClearanceSiteCheckHelper,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _lockedRow(
              context,
              lineClearanceTypeLabel,
              clearanceTypeLabel,
            ),
            _lockedRow(context, lineClearancePlaceLabel, placeLabel),
            _lockedRow(context, lineClearanceShiftLabel, shiftLabel),
            _lockedRow(
              context,
              lineClearanceStartLabel,
              lineClearanceDateTimeLabel(
                state.fieldValues['clearanceStartedAt'],
              ),
            ),
            _lockedRow(
              context,
              lineClearanceEndLabel,
              lineClearanceDateTimeLabel(
                state.fieldValues['clearanceFinishedAt'],
              ),
            ),
            _lockedRow(
              context,
              lineClearanceChecklistLabel,
              formatEvidenceYesNo(state.fieldValues['checklistConfirmed']),
            ),
            _lockedRow(
              context,
              lineClearancePerformedByLabel,
              performedByName,
            ),
            if (comment.isNotEmpty)
              _lockedRow(
                context,
                lineClearanceOperatorCommentLabel,
                comment,
              ),
            const SizedBox(height: 16),
            _yesNoField(
              context,
              label: lineClearanceSiteConditionCheckedLabel,
              requiredField: true,
              value: _siteChecked,
              onChanged: enabled
                  ? (next) {
                      if (next == null) {
                        state.fieldValues
                            .remove(lineClearanceSiteConditionCheckedKey);
                      } else {
                        state.fieldValues[lineClearanceSiteConditionCheckedKey] =
                            next;
                      }
                      onChanged();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _yesNoField(
              context,
              label: lineClearanceReadyForWorkLabel,
              requiredField: true,
              value: _ready,
              onChanged: enabled
                  ? (next) {
                      if (next == null) {
                        state.fieldValues.remove(lineClearanceReadyForWorkKey);
                      } else {
                        state.fieldValues[lineClearanceReadyForWorkKey] = next;
                      }
                      if (next != false) {
                        state.fieldValues
                            .remove(lineClearanceReadinessCorrectionKey);
                        if (correctionController.text.isNotEmpty) {
                          correctionController.clear();
                        }
                      }
                      onChanged();
                    }
                  : null,
            ),
            if (showCorrection) ...[
              const SizedBox(height: 12),
              TextField(
                controller: correctionController,
                enabled: enabled,
                maxLines: 3,
                maxLength: 512,
                decoration: InputDecoration(
                  labelText: '$lineClearanceReadinessCorrectionLabel *',
                  border: const OutlineInputBorder(),
                  helperText:
                      'Obavezno ako linija / mašina nije spremna za rad.',
                  helperMaxLines: 2,
                ),
                onChanged: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isEmpty) {
                    state.fieldValues
                        .remove(lineClearanceReadinessCorrectionKey);
                  } else {
                    state.fieldValues[lineClearanceReadinessCorrectionKey] =
                        trimmed;
                  }
                  onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lockedRow(BuildContext context, String label, String value) {
    final text = value.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _yesNoField(
    BuildContext context, {
    required String label,
    required bool requiredField,
    required bool? value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: true, label: Text('DA')),
            ButtonSegment<bool>(value: false, label: Text('NE')),
          ],
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          selected: value == null ? <bool>{} : {value},
          onSelectionChanged: onChanged == null
              ? null
              : (next) => onChanged(next.isEmpty ? null : next.first),
        ),
      ),
    );
  }
}
