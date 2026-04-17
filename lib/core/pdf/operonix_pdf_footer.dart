import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Tekstualni footer koji se pojavljuje na PDF dokumentima generisanim u Operonix Production.
class OperonixPdfFooter {
  OperonixPdfFooter._();

  static const String text =
      'Kompanija koristi Operonix industrial intelligence platform';

  /// Za [pw.MultiPage.footer] — Operonix lijevo, broj stranice desno.
  static pw.Widget multiPageFooter(
    pw.Context context,
    pw.Font font, {
    bool showPageNumbers = true,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: font,
              fontSize: 6,
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.left,
          ),
        ),
        if (showPageNumbers)
          pw.Text(
            'Strana ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: 7,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
      ],
    );
  }

  /// Jednostrani dokumenti ([pw.Page]) — sitan tekst pri dnu (lijevo).
  static pw.Widget inline(pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 6,
          color: PdfColors.grey600,
        ),
        textAlign: pw.TextAlign.left,
      ),
    );
  }
}
