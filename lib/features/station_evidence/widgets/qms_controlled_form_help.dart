import 'package:flutter/material.dart';

import '../../../modules/quality/widgets/qms_iatf_help.dart';
import '../export/evidence_pdf_qms_document_marking.dart';

/// QMS-M2 — HR tekstovi i procjena kompletnosti QMS oznake obrasca.
abstract final class QmsControlledFormHelp {
  static const infoTitle = 'QMS obrazac i oznaka dokumenta';

  static const approvalAuditGapMessage = 'nedostaje audit odobrenja';

  /// Puni postupak (info ikonica — admin / QMS dokumentacija).
  static const procedureMessage = '''
QMS obrazac se ne kreira ovdje. Ovo polje samo povezuje evidenciju sa već odobrenim QMS obrascem.

Da bi PDF prikazao ispravnu oznaku dokumenta, obrazac mora postojati u:
QMS → Dokumentacija → Obrasci

Obrazac mora imati:
• istu oznaku dokumenta
• vrstu dokumenta: Obrazac
• status: Odobreno
• opseg: Cijela kompanija
• reviziju
• vlasnika
• kategoriju čuvanja
• podatak ko je odobrio i kada je odobrio

Ako piše „Obrazac nije povezan / nije odobren“, potrebno je:
1. otvoriti QMS → Dokumentacija → Obrasci
2. kreirati ili pronaći obrazac s istom oznakom
3. odobriti ga kroz akciju „Odobri dokument“
4. vratiti se u konfiguraciju evidencije
5. unijeti istu oznaku obrasca
6. napraviti novu evidenciju i generisati novi PDF

Ako postoji stari odobren obrazac bez podatka ko ga je odobrio i kada, ne mijenja se direktno. Potrebno je napraviti „Nova revizija“ i zatim koristiti akciju „Odobri dokument“.
''';

  /// Kratka poruka za Detalje evidencije.
  static const detailsIncompleteMessage =
      'QMS obrazac nije kompletno povezan. Provjerite da obrazac postoji u '
      'QMS → Dokumentacija → Obrasci, da je tip dokumenta Obrazac, da je odobren '
      'kroz akciju „Odobri dokument“ i da oznaka odgovara oznaci u konfiguraciji evidencije.';

  static const detailsApprovalGapMessage =
      'Na povezanom obrascu nedostaje audit odobrenja (ko / kada). '
      'U QMS → Dokumentacija → Obrasci napravite „Nova revizija“, zatim „Odobri dokument“, '
      'pa pokrenite novu evidenciju (stare se ne mijenjaju unazad).';

  static QmsMarkingUiState assess(Map<String, dynamic>? fieldValues) {
    final fv = fieldValues ?? const <String, dynamic>{};
    final m = EvidencePdfQmsDocumentMarking.readMarkingFields(fv);
    final status = m['status']!;
    final code = m['code']!;
    final title = m['title']!;
    final linked = EvidencePdfQmsDocumentMarking.isLinkedApproved(
      status: status,
      code: code,
      title: title,
    );
    if (!linked) {
      return QmsMarkingUiState.unlinked;
    }
    if (EvidencePdfQmsDocumentMarking.hasApprovalAuditGap(
      status: status,
      approvedByName: m['approvedBy']!,
      approvedAtIso: m['approvedAt'],
    )) {
      return QmsMarkingUiState.approvalAuditGap;
    }
    return QmsMarkingUiState.complete;
  }
}

enum QmsMarkingUiState { unlinked, approvalAuditGap, complete }

/// Info ikonica s QMS-M2 procedurom.
class QmsControlledFormInfoIcon extends StatelessWidget {
  const QmsControlledFormInfoIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return QmsIatfInfoIcon(
      title: QmsControlledFormHelp.infoTitle,
      message: QmsControlledFormHelp.procedureMessage,
      size: size,
    );
  }
}

/// Banner na Detaljima evidencije kad QMS oznaka nije kompletna.
class QmsControlledFormMarkingBanner extends StatelessWidget {
  const QmsControlledFormMarkingBanner({
    super.key,
    required this.fieldValues,
  });

  final Map<String, dynamic> fieldValues;

  @override
  Widget build(BuildContext context) {
    final state = QmsControlledFormHelp.assess(fieldValues);
    if (state == QmsMarkingUiState.complete) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final message = state == QmsMarkingUiState.approvalAuditGap
        ? QmsControlledFormHelp.detailsApprovalGapMessage
        : QmsControlledFormHelp.detailsIncompleteMessage;
    final title = state == QmsMarkingUiState.approvalAuditGap
        ? 'Nedostaje audit odobrenja QMS obrasca'
        : 'QMS obrazac nije kompletno povezan';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const QmsControlledFormInfoIcon(size: 20),
          ],
        ),
      ),
    );
  }
}
