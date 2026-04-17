import 'package:flutter/material.dart';

import '../../../../core/theme/operonix_production_brand.dart';

/// Tri izgleda za [ProductionOperatorTrackingStationScreen] (i potomke u istom [Theme] stablu).
enum StationScreenThemeId {
  /// Operonix brend: navy + SCADA plavi akcent + production zelena (kao SCADA „Operonix grafit“, svijetla podloga).
  operonix,

  /// Tamna industrijska — ista paleta kao SCADA „Operonix grafit“ (čitljiv tekst, plavi akcenti).
  industrialDark,

  /// Neutralna svijetla — maksimalna čitljivost za dugu smjenu.
  cleanLight,
}

extension StationScreenThemeIdX on StationScreenThemeId {
  String get label {
    switch (this) {
      case StationScreenThemeId.operonix:
        return 'Operonix (brend)';
      case StationScreenThemeId.industrialDark:
        return 'Industrijska noć';
      case StationScreenThemeId.cleanLight:
        return 'Svijetla proizvodnja';
    }
  }

  String get description {
    switch (this) {
      case StationScreenThemeId.operonix:
        return 'Navy + SCADA plavo + zeleni akcent (usklađeno s SCADA zidom)';
      case StationScreenThemeId.industrialDark:
        return 'Tamna pozadina, plavi akcent, visok kontrast teksta';
      case StationScreenThemeId.cleanLight:
        return 'Neutralna svijetla — čitljivost i smanjenje zamora';
    }
  }

  IconData get menuIcon {
    switch (this) {
      case StationScreenThemeId.operonix:
        return Icons.hexagon_outlined;
      case StationScreenThemeId.industrialDark:
        return Icons.dark_mode_outlined;
      case StationScreenThemeId.cleanLight:
        return Icons.wb_sunny_outlined;
    }
  }
}

/// Ručno podešene boje stanice: podloga, akcent (gumbi), obrub polja.
@immutable
class StationScreenCustomColors {
  final Color background;
  final Color primaryAccent;
  final Color fieldOutline;

  const StationScreenCustomColors({
    required this.background,
    required this.primaryAccent,
    required this.fieldOutline,
  });

  Map<String, int> toJson() => {
    'bg': background.toARGB32(),
    'primary': primaryAccent.toARGB32(),
    'outline': fieldOutline.toARGB32(),
  };

