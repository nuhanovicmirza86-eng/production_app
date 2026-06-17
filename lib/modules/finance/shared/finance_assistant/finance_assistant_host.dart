import 'package:flutter/material.dart';

import 'finance_assistant_context.dart';
import 'finance_assistant_fab.dart';
import 'finance_assistant_panel.dart';

/// Omotač ekrana: plutajući Finance asistent + kontekst trenutnog ekrana.
class FinanceAssistantHost extends StatefulWidget {
  const FinanceAssistantHost({
    super.key,
    required this.contextData,
    required this.child,
    this.showFab = true,
  });

  final FinanceAssistantContext contextData;
  final Widget child;
  final bool showFab;

  static FinanceAssistantHostState? of(BuildContext context) {
    return context.findAncestorStateOfType<FinanceAssistantHostState>();
  }

  @override
  State<FinanceAssistantHost> createState() => FinanceAssistantHostState();
}

class FinanceAssistantHostState extends State<FinanceAssistantHost> {
  void openAssistant({String? questionKey}) {
    FinanceAssistantPanel.show(
      context,
      contextData: widget.contextData.copyWith(
        prefilledQuestionKey: questionKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.showFab)
          FinanceAssistantFab(
            onPressed: () => openAssistant(),
          ),
      ],
    );
  }
}
