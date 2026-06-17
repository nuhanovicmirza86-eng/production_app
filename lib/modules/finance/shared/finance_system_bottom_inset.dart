import 'package:flutter/material.dart';

/// Donji sistemski inseti — tastatura i navigacijska/gesture traka (Android).
abstract final class FinanceSystemBottomInset {
  FinanceSystemBottomInset._();

  static double keyboard(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  static double navigationBar(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  /// Podigni cijeli sheet/panel iznad tastature (koristi na rootu modala).
  static EdgeInsets sheetLift(BuildContext context) {
    return EdgeInsets.only(bottom: keyboard(context));
  }

  /// Padding za fiksirani input ili dugmad na dnu ekrana/sheet-a.
  /// Kad je tastatura otvorena, lift je na parentu; inače dodaj nav bar.
  static EdgeInsets anchoredBar({
    required BuildContext context,
    double horizontal = 12,
    double top = 0,
    double base = 12,
    bool liftKeyboardOnParent = false,
  }) {
    final kb = keyboard(context);
    final nav = navigationBar(context);
    final bottom = base + (liftKeyboardOnParent && kb > 0 ? 0 : (kb > 0 ? kb : nav));
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  /// Plutajući gumb iznad sistemske trake.
  static double fabBottom(BuildContext context, {double base = 16}) {
    return base + navigationBar(context);
  }

  /// Donji padding za scroll sadržaj (dugmad na kraju liste).
  static double scrollEnd(BuildContext context, {double base = 24}) {
    final kb = keyboard(context);
    final nav = navigationBar(context);
    return base + (kb > 0 ? kb : nav);
  }

  /// Omotaj [Scaffold.body] — sadržaj iznad Android gesture/nav trake.
  static Widget safeBody(Widget child) {
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: child,
    );
  }
}