  factory StationScreenCustomColors.fromJson(Map<String, dynamic> m) {
    int c(String k, int fallback) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return StationScreenCustomColors(
      background: Color(c('bg', 0xFFF5F5F5)),
      primaryAccent: Color(c('primary', 0xFF2E7D32)),
      fieldOutline: Color(c('outline', 0xFFB0BEC5)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationScreenCustomColors &&
          background == other.background &&
          primaryAccent == other.primaryAccent &&
          fieldOutline == other.fieldOutline;

  @override
  int get hashCode => Object.hash(background, primaryAccent, fieldOutline);
}

/// Aktivni izgled: ugrađena tema ili prilagođene boje.
@immutable
class StationScreenAppearance {
  final StationScreenThemeId preset;
  final StationScreenCustomColors? custom;

  const StationScreenAppearance({
    this.preset = StationScreenThemeId.operonix,
    this.custom,
  });

  bool get usesCustom => custom != null;

  StationScreenAppearance copyWith({
    StationScreenThemeId? preset,
    StationScreenCustomColors? custom,
    bool clearCustom = false,
  }) {
    return StationScreenAppearance(
      preset: preset ?? this.preset,
      custom: clearCustom ? null : (custom ?? this.custom),
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.index,
    if (custom != null) 'custom': custom!.toJson(),
  };

  factory StationScreenAppearance.fromJson(Map<String, dynamic> m) {
    final pi = m['preset'];
    final idx = pi is int ? pi : int.tryParse('$pi') ?? 0;
    final preset = StationScreenThemeId.values[
      idx.clamp(0, StationScreenThemeId.values.length - 1)
    ];
    StationScreenCustomColors? custom;
    final raw = m['custom'];
    if (raw is Map<String, dynamic>) {
      custom = StationScreenCustomColors.fromJson(raw);
    }
    return StationScreenAppearance(preset: preset, custom: custom);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationScreenAppearance &&
          preset == other.preset &&
          custom == other.custom;

  @override
  int get hashCode => Object.hash(preset, custom);
}

Brightness _brightnessForSurface(Color background) {
  return ThemeData.estimateBrightnessForColor(background);
}

/// SCADA `ScadaWallTheme.operonix_graphite` — tamna podloga i paneli.
const Color _kScadaWall = Color(0xFF070A0F);
const Color _kScadaPanel = Color(0xFF343E52);
const Color _kScadaHeaderBar = Color(0xFF262F3D);
const Color _kScadaBorder = Color(0xFF5C6B82);
const Color _kScadaTextPrimary = Color(0xFFE6EDF3);
const Color _kScadaTextMuted = Color(0xFF8B949E);

ColorScheme _colorSchemeOperonixBrandLight() {
  final base = ColorScheme.fromSeed(
    seedColor: kOperonixProductionBrandGreen,
    brightness: Brightness.light,
  );
  return base.copyWith(
    primary: kOperonixProductionBrandGreen,
    onPrimary: const Color(0xFF042218),
    secondary: kOperonixScadaAccentBlue,
    onSecondary: Colors.white,
    surface: const Color(0xFFF5F8FB),
    onSurface: kOperonixBrandNavy,
    onSurfaceVariant: const Color(0xFF546E7A),
    surfaceContainerHighest: const Color(0xFFE4EAF0),
    surfaceContainerHigh: const Color(0xFFDAE3EC),
    surfaceContainer: const Color(0xFFEEF2F6),
    outline: _kScadaBorder,
    outlineVariant: const Color(0xFF90A4AE),
  );
}

ThemeData _applyOperonixAppBar(ThemeData parent, ColorScheme scheme) {
  return parent.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    colorScheme: scheme,
    appBarTheme: parent.appBarTheme.copyWith(
      backgroundColor: kOperonixBrandNavy,
      foregroundColor: _kScadaTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: _kScadaTextPrimary),
      titleTextStyle: parent.textTheme.titleLarge?.copyWith(
        color: _kScadaTextPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: kOperonixScadaAccentBlue,
      unselectedLabelColor: _kScadaTextMuted,
      indicatorColor: kOperonixScadaAccentBlue,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}

ThemeData _applyIndustrialNight(ThemeData parent, ColorScheme scheme) {
  return parent.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _kScadaWall,
    colorScheme: scheme,
    appBarTheme: parent.appBarTheme.copyWith(
      backgroundColor: _kScadaHeaderBar,
      foregroundColor: _kScadaTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: _kScadaTextPrimary),
      titleTextStyle: parent.textTheme.titleLarge?.copyWith(
        color: _kScadaTextPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: kOperonixScadaAccentBlue,
      unselectedLabelColor: _kScadaTextMuted,
      indicatorColor: kOperonixScadaAccentBlue,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}

ColorScheme _colorSchemeIndustrialNight() {
  final base = ColorScheme.fromSeed(
    seedColor: kOperonixScadaAccentBlue,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    primary: kOperonixScadaAccentBlue,
    onPrimary: const Color(0xFF041018),
    primaryContainer: _kScadaHeaderBar,
    onPrimaryContainer: _kScadaTextPrimary,
    secondary: const Color(0xFF7EB8FF),
    onSecondary: const Color(0xFF0B1F3A),
    secondaryContainer: const Color(0xFF1E3A5F),
    onSecondaryContainer: _kScadaTextPrimary,
    surface: const Color(0xFF12151C),
    onSurface: _kScadaTextPrimary,
    onSurfaceVariant: _kScadaTextMuted,
    surfaceContainerHighest: _kScadaPanel,
    surfaceContainerHigh: _kScadaHeaderBar,
    surfaceContainer: const Color(0xFF1C232E),
    surfaceContainerLow: const Color(0xFF181C24),
    surfaceContainerLowest: _kScadaWall,
    outline: _kScadaBorder,
    outlineVariant: _kScadaBorder.withValues(alpha: 0.55),
    inverseSurface: _kScadaTextPrimary,
    onInverseSurface: _kScadaWall,
    inversePrimary: kOperonixScadaAccentBlue,
  );
}

ThemeData _applyCleanLight(ThemeData parent, ColorScheme scheme) {
  return parent.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    colorScheme: scheme,
    appBarTheme: parent.appBarTheme.copyWith(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: scheme.onSurface),
      titleTextStyle: parent.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}

ColorScheme _colorSchemeCleanLight() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF455A64),
    brightness: Brightness.light,
  );
  return base.copyWith(
    surface: const Color(0xFFFAFAFA),
    onSurface: const Color(0xFF263238),
    onSurfaceVariant: const Color(0xFF546E7A),
    surfaceContainerHighest: const Color(0xFFECEFF1),
    surfaceContainerHigh: const Color(0xFFEEE8E6),
    outline: const Color(0xFFB0BEC5),
    outlineVariant: const Color(0xFFCFD8DC),
  );
}

/// Gradi temu stanice iz roditeljske [ThemeData] (tipografija ostaje).
ThemeData buildStationScreenTheme(
  ThemeData parent,
  StationScreenAppearance appearance,
) {
  if (appearance.custom != null) {
    return _buildCustomTheme(parent, appearance.custom!);
  }
  return _buildPresetTheme(parent, appearance.preset);
}

ThemeData _buildPresetTheme(ThemeData parent, StationScreenThemeId id) {
  switch (id) {
    case StationScreenThemeId.operonix:
      return _applyOperonixAppBar(parent, _colorSchemeOperonixBrandLight());
    case StationScreenThemeId.industrialDark:
      return _applyIndustrialNight(parent, _colorSchemeIndustrialNight());
    case StationScreenThemeId.cleanLight:
      return _applyCleanLight(parent, _colorSchemeCleanLight());
  }
}

ThemeData _buildCustomTheme(ThemeData parent, StationScreenCustomColors c) {
  final brightness = _brightnessForSurface(c.background);
  final scheme = ColorScheme.fromSeed(
    seedColor: c.primaryAccent,
    brightness: brightness,
  );
  final onBg = brightness == Brightness.dark ? _kScadaTextPrimary : kOperonixBrandNavy;
  final onBgMuted = brightness == Brightness.dark ? _kScadaTextMuted : const Color(0xFF546E7A);
  final outlineMuted = Color.alphaBlend(
    c.fieldOutline.withValues(alpha: 0.65),
    c.background,
  );

  final merged = scheme.copyWith(
    surface: brightness == Brightness.dark
        ? const Color(0xFF12151C)
        : const Color(0xFFFAFAFA),
    onSurface: onBg,
    onSurfaceVariant: onBgMuted,
    outline: c.fieldOutline,
    outlineVariant: outlineMuted,
  );

  return parent.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: c.background,
    colorScheme: merged,
    appBarTheme: parent.appBarTheme.copyWith(
      backgroundColor: Color.alphaBlend(
        c.primaryAccent.withValues(alpha: 0.14),
        c.background,
      ),
      foregroundColor: onBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: onBg),
      titleTextStyle: parent.textTheme.titleLarge?.copyWith(
        color: onBg,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primaryAccent,
      unselectedLabelColor: onBgMuted,
      indicatorColor: c.primaryAccent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.92),
      labelStyle: TextStyle(color: onBgMuted),
      hintStyle: TextStyle(color: onBgMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.fieldOutline, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outlineMuted, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.primaryAccent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primaryAccent,
        foregroundColor: merged.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primaryAccent,
        side: BorderSide(color: c.primaryAccent.withValues(alpha: 0.85)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: outlineMuted.withValues(alpha: 0.9),
    ),
  );
}
