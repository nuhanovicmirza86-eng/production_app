import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// M1-I5-C6 — ispod PDF naslova: oznaka obrasca / revizija / status (ne opisni podnaslov).
abstract final class EvidencePdfQmsDocumentMarking {
  static const unlinkedMessage = 'Obrazac nije povezan / nije odobren';

  static String statusLabel(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return 'Aktivno';
      case 'draft':
        return 'Nacrt';
      case 'obsolete':
        return 'Van upotrebe';
      default:
        final t = (raw ?? '').trim();
        return t.isEmpty ? '—' : t;
    }
  }

  static bool isLinkedApproved({
    required String status,
    required String code,
    String title = '',
  }) {
    return status.trim().toLowerCase() == 'approved' &&
        (code.trim().isNotEmpty || title.trim().isNotEmpty);
  }

  /// Kompaktan blok odmah ispod naziva dokumenta.
  static List<pw.Widget> underTitle({
    required Map<String, dynamic> fieldValues,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    double fontSize = 9,
  }) {
    final status =
        (fieldValues['qmsControlledFormStatus'] ?? '').toString().trim();
    final code =
        (fieldValues['qmsControlledFormDocumentCode'] ?? '').toString().trim();
    final title =
        (fieldValues['qmsControlledFormTitle'] ?? '').toString().trim();
    final revRaw = fieldValues['qmsControlledFormRevision'];
    final rev = revRaw == null ? '' : revRaw.toString().trim();

    if (!isLinkedApproved(status: status, code: code, title: title)) {
      return [
        pw.SizedBox(height: 4),
        pw.Text(
          unlinkedMessage,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: fontSize,
            color: PdfColors.grey800,
          ),
        ),
      ];
    }

    String line(String label, String value) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return '$label: $v';
    }

    return [
      pw.SizedBox(height: 4),
      pw.Text(
        line('Oznaka obrasca', code),
        style: pw.TextStyle(font: fontRegular, fontSize: fontSize),
      ),
      pw.Text(
        line('Revizija', rev.isEmpty ? '—' : rev),
        style: pw.TextStyle(font: fontRegular, fontSize: fontSize),
      ),
      pw.Text(
        line('Status', statusLabel(status)),
        style: pw.TextStyle(font: fontRegular, fontSize: fontSize),
      ),
    ];
  }
}
