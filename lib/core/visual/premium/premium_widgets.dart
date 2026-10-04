import 'package:flutter/material.dart';

import '../operonix_visual_tokens.dart';
import 'premium_icon_accent.dart';
import 'premium_type.dart';

const double _kRadius = 16;
const double _kBadge = 40;

class PremiumSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PremiumSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final radius = BorderRadius.circular(_kRadius);
    final body = Padding(padding: padding, child: child);
    return Material(
      color: tokens.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: tokens.border.withValues(alpha: 0.85)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, borderRadius: radius, child: body),
    );
  }
}

class PremiumIconBadge extends StatelessWidget {
  final IconData icon;
  final PremiumIconRole role;
  final double size;

  const PremiumIconBadge({
    super.key,
    required this.icon,
    required this.role,
    this.size = _kBadge,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PremiumIconAccent.of(role);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, size: size * 0.52, color: accent),
    );
  }
}

class PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PremiumSectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PremiumType.sectionTitle(tokens)),
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: PremiumType.meta(tokens)),
        ],
      ],
    );
  }
}

class PremiumContextCard extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final PremiumIconRole role;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PremiumContextCard({
    super.key,
    this.leading,
    this.icon,
    this.role = PremiumIconRole.info,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return PremiumSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          leading ??
              PremiumIconBadge(
                icon: icon ?? Icons.apartment_outlined,
                role: role,
                size: 36,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PremiumType.meta(tokens)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumType.cardTitle(tokens),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class PremiumListCard extends StatelessWidget {
  final IconData icon;
  final PremiumIconRole role;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PremiumListCard({
    super.key,
    required this.icon,
    required this.role,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final meta = (subtitle ?? '').trim();
    return PremiumSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          PremiumIconBadge(icon: icon, role: role),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumType.cardTitle(tokens),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumType.meta(tokens),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
          Icon(
            Icons.chevron_right,
            color: tokens.secondaryText,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class PremiumKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final PremiumIconRole role;

  const PremiumKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = PremiumIconAccent.of(role);
    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PremiumIconBadge(icon: icon, role: role, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: PremiumType.value(tokens, color: accent)),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumType.meta(tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumKpiGrid extends StatelessWidget {
  final List<PremiumKpiCard> cards;

  const PremiumKpiGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    final items = cards.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: items[0]),
            const SizedBox(width: 10),
            Expanded(child: items.length > 1 ? items[1] : const SizedBox()),
          ],
        ),
        if (items.length > 2) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: items[2]),
              const SizedBox(width: 10),
              Expanded(child: items.length > 3 ? items[3] : const SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}

class PremiumFilterCard extends StatelessWidget {
  final String title;
  final String summary;
  final bool expanded;
  final int activeCount;
  final VoidCallback onToggle;
  final Widget child;

  const PremiumFilterCard({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return PremiumSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  const PremiumIconBadge(
                    icon: Icons.filter_alt_outlined,
                    role: PremiumIconRole.info,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: PremiumType.cardTitle(tokens)),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PremiumType.meta(tokens),
                        ),
                      ],
                    ),
                  ),
                  if (activeCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '$activeCount',
                        style: PremiumType.meta(tokens).copyWith(
                          color: tokens.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: tokens.secondaryText,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}

class PremiumPrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const PremiumPrimaryAction({
    super.key,
    required this.label,
    this.icon = Icons.add,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primaryAccent,
        foregroundColor: tokens.onAccent,
        elevation: 0,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final PremiumIconRole role;
  final String title;
  final String? support;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.role,
    required this.title,
    this.support,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return PremiumSurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumIconBadge(icon: icon, role: role, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PremiumType.cardTitle(tokens),
          ),
          if ((support ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              support!,
              textAlign: TextAlign.center,
              style: PremiumType.support(tokens),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            PremiumPrimaryAction(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Odabrano stanje donje navigacije: tamna elevated traka i svijetli pill.
class PremiumNavigationSelection {
  const PremiumNavigationSelection._();

  static NavigationBarThemeData barTheme(OperonixVisualTokens tokens) {
    return NavigationBarThemeData(
      backgroundColor: tokens.surfaceElevated,
      elevation: 0,
      height: 72,
      indicatorColor: tokens.surfaceInteractive,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? tokens.primaryText : tokens.disabledText,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? tokens.primaryText : tokens.disabledText,
        );
      }),
    );
  }
}
