import 'dart:typed_data';

/// Polja na dokumentu `companies/{id}` relevantna za logo u UI-ju.
///
/// **Primarni izvor:** `websiteUrl` — javna web adresa kompanije; iz nje se gradi
/// URL favicona (Google `faviconV2` servis).
///
/// **Nadjačavanje:** ako postoji izravni URL slike (`logoUrl`, …), koristi se on.
class CompanyLogoResolver {
  CompanyLogoResolver._();

  static String? _pickExplicitHttp(Map<String, dynamic> data) {
    String? pick(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      if (t.startsWith('https://') || t.startsWith('http://')) return t;
      return null;
    }

    for (final key in ['logoUrl', 'companyLogoUrl', 'brandLogoUrl']) {
      final u = pick((data[key] ?? '').toString());
      if (u != null) return u;
    }

    final branding = data['branding'];
    if (branding is Map) {
      for (final key in ['logoUrl', 'logo', 'imageUrl', 'iconUrl']) {
        final u = pick((branding[key] ?? '').toString());
        if (u != null) return u;
      }
    }
    return null;
  }

  /// Službeni ključ u Firestoreu: [websiteUrl]. Prihvata i `website`, `companyWebsite`.
  static String? _pickWebsiteRaw(Map<String, dynamic> data) {
    for (final key in ['websiteUrl', 'website', 'companyWebsite', 'webUrl']) {
      final t = (data[key] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    final branding = data['branding'];
    if (branding is Map) {
      for (final key in ['websiteUrl', 'website']) {
        final t = (branding[key] ?? '').toString().trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  static Uri? _normalizeWebsiteUri(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (!t.contains('://')) {
      t = 'https://$t';
    }
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return null;
    if (u.scheme != 'http' && u.scheme != 'https') return null;
    return u;
  }

  /// Kandidati za sliku loga iz [websiteUrl] (prvi koji se uspješno učita u UI-u).
  ///
  /// Redoslijed: Google faviconV2 → Google s2 po domenu → DuckDuckGo → `/favicon.ico`
  /// → `/apple-touch-icon.png` (česti Next.js / marketing sajtovi).
  static List<String> faviconCandidatesFromWebsite(String rawWebsite) {
    final u = _normalizeWebsiteUri(rawWebsite);
    if (u == null) return const [];

    final origin = '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}/';
    final encodedOrigin = Uri.encodeComponent(origin);
    final host = u.host;
    final base = '${u.scheme}://$host';

    return <String>[
      'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=$encodedOrigin&size=128',
      'https://www.google.com/s2/favicons?sz=128&domain=${Uri.encodeComponent(host)}',
      'https://icons.duckduckgo.com/ip3/$host.ico',
      '$base/favicon.ico',
      '$base/apple-touch-icon.png',
      '$base/favicon.svg',
    ];
  }

  /// Izravni `logoUrl` — jedan element; inače lista favicon kandidata s weba.
  static List<String> resolveLogoImageCandidates(Map<String, dynamic> data) {
    final explicit = _pickExplicitHttp(data);
    if (explicit != null) return [explicit];

    final web = _pickWebsiteRaw(data);
    if (web == null) return const [];

    return faviconCandidatesFromWebsite(web);
  }

  /// Prvi kandidat (za jednostavne slučajeve); za pouzdanije učitavanje koristi [resolveLogoImageCandidates].
  static String? resolveLogoImageUrl(Map<String, dynamic> data) {
    final list = resolveLogoImageCandidates(data);
    return list.isEmpty ? null : list.first;
  }

  /// URL iz polja „logo“ u PDF postavkama: može biti **direktna slika** ili **adresa sajta**
  /// (npr. `www.firma.ba` ili `https://firma.ba`) — tada se koriste favicon kandidati.
  /// Redoslijed: eksplicitni logo u postavkama → kandidati s `companyData`.
  static List<String> resolveLogoDownloadUrlsForPdf({
    required dynamic settingsLogoUrl,
    required Map<String, dynamic> companyData,
  }) {
    final urls = <String>[];
    final raw = (settingsLogoUrl ?? '').toString().trim();
    if (raw.isNotEmpty) {
      var normalized = raw;
      if (!normalized.contains('://')) {
        normalized = 'https://$normalized';
      }
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        final schemeOk = uri.scheme == 'http' || uri.scheme == 'https';
        if (schemeOk) {
          final path = uri.path.toLowerCase();
          final looksLikeRasterOrSvg =
              path.endsWith('.png') ||
              path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.gif') ||
              path.endsWith('.webp') ||
              path.endsWith('.svg') ||
              path.endsWith('.ico');
          if (looksLikeRasterOrSvg && path.isNotEmpty) {
            urls.add(uri.toString());
          } else {
            final forFav = raw.contains('://') ? raw : normalized;
            urls.addAll(faviconCandidatesFromWebsite(forFav));
          }
        }
      }
    }
    urls.addAll(resolveLogoImageCandidates(companyData));
    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }

  /// PNG, JPEG, GIF, WEBP, ICO — `package:pdf` [MemoryImage] ne koristi SVG.
  static bool isLikelyRasterImageBytes(Uint8List b) {
    if (b.length < 4) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return true;
    }
    if (b.length >= 8 &&
        b[0] == 0x47 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x38) {
      return true;
    }
    if (b.length >= 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46) {
      final tag = String.fromCharCodes(b.sublist(8, 12));
      if (tag == 'WEBP') return true;
    }
    if (b[0] == 0x00 && b[1] == 0x00 && b[2] == 0x01 && b[3] == 0x00) {
      return true;
    }
    if (b[0] == 0x00 && b[1] == 0x00 && b[2] == 0x02 && b[3] == 0x00) {
      return true;
    }
    return false;
  }
}
