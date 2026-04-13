import '../models/tracking_scrap_line.dart';

/// Kanonski kodovi defekata / škarta koje platforma dodijeli kompaniji.
///
/// Pravilo: kodovi se **nikad** ne mijenjaju; kompanija podešava samo prikazni naziv
/// (vidi [defectDisplayNamesKey] u sesiji / `companyData`).
class PlatformDefectCodes {
  PlatformDefectCodes._();

  /// Broj tipova po kompaniji (npr. DEF_001 … DEF_015).
  static const int count = 15;

  /// `index` 1-based: 1 → DEF_001, 15 → DEF_015.
  static String codeAt1Based(int index) {
    assert(index >= 1 && index <= count);
    return 'DEF_${index.toString().padLeft(3, '0')}';
  }

  static List<String> get allCodes =>
      List.generate(count, (i) => codeAt1Based(i + 1));
}

/// Ključ u `companyData` / sesiji: mapa `systemCode` → prikazni naziv.
/// Primjer: `{ "DEF_001": "Materijal", "DEF_002": "Alat", ... }`
const String defectDisplayNamesKey = 'defectDisplayNames';

/// Mapa kanonskog koda → prikazni naziv (iz `companies` / sesije).
Map<String, String> parseDefectDisplayNamesMap(Map<String, dynamic> companyData) {
  final raw = companyData[defectDisplayNamesKey];
  if (raw is! Map) return {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final key = k.toString().trim();
    final val = v.toString().trim();
    if (key.isEmpty || val.isEmpty) return;
    out[key] = val;
  });
  return out;
}

/// Prikazni naziv za [code] koristeći mapu iz kompanije; inače sam [code].
String displayLabelForScrapCode(String code, Map<String, String> namesByCode) {
  final t = namesByCode[code]?.trim() ?? '';
  return t.isNotEmpty ? t : code;
}

/// Pločice za unos škarta: fiksni [PlatformDefectCodes.allCodes], [ScrapTileDef.label] iz mape.
List<ScrapTileDef> defectTilesForCompanySession(Map<String, dynamic> companyData) {
  return defectTilesFromDisplayMap(parseDefectDisplayNamesMap(companyData));
}

/// Ista logika kao [defectTilesForCompanySession], ali s već spajenom mapom (npr. sesija + server).
List<ScrapTileDef> defectTilesFromDisplayMap(Map<String, String> namesByCode) {
  return [
    for (final code in PlatformDefectCodes.allCodes)
      ScrapTileDef(
        code: code,
        label: displayLabelForScrapCode(code, namesByCode),
      ),
  ];
}
