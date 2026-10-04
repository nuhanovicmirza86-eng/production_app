import 'package:flutter/widgets.dart';

/// Desktop/web shell geometrija Productiona.
///
/// Usklađeno s Maintenance `HomeScreen` (read-only, Material 3):
/// - wide kad je širina ≥ 900 ili native Windows
/// - navigation rail ne postavlja vlastiti `minWidth`, pa vrijedi M3 default 80
/// - vertikalni divider širine 1
/// - page padding 12 na webu i 16 na mobilnom, isti kao Maintenance početna
///
/// Classic i Premium dijele ove brojeve. Tema ne smije mijenjati širinu raila.
class OperonixShellMetrics {
  const OperonixShellMetrics._();

  static const double wideBreakpoint = 900;

  /// Flutter `_NavigationRailDefaultsM3.minWidth`. Maintenance rail ga ne override-a.
  static const double railMinWidth = 80;

  static const double railDividerWidth = 1;

  static const double pagePadding = 16;

  static const double pagePaddingWeb = 12;

  static const double minTouchTarget = 48;

  static bool isWide({required double width, required bool windowsNative}) {
    return windowsNative || width >= wideBreakpoint;
  }

  static double pagePaddingFor({required bool web}) {
    return web ? pagePaddingWeb : pagePadding;
  }
}

/// Interni max-width sadržaja (forma, dijalog, čitljiv tekst).
/// Ne koristi se oko cijelog application shella.
class OperonixContentConstraint extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const OperonixContentConstraint({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
