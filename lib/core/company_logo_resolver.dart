import 'dart:typed_data';

/// Polja na dokumentu `companies/{id}` relevantna za logo u UI-ju.
///
/// **Redoslijed:** `branding.autoLogoRasterUrl` → `branding.autoLogoUrl` (samo
/// ako nije SVG) → favicon lanac iz **`documentPdfSettings.website`**.
/// Ručni `logoUrl` / Super Admin upload nisu dio ovog toka.
class CompanyLogoResolver {
  CompanyLogoResolver._();

  static String? _pickAutoLogoRasterUrl(Map<String, dynamic> data) {
    final branding = data['branding'];
    if (branding is Map) {
      final t = (branding['autoLogoRasterUrl'] ?? '').toString().trim();
      if (t.startsWith('https://') || t.startsWith('http://')) return t;
    }
    return null;
  }

  static String? _pickAutoLogoUrl(Map<String, dynamic> data) {
    final branding = data['branding'];
    if (branding is Map) {
      final t = (branding['autoLogoUrl'] ?? '').toString().trim();
      if (t.startsWith('https://') || t.startsWith('http://')) return t;
    }
    return null;
  }

  static bool isSvgLogoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    final path = (uri?.path ?? trimmed).toLowerCase();
    return path.endsWith('.svg');
  }

  /// Backend raster wordmark (Storage `companies/.../branding/logo.png`).
  static bool isWordmarkLogoUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('/branding/logo.') ||
        lower.contains('%2fbranding%2flogo');
  }

  /// Kanonski web iz PDF — podaci kompanije (polje Web).
  static String? _pickDocumentPdfWebsite(Map<String, dynamic> data) {
    final pdf = data['documentPdfSettings'];
    if (pdf is Map) {
      final t = (pdf['website'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
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

  static List<String> resolveLogoImageCandidates(Map<String, dynamic> data) {
    final urls = <String>[];
    void add(String? raw) {
      final u = raw?.trim();
      if (u == null || u.isEmpty) return;
      if (!urls.contains(u)) urls.add(u);
    }

    add(_pickAutoLogoRasterUrl(data));

    final autoUrl = _pickAutoLogoUrl(data);
    if (autoUrl != null && !isSvgLogoUrl(autoUrl)) {
      add(autoUrl);
    }

    final web = _pickDocumentPdfWebsite(data);
    if (web != null) {
      for (final fav in faviconCandidatesFromWebsite(web)) {
        add(fav);
      }
    }

    return urls;
  }

  static String? resolveLogoImageUrl(Map<String, dynamic> data) {
    final list = resolveLogoImageCandidates(data);
    return list.isEmpty ? null : list.first;
  }

  /// PDF logo download: backend raster prvo, zatim isti lanac kao UI.
  static List<String> resolveLogoDownloadUrlsForPdf({
    required Map<String, dynamic> companyData,
  }) {
    return resolveLogoImageCandidates(companyData);
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
