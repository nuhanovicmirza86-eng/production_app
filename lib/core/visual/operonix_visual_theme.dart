import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/operonix_production_brand.dart';
import 'operonix_visual_tokens.dart';
import 'premium/premium_widgets.dart';
import 'visual_style.dart';

/// Gradi [ThemeData] za Classic (postojeći Production) ili Premium Midnight.
class OperonixVisualTheme {
  const OperonixVisualTheme._();

  static ThemeData forStyle(VisualStyle style) {
    switch (style) {
      case VisualStyle.classic:
        return classic();
      case VisualStyle.premium:
        return premiumMidnight();
    }
  }

  /// Isti seed, kartica i polja kao dosadašnji [MyApp] theme.
  static ThemeData classic() {
    const brand = Color(0xFF164344);
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      useMaterial3: true,
      visualDensity: kIsWeb ? VisualDensity.compact : VisualDensity.standard,
      extensions: [OperonixVisualTokens.classic()],
    );
    final scheme = baseTheme.colorScheme;
    return baseTheme.copyWith(
      cardTheme: const CardThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: kOperonixProductionCardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: kIsWeb
            ? const EdgeInsets.fromLTRB(14, 18, 14, 14)
            : null,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: kOperonixProductionBrandGreen,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
    );
  }

  static ThemeData premiumMidnight() =>
      premiumWith(OperonixVisualTokens.midnight());

  /// Premium struktura ostaje ista. Paleta mijenja platno, površine i akcent.
  ///
  /// Svijetlo platno (Svijetla proizvodnja) ostaje Premium: brightness prati
  /// platno, ne globalni VisualStyle.
  static ThemeData premiumWith(OperonixVisualTokens tokens) {
    final lightCanvas = tokens.background.computeLuminance() > 0.45;
    final scheme = ColorScheme(
      brightness: lightCanvas ? Brightness.light : Brightness.dark,
      primary: tokens.primaryAccent,
      onPrimary: tokens.onAccent,
      secondary: tokens.info,
      onSecondary: const Color(0xFF041018),
      error: tokens.danger,
      onError: const Color(0xFF2A0A0A),
      surface: tokens.surface,
      onSurface: tokens.primaryText,
      onSurfaceVariant: tokens.secondaryText,
      outline: tokens.border,
      outlineVariant: tokens.divider,
      surfaceContainerLowest: tokens.background,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surfaceElevated,
      surfaceContainerHigh: tokens.surfaceInteractive,
      surfaceContainerHighest: tokens.surfaceInteractive,
      primaryContainer: tokens.surfaceInteractive,
      onPrimaryContainer: tokens.primaryText,
      secondaryContainer: tokens.primaryAccent.withValues(alpha: 0.22),
      onSecondaryContainer: tokens.primaryAccent,
      errorContainer: lightCanvas
          ? const Color(0xFFFDECEC)
          : const Color(0xFF4A1C1C),
      onErrorContainer: lightCanvas
          ? const Color(0xFF6B1212)
          : const Color(0xFFFFD6D6),
    );

    final radius = BorderRadius.circular(tokens.cardRadius);
    OutlineInputBorder outline(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final textTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF164344)),
      visualDensity: kIsWeb ? VisualDensity.compact : VisualDensity.standard,
    ).textTheme.apply(
      bodyColor: tokens.primaryText,
      displayColor: tokens.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: lightCanvas ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      visualDensity: kIsWeb ? VisualDensity.compact : VisualDensity.standard,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: tokens.cardShape,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: tokens.primaryText, size: 22),
        actionsIconTheme: IconThemeData(color: tokens.primaryText, size: 22),
        titleTextStyle: TextStyle(
          color: tokens.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.primaryText,
          minimumSize: const Size(48, 48),
          iconSize: 22,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.surfaceInteractive,
      ),
      navigationBarTheme: PremiumNavigationSelection.barTheme(tokens),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: tokens.primaryText, fontSize: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.primaryAccent,
        unselectedLabelColor: tokens.secondaryText,
        indicatorColor: tokens.primaryAccent,
        dividerColor: tokens.divider,
      ),
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
      iconTheme: IconThemeData(color: tokens.secondaryText),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceInteractive,
        labelStyle: TextStyle(color: tokens.secondaryText),
        hintStyle: TextStyle(color: tokens.disabledText),
        contentPadding: kIsWeb
            ? const EdgeInsets.fromLTRB(14, 18, 14, 14)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: outline(tokens.border),
        enabledBorder: outline(tokens.border),
        focusedBorder: outline(tokens.fieldFocus, width: 2),
        disabledBorder: outline(tokens.disabledText),
        errorBorder: outline(tokens.danger),
        focusedErrorBorder: outline(tokens.danger, width: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primaryAccent,
          foregroundColor: tokens.onAccent,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primaryAccent,
          foregroundColor: tokens.onAccent,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primaryText,
          side: BorderSide(color: tokens.border),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.primaryAccent,
        foregroundColor: tokens.onAccent,
        elevation: 1,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.primaryText;
            }
            return tokens.secondaryText;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.primaryAccent.withValues(alpha: 0.22);
            }
            return tokens.surfaceElevated;
          }),
          side: WidgetStateProperty.all(BorderSide(color: tokens.border)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceElevated,
        selectedColor: tokens.primaryAccent.withValues(alpha: 0.22),
        disabledColor: tokens.surface,
        labelStyle: TextStyle(color: tokens.primaryText),
        secondaryLabelStyle: TextStyle(color: tokens.primaryText),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: tokens.primaryText),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(tokens.surfaceElevated),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        tilePadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        childrenPadding: EdgeInsets.only(bottom: 8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.secondaryText,
        textColor: tokens.primaryText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: tokens.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(tokens.surfaceInteractive),
        headingTextStyle: TextStyle(
          color: tokens.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: tokens.primaryText, fontSize: 13),
        dividerThickness: 1,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: tokens.surfaceElevated,
        headerBackgroundColor: tokens.surface,
        headerForegroundColor: tokens.primaryText,
        dayForegroundColor: WidgetStatePropertyAll(tokens.primaryText),
        todayForegroundColor: WidgetStatePropertyAll(tokens.primaryAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceInteractive,
        contentTextStyle: TextStyle(color: tokens.primaryText),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.primaryAccent,
      ),
    );
  }
}
