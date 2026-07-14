import 'package:flutter/material.dart';

/// Kanonski vizual tablica u Production appu (npr. Proizvodni nalozi → Zalihe i status).
class StandardTableMetrics {
  StandardTableMetrics._();

  static const double borderRadius = 12;
  static const double padH = 8;
  static const double padV = 8;
  static const double headerPadV = 10;

  static Color borderColor(ColorScheme cs) => cs.outlineVariant;

  static Color headerBackground(ColorScheme cs) => cs.surfaceContainerHighest;

  static Color rowBackground(ColorScheme cs) => cs.surface;

  static TextStyle headerStyle(ColorScheme cs) => TextStyle(
    color: cs.onSurface,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle cellStyle(ColorScheme cs) => TextStyle(
    fontSize: 10.5,
    height: 1.25,
    color: cs.onSurface,
  );
}

/// Zaobljena ivica + tanki obrub oko tabele (clip + outlineVariant).
class StandardTableShell extends StatelessWidget {
  const StandardTableShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StandardTableMetrics.borderRadius),
        side: BorderSide(color: StandardTableMetrics.borderColor(cs)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Ćelija unutar flex reda tabele — puna mreža linija kao [TableBorder.all].
class StandardTableFlexCell extends StatelessWidget {
  const StandardTableFlexCell({
    super.key,
    required this.flex,
    required this.borderColor,
    required this.child,
    required this.align,
    this.isLastColumn = false,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: StandardTableMetrics.padH,
      vertical: StandardTableMetrics.padV,
    ),
  });

  final int flex;
  final Color borderColor;
  final Widget child;
  final TextAlign align;
  final bool isLastColumn;
  final Color? backgroundColor;
  final EdgeInsets padding;

  Alignment get _alignment {
    switch (align) {
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            right: isLastColumn
                ? BorderSide.none
                : BorderSide(color: borderColor, width: 1),
            bottom: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Padding(
          padding: padding,
          child: Align(
            alignment: _alignment,
            child: child,
          ),
        ),
      ),
    );
  }
}
