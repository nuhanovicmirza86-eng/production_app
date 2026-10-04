import 'package:flutter/material.dart';

import '../../../modules/production/tracking/config/station_screen_theme.dart';
import '../operonix_visual_theme.dart';
import '../operonix_visual_tokens.dart';

/// Postojeći izbor stanice, preveden u tamnu Premium paletu.
///
/// Nikad ne vraća svijetlu Classic podlogu. Operonix predložak ostaje Midnight.
class PremiumStationPalette {
  const PremiumStationPalette._();

  static const Color _floor = Color(0xFF070B14);

  static OperonixVisualTokens tokensFor(StationScreenAppearance appearance) {
    final custom = appearance.custom;
    if (custom != null) return _fromCustom(custom);
    switch (appearance.preset) {
      case StationScreenThemeId.operonix:
        return OperonixVisualTokens.midnight();
      case StationScreenThemeId.industrialDark:
        return _shift(
          background: const Color(0xFF07111F),
          surface: const Color(0xFF0E1A2E),
          elevated: const Color(0xFF15243C),
          interactive: const Color(0xFF1C3254),
          border: const Color(0xFF2A4568),
          accent: const Color(0xFF4C8DFF),
          onAccent: const Color(0xFF041018),
        );
      case StationScreenThemeId.cleanLight:
        return _shift(
          background: const Color(0xFF140C1C),
          surface: const Color(0xFF1C1228),
          elevated: const Color(0xFF261838),
          interactive: const Color(0xFF342048),
          border: const Color(0xFF4A3068),
          accent: const Color(0xFFC4A0FF),
          onAccent: const Color(0xFF1A0E24),
        );
    }
  }

  static OperonixVisualTokens _shift({
    required Color background,
    required Color surface,
    required Color elevated,
    required Color interactive,
    required Color border,
    required Color accent,
    required Color onAccent,
  }) {
    return OperonixVisualTokens.midnight().copyWith(
      background: background,
      surface: surface,
      surfaceElevated: elevated,
      surfaceInteractive: interactive,
      border: border,
      pageBackground: background,
      kpiSurface: elevated,
      primaryAccent: accent,
      moduleAccent: accent,
      info: accent,
      fieldFocus: accent,
      onAccent: onAccent,
    );
  }

  static OperonixVisualTokens _fromCustom(StationScreenCustomColors custom) {
    final accent = custom.primaryAccent;
    final canvas = _keepDark(custom.background, accent);
    final surface = Color.lerp(canvas, accent, 0.08)!;
    final elevated = Color.lerp(canvas, accent, 0.14)!;
    final interactive = Color.lerp(canvas, accent, 0.22)!;
    return _shift(
      background: canvas,
      surface: surface,
      elevated: elevated,
      interactive: interactive,
      border: Color.lerp(canvas, accent, 0.35)!,
      accent: accent,
      onAccent: accent.computeLuminance() > 0.45
          ? const Color(0xFF0A1020)
          : const Color(0xFFF4F7FB),
    );
  }

  /// Svijetla stanica ostaje čitljiva, ali platno ne prelazi u bijelo.
  static Color _keepDark(Color requested, Color accent) {
    if (requested.computeLuminance() <= 0.18) return requested;
    return Color.lerp(_floor, accent, 0.16)!;
  }
}

/// Classic dobija punu temu stanice. Premium dobija tamnu paletu.
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
