import 'package:flutter/material.dart';

import '../helpers/aps_execution_watch_outcomes.dart';
import '../models/aps_execution_watch_alert_view.dart';

/// Rezultat potvrde ishoda (P6-1F / P6-1H).
class ApsExecutionWatchResolveResult {
  const ApsExecutionWatchResolveResult({
    required this.businessOutcome,
    this.resolutionNote,
    this.recommendationAccepted = false,
    this.estimatedAvoidedDelayMinutes,
    this.freedCapacityMinutes,
  });

  final String businessOutcome;
  final String? resolutionNote;
  final bool recommendationAccepted;
  final int? estimatedAvoidedDelayMinutes;
  final int? freedCapacityMinutes;

  Map<String, dynamic> valueMetricsPatch() {
    final map = <String, dynamic>{};
    if (estimatedAvoidedDelayMinutes != null) {
      map['estimatedAvoidedDelayMinutes'] = estimatedAvoidedDelayMinutes;
    }
    if (freedCapacityMinutes != null) {
      map['freedCapacityMinutes'] = freedCapacityMinutes;
    }
    return map;
  }
}

/// Dijalog za bilježenje poslovnog ishoda pri resolve (bez auto-izmene plana).
Future<ApsExecutionWatchResolveResult?> showApsExecutionWatchResolveDialog({
  required BuildContext context,
  required ApsExecutionWatchAlertView alert,
}) {
  return showDialog<ApsExecutionWatchResolveResult>(
    context: context,
    builder: (ctx) => _ApsExecutionWatchResolveDialog(alert: alert),
  );
}

class _ApsExecutionWatchResolveDialog extends StatefulWidget {
  const _ApsExecutionWatchResolveDialog({required this.alert});

  final ApsExecutionWatchAlertView alert;

  @override
  State<_ApsExecutionWatchResolveDialog> createState() =>
      _ApsExecutionWatchResolveDialogState();
}

class _ApsExecutionWatchResolveDialogState
    extends State<_ApsExecutionWatchResolveDialog> {
  late String _outcome;
  final _noteCtrl = TextEditingController();
  bool _followedRecommendation = false;
  late final TextEditingController _minutesCtrl;

  ApsExecutionWatchAlertView get alert => widget.alert;

  @override
  void initState() {
    super.initState();
    _outcome = ApsExecutionWatchOutcomes.suggestedOutcome(
          alertKind: alert.alertKind,
          alertType: alert.alertType,
        ) ??
        (alert.isOpportunity ? 'used_free_capacity' : 'prevented_delay');
    final suggestedMin = _suggestedMinutes();
    _minutesCtrl = TextEditingController(
      text: suggestedMin != null && suggestedMin > 0 ? '$suggestedMin' : '',
    );
  }

  int? _suggestedMinutes() {
    final vm = alert.valueMetrics;
    if (alert.isOpportunity) {
      final freed = vm['freedCapacityMinutes'] ?? vm['earlyCompletionMinutes'];
      return int.tryParse(freed?.toString() ?? '');
    }
    final late = vm['estimatedAvoidedDelayMinutes'];
    return int.tryParse(late?.toString() ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = ApsExecutionWatchOutcomes.outcomesForAlertKind(
      alert.alertKind,
    );
    final title = alert.isOpportunity
        ? 'Potvrdi iskorištenu priliku'
        : 'Potvrdi poslovni ishod';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              alert.headline,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Poslovni ishod',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...outcomes.map(
              (code) => RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  ApsExecutionWatchOutcomes.labelForBusinessOutcome(code),
                ),
                value: code,
                groupValue: _outcome,
                onChanged: (v) => setState(() => _outcome = v ?? _outcome),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: alert.isOpportunity
                    ? 'Iskorištene minute kapaciteta (opcionalno)'
                    : 'Procijenjeno izbjegnuto kašnjenje u minutama (opcionalno)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Napomena (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            if (alert.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _followedRecommendation,
                onChanged: (v) =>
                    setState(() => _followedRecommendation = v == true),
                title: const Text('Slijedio sam glavni prijedlog'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            final minutes = int.tryParse(_minutesCtrl.text.trim());
            Navigator.pop(
              context,
              ApsExecutionWatchResolveResult(
                businessOutcome: _outcome,
                resolutionNote: _noteCtrl.text.trim().isEmpty
                    ? null
                    : _noteCtrl.text.trim(),
                recommendationAccepted: _followedRecommendation,
                estimatedAvoidedDelayMinutes:
                    !alert.isOpportunity ? minutes : null,
                freedCapacityMinutes: alert.isOpportunity ? minutes : null,
              ),
            );
          },
          child: Text(alert.isOpportunity ? 'Potvrdi iskorišteno' : 'Potvrdi'),
        ),
      ],
    );
  }
}
