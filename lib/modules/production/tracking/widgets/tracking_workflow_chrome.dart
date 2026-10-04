import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_type.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import '../config/preparation_station_ui_prefs.dart';

/// Brzi / ručni unos. Isti callback u oba izgleda.
class TrackingEntryModeControl extends StatelessWidget {
  final bool quickMode;
  final ValueChanged<bool> onChanged;

  const TrackingEntryModeControl({
    super.key,
    required this.quickMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final premium = OperonixVisualTokens.of(context).isPremium;
    return SegmentedButton<bool>(
      style: premium
          ? const ButtonStyle(
              visualDensity: VisualDensity.standard,
              minimumSize: WidgetStatePropertyAll(Size(48, 44)),
              tapTargetSize: MaterialTapTargetSize.padded,
            )
          : null,
      segments: const [
        ButtonSegment<bool>(
          value: true,
          label: Text('Brzi unos'),
          icon: Icon(Icons.bolt_outlined),
        ),
        ButtonSegment<bool>(
          value: false,
          label: Text('Ručni unos'),
          icon: Icon(Icons.edit_note_outlined),
        ),
      ],
      selected: {quickMode},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}

/// Skeniraj QR i druga operativna radnja. Callbacki su isti; Premium razlikuje težinu.
class TrackingScanActions extends StatelessWidget {
  final VoidCallback? onScan;
  final VoidCallback? onSecondary;
  final bool showSecondary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final Color accent;

  const TrackingScanActions({
    super.key,
    required this.onScan,
    required this.onSecondary,
    required this.showSecondary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final premium = OperonixVisualTokens.of(context).isPremium;
    final scan = premium
        ? FilledButton.icon(
            onPressed: onScan,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Skeniraj QR'),
          )
        : FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Skeniraj QR'),
          );
    final secondary = premium
        ? OutlinedButton.icon(
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          )
        : FilledButton.tonalIcon(
            onPressed: onSecondary,
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          );
    return Row(
      children: [
        Expanded(child: scan),
        if (showSecondary) ...[
          const SizedBox(width: 10),
          Expanded(child: secondary),
        ],
      ],
    );
  }
}

InputDecoration trackingScannerDecoration({required bool premium}) {
  return InputDecoration(
    labelText: 'Vanjski QR skener',
    hintText: 'Fokus ovdje, zatim skeniraj',
    isDense: premium,
    prefixIcon: premium
        ? const Icon(Icons.qr_code_scanner_outlined)
        : null,
  );
}

/// Izbor boje gumba. U tijelu toka samo kad [inline] (Classic).
class TrackingButtonAccentChoices extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inline;

  const TrackingButtonAccentChoices({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.inline = true,
  });

  @override
  Widget build(BuildContext context) {
    if (inline && OperonixVisualTokens.of(context).isPremium) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Tema gumba',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (var i = 0; i < PreparationStationUiPrefs.accentColors.length; i++)
          ChoiceChip(
            label: Text(PreparationStationUiPrefs.accentLabels[i]),
            selected: selectedIndex == i,
            onSelected: (selected) {
              if (!selected) return;
              onSelected(i);
            },
          ),
      ],
    );
  }
}

class TrackingWorkContextCard extends StatelessWidget {
  final String entryDate;
  final List<Widget> actions;

  const TrackingWorkContextCard({
    super.key,
    required this.entryDate,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return PremiumSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const PremiumIconBadge(
            icon: Icons.calendar_today_outlined,
            role: PremiumIconRole.info,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Datum unosa', style: PremiumType.meta(tokens)),
                Text(entryDate, style: PremiumType.cardTitle(tokens)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
