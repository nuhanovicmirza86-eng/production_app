/// Opcije prikaza operativne proizvodne stanice (M1-G1 backend `displayOptions`).
class ProductionStationDisplayOptions {
  final bool? quickEntryModeDefault;
  final int? accentThemeIndex;
  final bool? showPackingActions;
  final bool? showQtyTiles;
  final String? defaultUnitOverride;

  const ProductionStationDisplayOptions({
    this.quickEntryModeDefault,
    this.accentThemeIndex,
    this.showPackingActions,
    this.showQtyTiles,
    this.defaultUnitOverride,
  });

  factory ProductionStationDisplayOptions.fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const ProductionStationDisplayOptions();
    int? accent;
    final ai = raw['accentThemeIndex'];
    if (ai is int) {
      accent = ai;
    } else {
      accent = int.tryParse('${ai ?? ''}');
    }
    return ProductionStationDisplayOptions(
      quickEntryModeDefault: raw['quickEntryModeDefault'] == true
          ? true
          : raw['quickEntryModeDefault'] == false
          ? false
          : null,
      accentThemeIndex: accent,
      showPackingActions: raw['showPackingActions'] == true
          ? true
          : raw['showPackingActions'] == false
          ? false
          : null,
      showQtyTiles: raw['showQtyTiles'] == true
          ? true
          : raw['showQtyTiles'] == false
          ? false
          : null,
      defaultUnitOverride: _opt(raw['defaultUnitOverride']),
    );
  }

  Map<String, dynamic> toMap() {
    final out = <String, dynamic>{};
    if (quickEntryModeDefault != null) {
      out['quickEntryModeDefault'] = quickEntryModeDefault;
    }
    if (accentThemeIndex != null) {
      out['accentThemeIndex'] = accentThemeIndex;
    }
    if (showPackingActions != null) {
      out['showPackingActions'] = showPackingActions;
    }
    if (showQtyTiles != null) {
      out['showQtyTiles'] = showQtyTiles;
    }
    if (defaultUnitOverride != null && defaultUnitOverride!.isNotEmpty) {
      out['defaultUnitOverride'] = defaultUnitOverride;
    }
    return out;
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static const List<String> accentThemeLabels = [
    'Zelena',
    'Plava',
    'Narandžasta',
    'Ljubičasta',
  ];
}
