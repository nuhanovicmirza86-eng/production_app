import 'package:flutter/material.dart';
import 'package:production_app/core/ui/standard_list_components.dart';

import 'mes_inbox_presentation.dart';

/// NOTIF-M1-B4-UI-HOTFIX-01 — isti collapsible obrazac kao liste
/// (`StandardFilterPanel` na Proizvodima / Nalozima / Narudžbama).
class MesInboxFilterBar extends StatelessWidget {
  const MesInboxFilterBar({
    super.key,
    required this.filter,
    required this.period,
    required this.expanded,
    required this.onToggle,
    required this.onFilterSelected,
    required this.onPeriodSelected,
  });

  final MesInboxListFilter filter;
  final MesInboxPeriodFilter period;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<MesInboxListFilter> onFilterSelected;
  final ValueChanged<MesInboxPeriodFilter> onPeriodSelected;

  int get activeCount {
    var n = 0;
    if (filter != MesInboxListFilter.unread) n++;
    if (period != MesInboxPeriodFilter.all) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget group(String title, List<Widget> chips) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(children: chips),
        ],
      );
    }

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: ChoiceChip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          selected: selected,
          showCheckmark: true,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: StandardFilterPanel(
        title: MesInboxPresentation.filterBarButtonLabel(),
        expanded: expanded,
        activeCount: activeCount,
        onToggle: onToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            group(
              MesInboxPresentation.filterBarStatusGroupLabel(),
              [
                for (final item in MesInboxListFilter.values)
                  chip(
                    label: MesInboxPresentation.filterLabel(item),
                    selected: filter == item,
                    onTap: () => onFilterSelected(item),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            group(
              MesInboxPresentation.filterBarPeriodGroupLabel(),
              [
                for (final item in MesInboxPeriodFilter.values)
                  chip(
                    label: MesInboxPresentation.periodLabel(item),
                    selected: period == item,
                    onTap: () => onPeriodSelected(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
