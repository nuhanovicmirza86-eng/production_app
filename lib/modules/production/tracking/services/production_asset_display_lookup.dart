import 'package:cloud_firestore/cloud_firestore.dart';

/// Prikazni naziv uređaja iz šifrarnika `assets` — **nikad** Firestore ID kao jedini tekst.
class ProductionAssetDisplayLookup {
  ProductionAssetDisplayLookup._(this._map);

  /// Ključevi: id dokumenta, kodovi, lower-case varijante → isti prikazni naziv.
  final Map<String, String> _map;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Isto kao u prijavi kvara / listi uređaja: primarni + sekundarni naziv.
  static String labelFromAssetData(Map<String, dynamic> d) {
    final primary = _s(d['primaryName']).isNotEmpty
        ? _s(d['primaryName'])
        : _s(d['name']);
    final secondary = _s(d['secondaryName']).isNotEmpty
        ? _s(d['secondaryName'])
        : _s(d['displayName']);
    if (primary.isEmpty && secondary.isEmpty) {
      final typ = _s(d['type']);
      if (typ.isNotEmpty) return typ;
      return 'Uređaj bez naziva u šifrarniku';
    }
    if (secondary.isEmpty) return primary;
    if (primary.isEmpty) return secondary;
    return '$primary — $secondary';
  }

  /// Učitava sve aktivne/neaktivne uređaje pogona (do [limit]) za mapiranje id/kod → naziv.
  static Future<ProductionAssetDisplayLookup> loadForPlant({
    required String companyId,
    required String plantKey,
    int limit = 500,
    FirebaseFirestore? firestore,
  }) async {
    final fs = firestore ?? FirebaseFirestore.instance;
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final map = <String, String>{};
    if (cid.isEmpty || pk.isEmpty) {
      return ProductionAssetDisplayLookup._(map);
    }

    final snap = await fs
        .collection('assets')
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .limit(limit)
        .get();

    void putKey(String? raw, String displayName) {
      final k = _s(raw);
      if (k.isEmpty) return;
      map[k] = displayName;
      map[k.toLowerCase()] = displayName;
    }

    for (final d in snap.docs) {
      final data = d.data();
      final name = labelFromAssetData(data);
      putKey(d.id, name);
      putKey(data['code'], name);
      putKey(data['assetCode'], name);
      putKey(data['internalCode'], name);
      putKey(data['systemCode'], name);
    }

    return ProductionAssetDisplayLookup._(map);
  }

  /// Prikaz za [rawKey] (obično `assetId` ili šifra); ne vraća sirovi ID.
  String resolve(
    String? rawKey, {
    String? eventTitle,
    String? faultDeviceName,
  }) {
    final key = _s(rawKey);
    if (key == '__no_asset_fault__') {
      final dn = _s(faultDeviceName);
      if (dn.isNotEmpty) return dn;
      return 'Kvarovi bez odabranog uređaja u šifrarniku';
    }
    if (key.isNotEmpty) {
      final hit = _map[key] ?? _map[key.toLowerCase()];
      if (hit != null) return hit;
    }
    final dn = _s(faultDeviceName);
    if (dn.isNotEmpty) return dn;
    final t = _s(eventTitle);
    if (t.isNotEmpty && !_looksLikeOpaqueTechnicalToken(t)) {
      return t;
    }
    if (key.isNotEmpty) {
      return 'Uređaj nije u šifrarniku (dodaj naziv u Uređaji)';
    }
    return 'Nepoznat uređaj';
  }

  /// Kad nema šifre — samo naslov događaja (ne ID).
  String resolveEventLine(String? assetCodeOrEmpty, String eventTitle) {
    final code = _s(assetCodeOrEmpty);
    if (code.isNotEmpty) {
      final hit = _map[code] ?? _map[code.toLowerCase()];
      if (hit != null) return hit;
    }
    final t = _s(eventTitle);
    if (t.isNotEmpty && !_looksLikeOpaqueTechnicalToken(t)) return t;
    if (code.isNotEmpty) {
      return 'Uređaj nije u šifrarniku (dodaj naziv u Uređaji)';
    }
    return 'Događaj bez šifre uređaja u šifrarniku';
  }

  static bool _looksLikeOpaqueTechnicalToken(String s) {
    final t = s.trim();
    if (t.length < 16) return false;
    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(t)) return true;
    return false;
  }

}
