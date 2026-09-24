import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// QMS-M2 — globalni standard oznake QMS dokumenta na PDF-u / evidenciji.
///
/// Obavezni prikaz: Oznaka, Revizija, Status, Odobrio, Datum odobrenja,
/// Tip dokumenta, Vlasnik, Kategorija čuvanja.
/// Ako je status Odobreno bez imena odobravatelja → jasni audit gap (ne „—“).
abstract final class EvidencePdfQmsDocumentMarking {
  static const unlinkedMessage = 'Obrazac nije povezan / nije odobren';

  static const approvalAuditGapMessage = 'nedostaje audit odobrenja';

  static const documentTypeLabel = 'Obrazac / zapis kvaliteta';

  static const labelDocumentCode = 'Oznaka obrasca';
  static const labelRevision = 'Revizija';
  static const labelStatus = 'Status';
  static const labelApprovedBy = 'Odobrio';
  static const labelApprovedAt = 'Datum odobrenja';
  static const labelDocumentType = 'Tip dokumenta';
  static const labelOwner = 'Vlasnik';
  static const labelRetention = 'Kategorija čuvanja';

  static String statusLabel(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return 'Odobreno';
      case 'draft':
        return 'Nacrt';
      case 'obsolete':
        return 'Van upotrebe';
      default:
        final t = (raw ?? '').trim();
        return t.isEmpty ? '—' : t;
    }
  }

  /// dd.MM.yyyy HH:mm (lokalno iz ISO / parseable string).
  static String formatApprovedAt(String? iso) {
    final t = (iso ?? '').trim();
    if (t.isEmpty) return '';
    final dt = DateTime.tryParse(t);
    if (dt == null) return t;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static bool isLinkedApproved({
    required String status,
    required String code,
    String title = '',
  }) {
    return status.trim().toLowerCase() == 'approved' &&
        (code.trim().isNotEmpty || title.trim().isNotEmpty);
  }

  static bool hasApprovalAuditGap({
    required String status,
    required String approvedByName,
    String? approvedAtIso,
  }) {
    if (status.trim().toLowerCase() != 'approved') return false;
    if (approvedByName.trim().isEmpty) return true;
    if ((approvedAtIso ?? '').trim().isEmpty) return true;
    return false;
  }

  /// Vrijednost za polje Odobrio (HR; bez EN; gap umjesto lažnog „—“).
  static String approvedByDisplay({
    required String status,
    required String approvedByName,
  }) {
    final name = approvedByName.trim();
    if (status.trim().toLowerCase() == 'approved' && name.isEmpty) {
      return approvalAuditGapMessage;
    }
    return name.isEmpty ? '—' : name;
  }

  /// Vrijednost za Datum odobrenja.
  static String approvedAtDisplay({
    required String status,
    required String? approvedAtIso,
  }) {
    final formatted = formatApprovedAt(approvedAtIso);
    if (status.trim().toLowerCase() == 'approved' && formatted.isEmpty) {
      return approvalAuditGapMessage;
    }
    return formatted.isEmpty ? '—' : formatted;
  }

  static Map<String, String> readMarkingFields(Map<String, dynamic> fv) {
    final status = (fv['qmsControlledFormStatus'] ?? '').toString().trim();
    final code =
        (fv['qmsControlledFormDocumentCode'] ?? '').toString().trim();
    final title = (fv['qmsControlledFormTitle'] ?? '').toString().trim();
    final revRaw = fv['qmsControlledFormRevision'];
    final rev = revRaw == null ? '' : revRaw.toString().trim();
    final approvedBy =
        (fv['qmsControlledFormApprovedByName'] ?? '').toString().trim();
    final approvedAt =
        (fv['qmsControlledFormApprovedAt'] ?? '').toString().trim();
    final owner =
        (fv['qmsControlledFormOwnerDepartment'] ?? '').toString().trim();
    final retention =
        (fv['qmsControlledFormRetentionCategory'] ?? '').toString().trim();
    return {
      'status': status,
      'code': code,
      'title': title,
      'revision': rev,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'owner': owner,
      'retention': retention,
    };
  }

  /// Kompaktan blok odmah ispod naziva dokumenta (svi PDF-capable profili).
  static List<pw.Widget> underTitle({
    required Map<String, dynamic> fieldValues,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    double fontSize = 9,
  }) {
    final m = readMarkingFields(fieldValues);
    final status = m['status']!;
    final code = m['code']!;
    final title = m['title']!;

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

    String line(String label, String value) => '$label: $value';

    final gap = hasApprovalAuditGap(
      status: status,
      approvedByName: m['approvedBy']!,
      approvedAtIso: m['approvedAt'],
    );

    final style = pw.TextStyle(font: fontRegular, fontSize: fontSize);
    final gapStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fontSize,
      color: PdfColors.grey800,
    );

    return [
      pw.SizedBox(height: 4),
      pw.Text(line(labelDocumentCode, code.isEmpty ? '—' : code), style: style),
      pw.Text(
        line(labelRevision, m['revision']!.isEmpty ? '—' : m['revision']!),
        style: style,
      ),
      pw.Text(line(labelStatus, statusLabel(status)), style: style),
      pw.Text(
        line(
          labelApprovedBy,
          approvedByDisplay(status: status, approvedByName: m['approvedBy']!),
        ),
        style: gap ? gapStyle : style,
      ),
      pw.Text(
        line(
          labelApprovedAt,
          approvedAtDisplay(status: status, approvedAtIso: m['approvedAt']),
        ),
        style: gap ? gapStyle : style,
      ),
      pw.Text(line(labelDocumentType, documentTypeLabel), style: style),
      pw.Text(
        line(labelOwner, m['owner']!.isEmpty ? '—' : m['owner']!),
        style: style,
      ),
      pw.Text(
        line(labelRetention, m['retention']!.isEmpty ? '—' : m['retention']!),
        style: style,
      ),
    ];
  }

  /// Sekcija „Kontrola dokumenta“ — isti sadržaj kao underTitle (dva stupca).
  static List<pw.Widget> documentControlBlock({
    required Map<String, dynamic> fieldValues,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Widget Function(String) sectionTitle,
    required pw.Widget Function(List<pw.Widget>, List<pw.Widget>) twoCol,
    required pw.Widget Function(String, String) kv,
  }) {
    final m = readMarkingFields(fieldValues);
    final status = m['status']!;
    final code = m['code']!;
    final title = m['title']!;

    if (!isLinkedApproved(status: status, code: code, title: title)) {
      return const [];
    }

    final approvedBy = approvedByDisplay(
      status: status,
      approvedByName: m['approvedBy']!,
    );
    final approvedAt = approvedAtDisplay(
      status: status,
      approvedAtIso: m['approvedAt'],
    );

    return [
      sectionTitle('Kontrola dokumenta'),
      twoCol(
        [
          kv(labelDocumentCode, code.isEmpty ? '—' : code),
          kv(labelRevision, m['revision']!.isEmpty ? '—' : m['revision']!),
          kv(labelStatus, statusLabel(status)),
          kv(labelApprovedBy, approvedBy),
          kv(labelApprovedAt, approvedAt),
        ],
        [
          kv(labelDocumentType, documentTypeLabel),
          kv(labelOwner, m['owner']!.isEmpty ? '—' : m['owner']!),
          kv(labelRetention, m['retention']!.isEmpty ? '—' : m['retention']!),
        ],
      ),
      if (title.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
        ),
    ];
  }
}
