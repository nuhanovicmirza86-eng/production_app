import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';

void main() {
  test('Premium platform chrome differs in structure from Classic', () {
    final classic = OperonixVisualTheme.classic();
    final premium = OperonixVisualTheme.premiumMidnight();

    expect(classic.cardTheme.elevation, 1);
    expect(premium.cardTheme.elevation, 0);
    expect(classic.inputDecorationTheme.filled, isNot(true));
    expect(premium.inputDecorationTheme.filled, isTrue);
    expect(premium.dialogTheme.shape, isA<RoundedRectangleBorder>());
    expect(premium.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());
    expect(premium.dataTableTheme.headingRowColor, isNotNull);
    expect(classic.dataTableTheme.headingRowColor, isNull);
    expect(premium.datePickerTheme.shape, isA<RoundedRectangleBorder>());
    expect(classic.datePickerTheme.shape, isNull);
    expect(
      premium.scaffoldBackgroundColor,
      OperonixVisualTokens.midnight().background,
    );
    expect(
      classic.scaffoldBackgroundColor,
      isNot(premium.scaffoldBackgroundColor),
    );
  });
}
