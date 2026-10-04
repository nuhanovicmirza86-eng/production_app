import 'package:flutter/material.dart';

import 'operonix_shell_metrics.dart';

/// Full-width desktop shell: rail uz lijevu ivicu, sadržaj u preostaloj širini.
///
/// Geometrija je ista za Classic i Premium. Boje dolaze iz [NavigationRailTheme].
class OperonixDesktopShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;
  final Widget? leading;
  final Widget child;

  const OperonixDesktopShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            minWidth: OperonixShellMetrics.railMinWidth,
            leading: leading,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
            scrollable: true,
          ),
          const VerticalDivider(
            width: OperonixShellMetrics.railDividerWidth,
            thickness: 1,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
