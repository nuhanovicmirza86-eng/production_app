import 'package:flutter/material.dart';

import '../theme/operonix_production_brand.dart';
import 'visual_style.dart';

/// Centralni Classic / Premium Midnight tokeni.
///
/// Ekrani čitaju ovaj extension. Ne rasipaju sirove boje po pilotu.
@immutable
class OperonixVisualTokens extends ThemeExtension<OperonixVisualTokens> {
  final VisualStyle style;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceInteractive;
  final Color border;
  final Color divider;
  final Color primaryText;
  final Color secondaryText;
  final Color disabledText;
  final Color primaryAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Classic KPI „U toku” ostaje deep orange. Premium koristi aktivni narančasto-crveni akcent.
  final Color kpiActive;

  /// Obrub standardne kartice. Classic = brend zelena 1.5. Premium = suzdržani border.
  final Color cardBorder;
  final double cardBorderWidth;

  /// Površina KPI kartice. Classic = bijela, kao dosadašnji [StandardKpiGrid].
  final Color kpiSurface;
  final Color kpiBorder;

  /// Pozadina liste naloga. Classic = postojeći `0xFFF5F6FA`.
  final Color pageBackground;

  /// Meta linija / labela pogona. Classic = `Colors.grey.shade800`.
  final Color metaText;

  /// Akcent modula na početnoj. Classic = brend zelena.
  final Color moduleAccent;

  /// Tekst na punom akcentu (badge, primarno dugme).
  final Color onAccent;

  final Color fieldOutline;
  final Color fieldFocus;

  final double cardRadius;
  final double kpiRadius;
  final double sectionSpacing;

  const OperonixVisualTokens({
    required this.style,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceInteractive,
    required this.border,
    required this.divider,
    required this.primaryText,
    required this.secondaryText,
    required this.disabledText,
    required this.primaryAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.kpiActive,
    required this.cardBorder,
    required this.cardBorderWidth,
    required this.kpiSurface,
    required this.kpiBorder,
    required this.pageBackground,
    required this.metaText,
    required this.moduleAccent,
    required this.onAccent,
    required this.fieldOutline,
    required this.fieldFocus,
    required this.cardRadius,
    required this.kpiRadius,
    required this.sectionSpacing,
  });

  bool get isPremium => style == VisualStyle.premium;

  static OperonixVisualTokens of(BuildContext context) {
    return Theme.of(context).extension<OperonixVisualTokens>() ??
        OperonixVisualTokens.classic();
  }

  /// Vrijednosti koje reproduciraju trenutni svijetli Production UI.
  factory OperonixVisualTokens.classic() {
    return OperonixVisualTokens(
      style: VisualStyle.classic,
      background: const Color(0xFFF5F6FA),
      surface: Colors.white,
      surfaceElevated: Colors.white,
      surfaceInteractive: const Color(0xFFF3F6F8),
      border: const Color(0xFFE0E0E0),
      divider: const Color(0xFFE0E0E0),
      primaryText: const Color(0xDD000000),
      secondaryText: const Color(0x8A000000),
      disabledText: const Color(0x61000000),
      primaryAccent: kOperonixProductionBrandGreen,
      success: Colors.green,
      warning: Colors.orange,
      danger: const Color(0xFFB00020),
      info: Colors.blue,
      kpiActive: Colors.deepOrange,
      cardBorder: kOperonixProductionBrandGreen,
      cardBorderWidth: 1.5,
      kpiSurface: Colors.white,
      kpiBorder: const Color(0xFFEEEEEE),
      pageBackground: const Color(0xFFF5F6FA),
      metaText: const Color(0xFF424242),
      moduleAccent: kOperonixProductionBrandGreen,
      onAccent: Colors.white,
      fieldOutline: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
      fieldFocus: kOperonixProductionBrandGreen,
      cardRadius: 12,
      kpiRadius: 14,
      sectionSpacing: 12,
    );
  }

