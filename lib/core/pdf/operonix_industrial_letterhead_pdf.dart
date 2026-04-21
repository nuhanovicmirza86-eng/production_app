import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Službeni Operonix logo na vrhu PDF dokumenata u Operonix Production.
///
/// Pun wordmark + tagline u slici — `branding/operonix_company_logo.png`.
class OperonixIndustrialLetterheadPdf {
  OperonixIndustrialLetterheadPdf._();

  static const String assetPath = 'branding/operonix_company_logo.png';

  static final PdfColor _navy = PdfColor.fromInt(0xFF0B1F3A);

  static Future<Uint8List> loadLogoBytes() async {
    final b = await rootBundle.load(assetPath);
    return b.buffer.asUint8List();
  }

  static pw.Widget strip({
    required Uint8List logoBytes,
    double maxLogoHeight = 44,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _navy, width: 1),
        ),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          height: maxLogoHeight,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }
}
