import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../../core/company_logo_resolver.dart';
import '../models/document_pdf_settings.dart';
import 'document_pdf_settings_service.dart';

/// Jedinstveni podaci firme (tenant) za zaglavlje PDF dokumenata — učitavaju se iz
/// `companies/{id}.documentPdfSettings` + logo s URL-a.
class CompanyPrintIdentity {
  CompanyPrintIdentity({
    required this.settings,
    this.logoBytes,
  });

  final DocumentPdfSettings settings;
  final Uint8List? logoBytes;

  /// Prikazni naziv (postavke ili sesija).
  String primaryName(Map<String, dynamic> companyData) {
    final a = settings.companyLegalName.trim();
    if (a.isNotEmpty) return a;
    return (companyData['companyName'] ?? companyData['name'] ?? '')
        .toString()
        .trim();
  }

  /// Redovi ispod naziva (adresa, kontakt, banka …).
  List<String> detailLines() {
    final s = settings;
    final bank = <String>[];
    if (s.bankName.trim().isNotEmpty ||
        s.bankAccount.trim().isNotEmpty ||
        s.bankIban.trim().isNotEmpty) {
      if (s.bankName.trim().isNotEmpty) bank.add(s.bankName.trim());
      final acc = [s.bankAccount, s.bankIban]
          .where((e) => e.trim().isNotEmpty)
          .join(' · ');
      if (acc.isNotEmpty) bank.add(acc);
    }
    return <String>[
      if (s.businessDescription.trim().isNotEmpty)
        s.businessDescription.trim(),
      if (s.addressLine1.trim().isNotEmpty) s.addressLine1.trim(),
      if (s.addressLine2.trim().isNotEmpty) s.addressLine2.trim(),
      if (s.phone.trim().isNotEmpty) 'Tel: ${s.phone.trim()}',
      if (s.fax.trim().isNotEmpty) 'Fax: ${s.fax.trim()}',
      if (s.email.trim().isNotEmpty) s.email.trim(),
      if (s.website.trim().isNotEmpty) s.website.trim(),
      if (s.courtRegistration.trim().isNotEmpty)
        'Sud: ${s.courtRegistration.trim()}',
      if (s.idNumber.trim().isNotEmpty) 'ID: ${s.idNumber.trim()}',
      if (s.vatNumber.trim().isNotEmpty) 'PDV: ${s.vatNumber.trim()}',
      ...bank,
    ];
  }
}

class CompanyPrintIdentityService {
  CompanyPrintIdentityService({
    DocumentPdfSettingsService? settingsService,
    FirebaseFunctions? functions,
  }) : _settingsService = settingsService ?? DocumentPdfSettingsService(),
       _functions = functions ??
           FirebaseFunctions.instanceFor(region: 'europe-west1');

  final DocumentPdfSettingsService _settingsService;
  final FirebaseFunctions _functions;

  Future<CompanyPrintIdentity> load({
    required String companyId,
    required Map<String, dynamic> companyData,
  }) async {
    final cid = companyId.trim();
    final settings = cid.isEmpty
        ? const DocumentPdfSettings()
        : await _settingsService.load(cid);
    final logoBytes = await loadLogoBytesForPdf(
      companyId: cid,
      settings: settings,
      companyData: companyData,
      functions: _functions,
    );
    return CompanyPrintIdentity(settings: settings, logoBytes: logoBytes);
  }

  /// Dijeli logiku učitavanja loga za sve PDF izvoze (web: CORS → Callable).
  static Future<Uint8List?> loadLogoBytesForPdf({
    required String companyId,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
    FirebaseFunctions? functions,
  }) async {
    final urls = CompanyLogoResolver.resolveLogoDownloadUrlsForPdf(
      settingsLogoUrl: settings.logoUrl,
      companyData: companyData,
    );
    if (urls.isEmpty) return null;

    final fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

    if (!kIsWeb) {
      for (final url in urls) {
        final b = await _tryDownload(url);
        if (b != null && CompanyLogoResolver.isLikelyRasterImageBytes(b)) {
          return b;
        }
      }
    }

    return _fetchLogoViaCallable(
      companyId: companyId,
      urls: urls,
      functions: fn,
    );
  }

  static Future<Uint8List?> _fetchLogoViaCallable({
    required String companyId,
    required List<String> urls,
    required FirebaseFunctions functions,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return null;
    try {
      final callable = functions.httpsCallable('fetchCompanyLogoBytesForPdf');
      final res = await callable.call(<String, dynamic>{
        'companyId': cid,
        'urls': urls.take(24).toList(),
      });
      final data = res.data;
      if (data is! Map) return null;
      final b64 = (data['bytesBase64'] ?? '').toString().trim();
      if (b64.isEmpty) return null;
      return Uint8List.fromList(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _tryDownload(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
