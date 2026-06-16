import 'package:flutter/material.dart';

/// Jednom po stvarnom prikazu preporuke — ne na fetch.
class FinanceAiRecommendationVisibilityReporter extends StatefulWidget {
  const FinanceAiRecommendationVisibilityReporter({
    super.key,
    required this.enabled,
    required this.onVisible,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onVisible;
  final Widget child;

  @override
  State<FinanceAiRecommendationVisibilityReporter> createState() =>
      _FinanceAiRecommendationVisibilityReporterState();
}

class _FinanceAiRecommendationVisibilityReporterState
    extends State<FinanceAiRecommendationVisibilityReporter> {
  bool _reported = false;

  @override
  void didUpdateWidget(covariant FinanceAiRecommendationVisibilityReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _reported = false;
    }
  }

  void _maybeReport() {
    if (_reported || !widget.enabled) return;
    _reported = true;
    widget.onVisible();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Visibility(
      visible: true,
      maintainState: true,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReport());
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: widget.child,
        ),
      ),
    );
  }
}

/// Kanonski tipovi telemetry interakcija.
class FinanceAiInteractionTypes {
  FinanceAiInteractionTypes._();

  static const shown = 'shown';
  static const viewed = 'viewed';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const actionStarted = 'action_started';
  static const actionCompleted = 'action_completed';
}

/// Kanonski kodovi razloga odbijanja preporuke.
class FinanceAiRejectReasonCodes {
  FinanceAiRejectReasonCodes._();

  static const notRelevant = 'not_relevant';
  static const alreadyResolved = 'already_resolved';
  static const incorrectIncompleteData = 'incorrect_incomplete_data';
  static const otherBusinessDecision = 'other_business_decision';
  static const other = 'other';

  static const all = <String>[
    notRelevant,
    alreadyResolved,
    incorrectIncompleteData,
    otherBusinessDecision,
    other,
  ];
}