  /// Premium Midnight. Duboki navy / grafit, bez neon efekta i bez ravnog crnog polja.
  ///
  /// Hijerarhija: background → surface → surfaceElevated → surfaceInteractive.
  /// [border] je suzdržan, [cardBorder] jači.
  factory OperonixVisualTokens.midnight() {
    const primaryText = Color(0xFFE6EDF3);
    const secondaryText = Color(0xFF8B949E);
    const accent = Color(0xFF3D9A94);
    const borderSubtle = Color(0xFF2C3A52);
    const borderStrong = Color(0xFF3E5270);
    return OperonixVisualTokens(
      style: VisualStyle.premium,
      background: const Color(0xFF0A1020),
      surface: const Color(0xFF121A2B),
      surfaceElevated: const Color(0xFF182338),
      surfaceInteractive: const Color(0xFF223049),
      border: borderSubtle,
      divider: const Color(0xFF243044),
      primaryText: primaryText,
      secondaryText: secondaryText,
      disabledText: const Color(0xFF6E7681),
      primaryAccent: accent,
      success: const Color(0xFF3DCF8C),
      warning: const Color(0xFFE0A106),
      danger: const Color(0xFFE35D5D),
      info: const Color(0xFF58A6FF),
      kpiActive: const Color(0xFFFF7043),
      cardBorder: borderStrong,
      cardBorderWidth: 1,
      kpiSurface: const Color(0xFF182338),
      kpiBorder: borderStrong,
      pageBackground: const Color(0xFF0A1020),
      metaText: secondaryText,
      moduleAccent: accent,
      onAccent: const Color(0xFF041614),
      fieldOutline: borderSubtle,
      fieldFocus: accent,
      cardRadius: 12,
      kpiRadius: 14,
      sectionSpacing: 12,
    );
  }

  ShapeBorder get cardShape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: cardBorder, width: cardBorderWidth),
    );
  }

  @override
  OperonixVisualTokens copyWith({
    VisualStyle? style,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceInteractive,
    Color? border,
    Color? divider,
    Color? primaryText,
    Color? secondaryText,
    Color? disabledText,
    Color? primaryAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? kpiActive,
    Color? cardBorder,
    double? cardBorderWidth,
    Color? kpiSurface,
    Color? kpiBorder,
    Color? pageBackground,
    Color? metaText,
    Color? moduleAccent,
    Color? onAccent,
    Color? fieldOutline,
    Color? fieldFocus,
    double? cardRadius,
    double? kpiRadius,
    double? sectionSpacing,
  }) {
    return OperonixVisualTokens(
      style: style ?? this.style,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceInteractive: surfaceInteractive ?? this.surfaceInteractive,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      disabledText: disabledText ?? this.disabledText,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      kpiActive: kpiActive ?? this.kpiActive,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      kpiSurface: kpiSurface ?? this.kpiSurface,
      kpiBorder: kpiBorder ?? this.kpiBorder,
      pageBackground: pageBackground ?? this.pageBackground,
      metaText: metaText ?? this.metaText,
      moduleAccent: moduleAccent ?? this.moduleAccent,
      onAccent: onAccent ?? this.onAccent,
      fieldOutline: fieldOutline ?? this.fieldOutline,
      fieldFocus: fieldFocus ?? this.fieldFocus,
      cardRadius: cardRadius ?? this.cardRadius,
      kpiRadius: kpiRadius ?? this.kpiRadius,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
    );
  }

  @override
  OperonixVisualTokens lerp(OperonixVisualTokens? other, double t) {
    if (other == null) return this;
    return OperonixVisualTokens(
      style: t < 0.5 ? style : other.style,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceInteractive: Color.lerp(
        surfaceInteractive,
        other.surfaceInteractive,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      kpiActive: Color.lerp(kpiActive, other.kpiActive, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderWidth: cardBorderWidth +
          (other.cardBorderWidth - cardBorderWidth) * t,
      kpiSurface: Color.lerp(kpiSurface, other.kpiSurface, t)!,
      kpiBorder: Color.lerp(kpiBorder, other.kpiBorder, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      metaText: Color.lerp(metaText, other.metaText, t)!,
      moduleAccent: Color.lerp(moduleAccent, other.moduleAccent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      fieldOutline: Color.lerp(fieldOutline, other.fieldOutline, t)!,
      fieldFocus: Color.lerp(fieldFocus, other.fieldFocus, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      kpiRadius: kpiRadius + (other.kpiRadius - kpiRadius) * t,
      sectionSpacing:
          sectionSpacing + (other.sectionSpacing - sectionSpacing) * t,
    );
  }
}
