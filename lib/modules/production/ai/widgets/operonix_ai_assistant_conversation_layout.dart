import 'package:flutter/material.dart';

import '../../../../core/ui/standard_list_components.dart';

/// Chat body: optional collapsible scope scrolls with messages; composer stays below.
class OperonixAiAssistantConversationLayout extends StatelessWidget {
  const OperonixAiAssistantConversationLayout({
    super.key,
    required this.conversation,
    required this.composer,
    this.scrollController,
    this.showScope = false,
    this.scopeExpanded = false,
    this.scopeSummary,
    this.onToggleScope,
    this.scopeControls,
    this.scopeTitle = 'Doseg asistenta',
  });

  final ScrollController? scrollController;
  final bool showScope;
  final bool scopeExpanded;
  final String? scopeSummary;
  final VoidCallback? onToggleScope;
  final Widget? scopeControls;
  final String scopeTitle;
  final List<Widget> conversation;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              if (showScope) ...[
                StandardFilterPanel(
                  expanded: scopeExpanded,
                  activeCount: 0,
                  title: scopeTitle,
                  summary: scopeSummary,
                  onToggle: onToggleScope ?? () {},
                  child: scopeControls ?? const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
              ],
              ...conversation,
            ],
          ),
        ),
        composer,
      ],
    );
  }
}
