import 'package:flutter/material.dart';

import '../operonix_visual_tokens.dart';
import 'operonix_premium_icon.dart';
import 'operonix_premium_iconography.dart';
import 'premium_icon_accent.dart';
import 'premium_type.dart';

/// Veličina meke mrlje. Piktogram puni većinu površine, bez obruba.
enum PremiumBadgeVariant { small, medium, large }

const double _kBadge = 40;

class PremiumSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// 1 = sekcija, 2 = radna površina, 3 = odabrano / prioritet.
  final int level;
  final bool outlined;

  const PremiumSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.level = 2,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final radius = BorderRadius.circular(switch (level) {
      1 => 20,
      3 => 12,
      _ => 14,
    });
    final color = switch (level) {
      1 => tokens.surface,
      3 => tokens.surfaceInteractive,
      _ => tokens.surfaceElevated,
    };
    final body = Padding(padding: padding, child: child);
    return Material(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: outlined
            ? BorderSide(color: tokens.border.withValues(alpha: 0.7))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, borderRadius: radius, child: body),
    );
  }
}

class PremiumIconBadge extends StatelessWidget {
  final IconData? icon;
  final OperonixPremiumGlyph? glyph;
  final PremiumIconRole role;
  final PremiumBadgeVariant variant;
  final double? size;
  final bool selected;
  final bool disabled;

  const PremiumIconBadge({
    super.key,
    this.icon,
    this.glyph,
    required this.role,
    this.variant = PremiumBadgeVariant.medium,
    this.size,
    this.selected = false,
    this.disabled = false,
  });

  double get extent {
    if (size != null) return size!;
    return switch (variant) {
      PremiumBadgeVariant.small => 28,
      PremiumBadgeVariant.medium => _kBadge,
      PremiumBadgeVariant.large => 60,
    };
  }

  double get radius {
    final resolved = size == null
        ? variant
        : size! <= 32
        ? PremiumBadgeVariant.small
        : size! >= 48
        ? PremiumBadgeVariant.large
        : PremiumBadgeVariant.medium;
    return switch (resolved) {
      PremiumBadgeVariant.small => 8,
      PremiumBadgeVariant.medium => 12,
      PremiumBadgeVariant.large => 18,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = disabled
        ? tokens.disabledText
        : PremiumIconAccent.of(role, tokens);
    final box = extent;
    final spot = disabled
        ? tokens.disabledText.withValues(alpha: 0.14)
        : accent.withValues(alpha: selected ? 0.30 : 0.20);
    final spotDeep = disabled
        ? tokens.disabledText.withValues(alpha: 0.06)
        : accent.withValues(alpha: selected ? 0.12 : 0.07);
    final mark = glyph;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spot, spotDeep],
        ),
      ),
      child: mark != null
          ? OperonixPremiumIcon(
              glyph: mark,
              color: accent,
              size: box * 0.82,
            )
          : Icon(icon ?? Icons.circle_outlined, size: box * 0.62, color: accent),
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
      level: 1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  final OperonixPremiumGlyph? glyph;
  final PremiumIconRole role;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final PremiumBadgeVariant badgeVariant;

  /// Red unutar zajedničke površine, bez vlastite kartice.
  final bool flush;

  const PremiumListCard({
    super.key,
    required this.icon,
    this.glyph,
    required this.role,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.flush = false,
    this.badgeVariant = PremiumBadgeVariant.medium,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final resolved =
        glyph ?? OperonixPremiumIconography.resolve(title: title, icon: icon);
    final accent = PremiumIconAccent.of(role, tokens);
    final meta = (subtitle ?? '').trim();
    final row = Row(
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        PremiumIconBadge(
          icon: icon,
          glyph: resolved,
          role: role,
          variant: badgeVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                PremiumIconAccent.familyLabel(role),
                style: PremiumType.meta(tokens).copyWith(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    );
    if (flush) {
      final padded = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: row,
      );
      if (onTap == null) return padded;
      return InkWell(onTap: onTap, child: padded);
    }
    return PremiumSurfaceCard(
      onTap: onTap,
      level: 2,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: row,
    );
  }
}

class PremiumKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final PremiumIconRole role;
  final OperonixPremiumGlyph? glyph;

  const PremiumKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.role,
    this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final accent = PremiumIconAccent.of(role, tokens);
    final resolved =
        glyph ??
        OperonixPremiumIconography.forKpi(label) ??
        OperonixPremiumIconography.resolve(title: label, icon: icon);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PremiumIconBadge(icon: icon, glyph: resolved, role: role, size: 36),
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
    final tokens = OperonixVisualTokens.of(context);
    final items = cards.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final rows = wide
            ? [items]
            : [
                items.take(2).toList(),
                if (items.length > 2) items.skip(2).take(2).toList(),
              ];
        return PremiumSurfaceCard(
          level: 1,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0)
                  Container(height: 1, color: tokens.divider),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < rows[r].length; c++) ...[
                        if (c > 0)
                          Container(width: 1, color: tokens.divider),
                        Expanded(child: rows[r][c]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class PremiumResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;

  const PremiumResponsiveGrid({
    super.key,
    required this.children,
    this.breakpoint = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                children[i],
              ],
            ],
          );
        }
        final cols = constraints.maxWidth >= 1100 ? 3 : 2;
        final width =
            (constraints.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
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
      level: 2,
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
  final OperonixPremiumGlyph? glyph;
  final PremiumIconRole role;
  final String title;
  final String? support;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    this.glyph,
    required this.role,
    required this.title,
    this.support,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    final resolved =
        glyph ??
        OperonixPremiumIconography.resolve(title: title, icon: icon) ??
        OperonixPremiumGlyph.evidence;
    return PremiumSurfaceCard(
      level: 1,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumIconBadge(
            icon: icon,
            glyph: resolved,
            role: role,
            size: 52,
          ),
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
      indicatorColor: tokens.primaryAccent.withValues(alpha: 0.22),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? tokens.primaryAccent : tokens.disabledText,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? tokens.primaryAccent : tokens.disabledText,
        );
      }),
    );
  }
}
