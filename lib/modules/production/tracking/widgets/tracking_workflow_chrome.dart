import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_collapsible_section.dart';
import '../../../../core/visual/operonix_shell_metrics.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/operonix_premium_icon.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_station_palette.dart';
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
    final tokens = OperonixVisualTokens.of(context);
    final premium = tokens.isPremium;
    return SegmentedButton<bool>(
      style: premium
          ? ButtonStyle(
              visualDensity: VisualDensity.standard,
              minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
              tapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return tokens.primaryAccent.withValues(alpha: 0.22);
                }
                return tokens.surface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return tokens.primaryText;
                }
                return tokens.secondaryText;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: tokens.primaryAccent);
                }
                return BorderSide.none;
              }),
            )
          : null,
      segments: [
        ButtonSegment<bool>(
          value: true,
          label: const Text('Brzi unos'),
          icon: premium
              ? const OperonixPremiumIcon(
                  glyph: OperonixPremiumGlyph.quickEntry,
                  size: 18,
                )
              : const Icon(Icons.bolt_outlined),
        ),
        ButtonSegment<bool>(
          value: false,
          label: const Text('Ručni unos'),
          icon: premium
              ? const OperonixPremiumIcon(
                  glyph: OperonixPremiumGlyph.manualEntry,
                  size: 18,
                )
              : const Icon(Icons.edit_note_outlined),
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
    final tokens = OperonixVisualTokens.of(context);
    final premium = tokens.isPremium;
    final onAction = premiumActionForeground(accent);
    final scan = premium
        ? FilledButton.icon(
            onPressed: onScan,
            style:
                FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: onAction,
                  iconColor: onAction,
                  minimumSize: const Size(48, 48),
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return onAction.withValues(alpha: 0.16);
                    }
                    if (states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.hovered)) {
                      return onAction.withValues(alpha: 0.10);
                    }
                    return null;
                  }),
                ),
            icon: const OperonixPremiumIcon(
              glyph: OperonixPremiumGlyph.qrScan,
              size: 20,
            ),
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
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: OperonixPremiumIcon(
              glyph: secondaryIcon == Icons.inventory_2_outlined
                  ? OperonixPremiumGlyph.closeBox
                  : OperonixPremiumGlyph.labelPrint,
              size: 20,
            ),
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
        ? const OperonixPremiumIcon(
            glyph: OperonixPremiumGlyph.qrScan,
            size: 22,
          )
        : null,
  );
}

/// Izbor boje gumba. U tijelu toka samo kad [inline] (Classic).
class TrackingButtonAccentChoices extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inline;
  final bool showHeading;
  final bool showSwatch;

  const TrackingButtonAccentChoices({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.inline = true,
    this.showHeading = true,
    this.showSwatch = false,
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
        if (showHeading)
          Text(
            'Tema gumba',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (var i = 0; i < PreparationStationUiPrefs.accentColors.length; i++)
          ChoiceChip(
            avatar: showSwatch
                ? CircleAvatar(
                    backgroundColor: PreparationStationUiPrefs.accentColors[i],
                    radius: 8,
                  )
                : null,
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

/// Jedna radna traka: dan, datum unosa i pogon. Nisu tri odvojene kartice.
///
/// Na telefonu je skupljena. Sažetak i dalje pokazuje datum i pogon.
class TrackingContextBand extends StatefulWidget {
  final String workDay;
  final String entryDate;
  final String plant;
  final VoidCallback? onPlant;
  final List<Widget> actions;

  const TrackingContextBand({
    super.key,
    required this.workDay,
    required this.entryDate,
    required this.plant,
    this.onPlant,
    this.actions = const [],
  });

  @override
  State<TrackingContextBand> createState() => _TrackingContextBandState();
}

class _TrackingContextBandState extends State<TrackingContextBand> {
  bool? _expanded;

  bool _isExpanded(BuildContext context) {
    if (_expanded != null) return _expanded!;
    return MediaQuery.sizeOf(context).width >=
        OperonixShellMetrics.wideBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _isExpanded(context);
    return OperonixCollapsibleSection(
      title: 'Kontekst unosa',
      summary: '${widget.entryDate} · ${widget.plant}',
      expanded: expanded,
      glyph: OperonixPremiumGlyph.entryDate,
      role: PremiumIconRole.material,
      onToggle: () => setState(() => _expanded = !expanded),
      child: _details(context),
    );
  }

  Widget _details(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return PremiumSurfaceCard(
      level: 1,
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cells = [
                _ContextCell(
                  icon: Icons.calendar_today_outlined,
                  glyph: OperonixPremiumGlyph.workDay,
                  role: PremiumIconRole.info,
                  label: 'Radni dan',
                  value: widget.workDay,
                ),
                _ContextCell(
                  icon: Icons.edit_calendar_outlined,
                  glyph: OperonixPremiumGlyph.entryDate,
                  role: PremiumIconRole.material,
                  label: 'Datum unosa',
                  value: widget.entryDate,
                ),
                _ContextCell(
                  icon: Icons.factory_outlined,
                  glyph: OperonixPremiumGlyph.plant,
                  role: PremiumIconRole.people,
                  label: 'Pogon',
                  value: widget.plant,
                  onTap: widget.onPlant,
                ),
              ];
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) Divider(height: 12, color: tokens.divider),
                      cells[i],
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) Container(width: 1, color: tokens.divider),
                      Expanded(child: cells[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          if (widget.actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.actions,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextCell extends StatelessWidget {
  final IconData icon;
  final OperonixPremiumGlyph glyph;
  final PremiumIconRole role;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContextCell({
    required this.icon,
    required this.glyph,
    required this.role,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          PremiumIconBadge(
            icon: icon,
            glyph: glyph,
            role: role,
            variant: PremiumBadgeVariant.small,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: PremiumType.meta(tokens)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumType.cardTitle(tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
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
            glyph: OperonixPremiumGlyph.entryDate,
            role: PremiumIconRole.material,
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
