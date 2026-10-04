import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../modules/production/tracking/config/station_screen_theme.dart';
import '../operonix_visual_theme.dart';
import '../operonix_visual_tokens.dart';

/// Precedence na Praćenju proizvodnje:
///
/// 1. Premium baza bira komponentni sistem (VisualStyle).
/// 2. Tema radnog prostora (`StationScreenThemeStore`) bira platno,
///    površine, navigaciju i tematski akcent.
/// 3. Boja operativnih akcija (`PreparationStationUiPrefs`) prekriva
///    samo primarne radnje. Ne boji platno, navigaciju ni kartice.
///
/// Operonix (brend) ostaje Midnight. Industrijska noć je tamniji grafit.
/// Svijetla proizvodnja je pravi svijetli Premium prostor, samo na ovom ekranu.
class PremiumStationPalette {
  const PremiumStationPalette._();

  static OperonixVisualTokens tokensFor(StationScreenAppearance appearance) {
    final custom = appearance.custom;
    if (custom != null) return _fromCustom(custom);
    switch (appearance.preset) {
      case StationScreenThemeId.operonix:
        return OperonixVisualTokens.midnight();
      case StationScreenThemeId.industrialDark:
        return _dark(
          background: const Color(0xFF05080C),
          surface: const Color(0xFF0C1218),
          elevated: const Color(0xFF141C24),
          interactive: const Color(0xFF1A2833),
          border: const Color(0xFF2C4250),
          divider: const Color(0xFF1B2832),
          accent: const Color(0xFF3EC6D6),
          info: const Color(0xFF7FDBEA),
        );
      case StationScreenThemeId.cleanLight:
        return _light(
          background: const Color(0xFFF2F4F7),
          surface: const Color(0xFFFFFFFF),
          elevated: const Color(0xFFF7F8FA),
          interactive: const Color(0xFFE7EDF2),
          border: const Color(0xFFD0D7E0),
          divider: const Color(0xFFE1E6EC),
          accent: const Color(0xFF0E6B66),
          info: const Color(0xFF1D4E89),
        );
    }
  }

  static OperonixVisualTokens _dark({
    required Color background,
    required Color surface,
    required Color elevated,
    required Color interactive,
    required Color border,
    required Color divider,
    required Color accent,
    required Color info,
  }) {
    return OperonixVisualTokens.midnight().copyWith(
      background: background,
      surface: surface,
      surfaceElevated: elevated,
      surfaceInteractive: interactive,
      border: border,
      divider: divider,
      pageBackground: background,
      kpiSurface: elevated,
      cardBorder: border,
      kpiBorder: border,
      fieldOutline: border,
      primaryAccent: accent,
      moduleAccent: accent,
      info: info,
      fieldFocus: accent,
      onAccent: premiumActionForeground(accent),
    );
  }

  static OperonixVisualTokens _light({
    required Color background,
    required Color surface,
    required Color elevated,
    required Color interactive,
    required Color border,
    required Color divider,
    required Color accent,
    required Color info,
  }) {
    const primaryText = Color(0xFF1B2430);
    const secondaryText = Color(0xFF5A6775);
    return OperonixVisualTokens.midnight().copyWith(
      background: background,
      surface: surface,
      surfaceElevated: elevated,
      surfaceInteractive: interactive,
      border: border,
      divider: divider,
      primaryText: primaryText,
      secondaryText: secondaryText,
      disabledText: const Color(0xFF8A95A1),
      metaText: secondaryText,
      pageBackground: background,
      kpiSurface: surface,
      cardBorder: border,
      kpiBorder: border,
      fieldOutline: border,
      primaryAccent: accent,
      moduleAccent: accent,
      info: info,
      fieldFocus: accent,
      onAccent: premiumActionForeground(accent),
      success: const Color(0xFF1B7F4A),
      warning: const Color(0xFF9A6700),
      danger: const Color(0xFFC62828),
    );
  }

  static OperonixVisualTokens _fromCustom(StationScreenCustomColors custom) {
    final canvas = custom.background;
    final accent = custom.primaryAccent;
    final border = custom.fieldOutline;
    if (canvas.computeLuminance() > 0.45) {
      final surface = Color.lerp(canvas, Colors.white, 0.55)!;
      return _light(
        background: canvas,
        surface: surface,
        elevated: Color.lerp(canvas, Colors.white, 0.35)!,
        interactive: Color.lerp(canvas, accent, 0.08)!,
        border: border,
        divider: Color.lerp(canvas, border, 0.35)!,
        accent: accent,
        info: accent,
      );
    }
    return _dark(
      background: canvas,
      surface: Color.lerp(canvas, accent, 0.08)!,
      elevated: Color.lerp(canvas, accent, 0.14)!,
      interactive: Color.lerp(canvas, accent, 0.22)!,
      border: border,
      divider: Color.lerp(canvas, Colors.white, 0.08)!,
      accent: accent,
      info: accent,
    );
  }
}

/// Prednji plan koji ostaje čitljiv na odabranoj boji akcije.
Color premiumActionForeground(Color action) {
  const light = Color(0xFFF7FBFA);
  const dark = Color(0xFF0A1020);
  return _contrast(action, light) >= _contrast(action, dark) ? light : dark;
}

double premiumContrast(Color a, Color b) => _contrast(a, b);

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

/// Samo tema gumba. Platno i navigacija ostaju od teme radnog prostora.
ThemeData premiumTrackingActionTheme(ThemeData base, Color action) {
  final on = premiumActionForeground(action);
  final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) {
      return on.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.focused) ||
        states.contains(WidgetState.hovered)) {
      return on.withValues(alpha: 0.10);
    }
    return null;
  });
  ButtonStyle style({required bool filled}) {
    return ButtonStyle(
      backgroundColor: filled ? WidgetStatePropertyAll(action) : null,
      foregroundColor: WidgetStatePropertyAll(on),
      iconColor: WidgetStatePropertyAll(on),
      overlayColor: overlay,
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    );
  }

  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(style: style(filled: true)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: style(filled: true)),
  );
}

/// Classic dobija punu temu stanice. Premium dobija paletu radnog prostora.
ThemeData trackingPageTheme({
  required ThemeData parent,
  required StationScreenAppearance appearance,
  required bool premium,
}) {
  if (!premium) return buildStationScreenTheme(parent, appearance);
  return OperonixVisualTheme.premiumWith(
    PremiumStationPalette.tokensFor(appearance),
  );
}
