import 'package:flutter/material.dart';

/// Kanonski vizual tablica u Production appu (npr. Proizvodni nalozi, evidencije).
///
/// Poravnanje kolona (standard):
/// - tekstualne kolone → lijevo
/// - brojčane kolone → desno
/// - status badge → lijevo
/// - akcija (Detalji / Otvori) → centar
///
/// Širina: kompaktna prema sadržaju (narrow / medium / wide), bez nepotrebnog
/// širenja; header label do 2 reda po riječima (ne po slovima); horizontalni
/// scroll kad zbroj kolona ne stane u dostupnu širinu kontejnera.
///
/// Koristi [StandardTableShell], [StandardTableFlexCell], [StandardTableMetrics],
/// [StandardTableStatusBadge] i [StandardTableOpenLink] za konzistentan izgled.
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

/// Status pill u koloni tabele — jedan red teksta, bez lomljenja u uskim ćelijama.
class StandardTableStatusBadge extends StatelessWidget {
  const StandardTableStatusBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: StandardTableMetrics.cellStyle(cs).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}

/// Link „Otvori“ u koloni Detalji — jedina klikabilna akcija u redu tabele.
class StandardTableOpenLink extends StatelessWidget {
  const StandardTableOpenLink({
    super.key,
    required this.onPressed,
    this.label = 'Otvori',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
