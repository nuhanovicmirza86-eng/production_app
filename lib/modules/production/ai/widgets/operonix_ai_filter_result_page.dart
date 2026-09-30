import 'package:flutter/material.dart';

import '../../../../core/ui/standard_list_components.dart';

/// Shared AppBar-below layout for structured AI analysis / report screens.
class OperonixAiFilterResultPage extends StatelessWidget {
  const OperonixAiFilterResultPage({
    super.key,
    required this.filtersExpanded,
    required this.onToggleFilters,
    required this.filterControls,
    required this.action,
    required this.bodyBelowAction,
    this.filterSummary,
    this.filterTitle = 'Filteri',
  });

  final bool filtersExpanded;
  final VoidCallback onToggleFilters;
  final Widget filterControls;
  final Widget action;
  final Widget bodyBelowAction;
  final String? filterSummary;
  final String filterTitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StandardFilterPanel(
              expanded: filtersExpanded,
              activeCount: 0,
              title: filterTitle,
              summary: filterSummary,
              onToggle: onToggleFilters,
              child: filterControls,
            ),
            const SizedBox(height: 16),
            action,
            bodyBelowAction,
          ],
        ),
      ),
    );
  }
}
