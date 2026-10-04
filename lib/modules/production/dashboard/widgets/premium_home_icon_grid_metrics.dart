/// Broj kolona i visina Premium kartice biraju se iz širine sadržaja.
///
/// Kartica ne smije biti uža od [minTileWidth]. Telefon s uobičajenim
/// paddingom (oko 328 px) ostaje na 2 kolone. Visina prati piktogram i
/// naslov, bez rezervirane prazne plohe.
class PremiumHomeIconGridMetrics {
  const PremiumHomeIconGridMetrics._();

  static const double minTileWidth = 150;
  static const double gap = 10;
  static const double tilePaddingH = 12;
  static const double padTop = 8;
  static const double padBottom = 8;
  static const double titleGap = 6;

  /// Large Premium spot. Density polish does not shrink the pictogram.
  static const double iconSlot = 60;
  static const double titleFontSize = 14;
  static const double titleLineHeight = 1.15;

  /// Third line only while the title column is still narrow.
  static const double twoLineTextWidth = 150;

  static int columnCount(double contentWidth) {
    if (!contentWidth.isFinite || contentWidth <= 0) return 1;
    final columns = ((contentWidth + gap) / (minTileWidth + gap)).floor();
    return columns < 1 ? 1 : columns;
  }

  static double tileWidth(double contentWidth) {
    final columns = columnCount(contentWidth);
    return (contentWidth - gap * (columns - 1)) / columns;
  }

  static int titleMaxLinesForTileWidth(double tileWidth) {
    final textWidth = tileWidth - tilePaddingH * 2;
    if (!textWidth.isFinite || textWidth <= 0) return 2;
    if (textWidth < twoLineTextWidth) return 3;
    return 2;
  }

  static int titleMaxLines(double contentWidth) {
    return titleMaxLinesForTileWidth(tileWidth(contentWidth));
  }

  /// Height follows the icon plus the title lines that tile actually needs.
  /// Wider tiles stay in the same band and do not grow into tall panels.
  static double tileExtentFor(double contentWidth) {
    final lines = titleMaxLines(contentWidth);
    final text = titleFontSize * titleLineHeight * lines;
    final raw = padTop + iconSlot + titleGap + text + padBottom + 8;
    final height = raw.ceilToDouble();
    if (tileWidth(contentWidth) >= 220) {
      if (height < 124) return 124;
      if (height > 140) return 140;
    }
    return height;
  }
}
