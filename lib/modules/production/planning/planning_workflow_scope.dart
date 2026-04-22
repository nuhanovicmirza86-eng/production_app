import 'package:flutter/material.dart';

import 'planning_session_controller.dart';

class PlanningWorkflowScope extends InheritedWidget {
  const PlanningWorkflowScope({
    super.key,
    required this.session,
    required super.child,
  });

  final PlanningSessionController session;

  static PlanningSessionController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<PlanningWorkflowScope>();
    assert(w != null, 'PlanningWorkflowScope nije u stablu');
    return w!.session;
  }

  @override
  bool updateShouldNotify(PlanningWorkflowScope oldWidget) => session != oldWidget.session;
}
