/// M1-I12-B — model vizuelnog NCR hodograma (read-only, BS labele).
library;

import '../utils/ncr_next_disposition_catalog.dart';
import '../utils/ncr_qms_responsibility_matrix.dart';
import '../utils/qms_ncr_display_labels.dart';

/// Vizuelno stanje čvora (koraci 1–4 i 6).
enum NcrHodogramStepPhase {
  pending,
  current,
  done,
  notApplicable,
}

/// Boja koraka 5 — Sljedeća akcija (vlasnik 2026-08-28).
enum NcrHodogramActionTone {
  /// Siva — akcija još nije odabrana.
  idle,

  /// Plava — akcija odabrana i dodijeljena.
  assigned,

  /// Žuta — rok se približava ili potreban nadzor.
  watch,

  /// Crvena — rok prekoračen ili proizvodnja zaustavljena.
  critical,

  /// Zelena — akcija završena / NCR zatvoren.
  complete,
}

enum NcrHodogramStepId {
  evidenceOutcome,
  containment,
  ncrCreated,
  notificationSent,
  nextAction,
  resolution,
}

extension NcrHodogramStepIdX on NcrHodogramStepId {
  String get titleBs {
    switch (this) {
      case NcrHodogramStepId.evidenceOutcome:
        return 'Ishod evidencije';
      case NcrHodogramStepId.containment:
        return 'Mjera zadržavanja';
      case NcrHodogramStepId.ncrCreated:
        return 'Neusaglašenost kreirana';
      case NcrHodogramStepId.notificationSent:
        return 'Obavijest poslana';
      case NcrHodogramStepId.nextAction:
        return 'Sljedeća akcija';
      case NcrHodogramStepId.resolution:
        return 'Status rješavanja';
    }
  }

  int get number => index + 1;
}

class NcrHodogramStepView {
  const NcrHodogramStepView({
    required this.id,
    required this.phase,
    required this.summary,
    this.actionTone,
    this.detailRows = const [],
  });

  final NcrHodogramStepId id;
  final NcrHodogramStepPhase phase;
  final String summary;
  final NcrHodogramActionTone? actionTone;
  final List<({String label, String value})> detailRows;

  String get title => id.titleBs;
}

class NcrHodogramSnapshot {
  const NcrHodogramSnapshot({
    required this.steps,
    required this.currentStepId,
    this.headlineNextStep,
  });

  final List<NcrHodogramStepView> steps;
  final NcrHodogramStepId currentStepId;
  final String? headlineNextStep;
}

/// Ulaz (samo poslovna polja — bez raw ID u UI sloju).
class NcrHodogramInput {
  const NcrHodogramInput({
    this.outcomeKey,
    this.outcomeLabel,
    this.containmentAction,
    this.holdApplied = false,
    this.holdSkipReason,
    this.ncrCode,
    this.ncrDocumentNo,
    this.hasNcr = false,
    this.fromEvidenceSession = false,
    this.nextDispositionActionKey,
    this.nextDispositionActionLabel,
    this.nextDispositionOwner,
    this.nextDispositionDueAt,
    this.nextDispositionReason,
    this.nextDispositionRoleLabel,
    this.nextDispositionPriorityLabel,
    this.nextDispositionTask,
    this.nextDispositionNote,
    this.nextDispositionPhase,
    this.nextDispositionExecutor,
    this.nextDispositionExecutorRoleLabel,
    this.ncrStatus,
    this.now,
  });

  final String? outcomeKey;
  final String? outcomeLabel;
  final String? containmentAction;
  final bool holdApplied;
  final String? holdSkipReason;
  final String? ncrCode;
  final String? ncrDocumentNo;
  final bool hasNcr;
  final bool fromEvidenceSession;
  final String? nextDispositionActionKey;
  final String? nextDispositionActionLabel;
  final String? nextDispositionOwner;
  final String? nextDispositionDueAt;
  final String? nextDispositionReason;
  final String? nextDispositionRoleLabel;
  final String? nextDispositionPriorityLabel;
  final String? nextDispositionTask;
  final String? nextDispositionNote;
  final String? nextDispositionPhase;
  final String? nextDispositionExecutor;
  final String? nextDispositionExecutorRoleLabel;
  final String? ncrStatus;
  final DateTime? now;
}

abstract final class NcrActionHodogramLogic {
  /// Dani do roka (uključivo) za žuti „watch”.
  static const watchWithinDays = 3;

  static String dash(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  static DateTime? parseDueDate(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    // YYYY-MM-DD or YYYY-MM-DDTHH:mm[:ss]
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(t);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4) ?? '0'),
        int.parse(m.group(5) ?? '0'),
        int.parse(m.group(6) ?? '0'),
      );
    }
    return DateTime.tryParse(t);
  }

  static String formatDueBs(String? raw) {
    final d = parseDueDate(raw);
    if (d == null) return dash(raw);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hasTime = RegExp(r'[T ]\d{2}:\d{2}').hasMatch((raw ?? '').trim());
    if (!hasTime) return '$dd.$mm.${d.year}.';
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}. $hh:$mi';
  }

  static bool isNcrClosed(String? status) {
    final s = (status ?? '').trim().toUpperCase();
    return s == 'CLOSED' || s == 'DISMISSED';
  }

  static NcrHodogramActionTone resolveActionTone({
    required String? actionKey,
    required String? dueAt,
    required String? ncrStatus,
    String? phase,
    DateTime? now,
  }) {
    if (isNcrClosed(ncrStatus)) {
      return NcrHodogramActionTone.complete;
    }
    final key = (actionKey ?? '').trim();
    if (key.isEmpty) return NcrHodogramActionTone.idle;

    if (key == NcrNextDispositionAction.stopProduction.key) {
      return NcrHodogramActionTone.critical;
    }

    final ph = (phase ?? '').trim().toLowerCase();
    if (key == NcrNextDispositionAction.sendToRework.key &&
        ph == 'awaiting_executor') {
      // Vlasnik dodijeljen; čeka se izvršilac — potreban nadzor.
      return NcrHodogramActionTone.watch;
    }

    final due = parseDueDate(dueAt);
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (due != null) {
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dueDay.isBefore(today)) {
        return NcrHodogramActionTone.critical;
      }
      final diff = dueDay.difference(today).inDays;
      if (diff <= watchWithinDays) {
        return NcrHodogramActionTone.watch;
      }
    }
    return NcrHodogramActionTone.assigned;
  }

  static String actionStatusLabel(NcrHodogramActionTone tone) {
    switch (tone) {
      case NcrHodogramActionTone.idle:
        return 'Nije odabrana';
      case NcrHodogramActionTone.assigned:
        return 'Dodijeljena';
      case NcrHodogramActionTone.watch:
        return 'Čeka dodjelu izvršioca ili rok se približava';
      case NcrHodogramActionTone.critical:
        return 'Kritično — rok prekoračen ili proizvodnja zaustavljena';
      case NcrHodogramActionTone.complete:
        return 'Završena / neusaglašenost zatvorena';
    }
  }

  static String actionLabelBs({
    required String? key,
    required String? label,
  }) {
    final fromCatalog = NcrNextDispositionCatalog.labelForKey(key);
    if (fromCatalog.isNotEmpty &&
        NcrNextDispositionCatalog.fromKey(key) != null) {
      return fromCatalog;
    }
    final l = (label ?? '').trim();
    if (l.isNotEmpty) return l;
    return '—';
  }

  static NcrHodogramSnapshot build(NcrHodogramInput input) {
    final hasOutcome = (input.outcomeLabel ?? '').trim().isNotEmpty ||
        (input.outcomeKey ?? '').trim().isNotEmpty;
    final containment = (input.containmentAction ?? '').trim();
    final hasContainment = containment.isNotEmpty ||
        input.holdApplied ||
        (input.holdSkipReason ?? '').trim().isNotEmpty;
    final hasNcr = input.hasNcr ||
        (input.ncrDocumentNo ?? '').trim().isNotEmpty ||
        (input.ncrCode ?? '').trim().isNotEmpty;
    final ncrCode = QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: input.ncrDocumentNo,
      ncrCode: input.ncrCode,
    );
    final ncrCodeDisplay = QmsNcrDisplayLabels.businessOrNull(ncrCode) ?? ncrCode;
    final actionKey = (input.nextDispositionActionKey ?? '').trim();
    final hasAction = actionKey.isNotEmpty;
    final closed = isNcrClosed(input.ncrStatus);
    final tone = resolveActionTone(
      actionKey: actionKey,
      dueAt: input.nextDispositionDueAt,
      ncrStatus: input.ncrStatus,
      phase: input.nextDispositionPhase,
      now: input.now,
    );

    // Korak 4: bez novog polja — obavijest je dio I6 create toka za evidence NCR.
    final notifDone = hasNcr && input.fromEvidenceSession;
    final notifNa = hasNcr && !input.fromEvidenceSession;

    final step1Done = hasOutcome || (hasNcr && !input.fromEvidenceSession);
    final step2Done = hasContainment;
    final step3Done = hasNcr;
    final step4Done = notifDone;
    final step5Done = hasAction;
    final step6Done = closed;

    final flags = <bool>[
      step1Done,
      step2Done,
      step3Done,
      step4Done || notifNa,
      step5Done,
      step6Done,
    ];

    var currentIndex = flags.indexWhere((d) => !d);
    if (currentIndex < 0) currentIndex = 5;

    NcrHodogramStepPhase phaseFor(int i, {bool na = false}) {
      if (na) return NcrHodogramStepPhase.notApplicable;
      if (i == currentIndex) return NcrHodogramStepPhase.current;
      if (flags[i]) return NcrHodogramStepPhase.done;
      return NcrHodogramStepPhase.pending;
    }

    String outcomeSummary() {
      if (hasOutcome) {
        final label = (input.outcomeLabel ?? '').trim();
        if (label.isNotEmpty) return label;
        return QmsNcrDisplayLabels.outcome(input.outcomeKey);
      }
      if (hasNcr && !input.fromEvidenceSession) {
        return 'Neusaglašenost nije vezana za ishod evidencije';
      }
      return 'Ishod još nije zabilježen';
    }

    String containmentSummary() {
      if (containment.isNotEmpty) return containment;
      if (input.holdApplied) return 'Zadržavanje lota (WMS) primijenjeno';
      final skip = (input.holdSkipReason ?? '').trim();
      if (skip == 'lot_not_provided') {
        return 'Zadržavanje lota nije primijenjeno (nema lota na evidenciji)';
      }
      if (skip.isNotEmpty) return 'Zadržavanje lota nije primijenjeno';
      return 'Mjera zadržavanja još nije unesena';
    }

    String ncrSummary() {
      if (!hasNcr) return 'Neusaglašenost još nije kreirana';
      if (ncrCodeDisplay.isNotEmpty && ncrCodeDisplay != 'Neusaglašenost') {
        return 'Broj: $ncrCodeDisplay';
      }
      return 'Neusaglašenost kreirana';
    }

    String notifSummary() {
      if (notifNa) {
        return 'Obavijest nije dio ovog toka (nije iz evidencije)';
      }
      if (notifDone) {
        return 'Sistemska obavijest poslana pri kreiranju';
      }
      return 'Obavijest čeka kreiranje neusaglašenosti';
    }

    final taskText = () {
      final t = (input.nextDispositionTask ?? '').trim();
      if (t.isNotEmpty) return t;
      final fromCatalog =
          NcrNextDispositionCatalog.fromKey(actionKey)?.taskTemplateBs;
      if (fromCatalog != null && fromCatalog.isNotEmpty) return fromCatalog;
      return (input.nextDispositionReason ?? '').trim();
    }();
    final noteText = (input.nextDispositionNote ?? '').trim();
    final phaseBs = NcrQmsResponsibilityMatrix.phaseLabelBs(
      input.nextDispositionPhase,
    );
    final executor = (input.nextDispositionExecutor ?? '').trim();
    final executorRole =
        (input.nextDispositionExecutorRoleLabel ?? '').trim();
    final isRework = actionKey == NcrNextDispositionAction.sendToRework.key;
    final actionDetails = <({String label, String value})>[
      (
        label: 'Akcija',
        value: actionLabelBs(
          key: actionKey,
          label: input.nextDispositionActionLabel,
        ),
      ),
      if (phaseBs.isNotEmpty) (label: 'Faza', value: phaseBs),
      (
        label: isRework ? 'Odgovorni vlasnik' : 'Odgovorna uloga',
        value: dash(input.nextDispositionRoleLabel),
      ),
      (
        label: isRework ? 'Vlasnik (osoba)' : 'Odgovorna osoba',
        value: dash(input.nextDispositionOwner),
      ),
      if (isRework) ...[
        (label: 'Izvršilac', value: dash(executor.isEmpty ? null : executor)),
        if (executorRole.isNotEmpty)
          (label: 'Uloga izvršioca', value: executorRole),
      ],
      (
        label: isRework ? 'Proizvodni rok' : 'Rok',
        value: formatDueBs(input.nextDispositionDueAt),
      ),
      (
        label: 'Prioritet',
        value: dash(
          input.nextDispositionPriorityLabel?.trim().isNotEmpty == true
              ? input.nextDispositionPriorityLabel
              : (hasAction
                  ? NcrNextDispositionCatalog.priorityHighBs
                  : null),
        ),
      ),
      (label: 'Zadatak', value: dash(taskText)),
      if (noteText.isNotEmpty) (label: 'Napomena', value: noteText),
      (label: 'Status akcije', value: actionStatusLabel(tone)),
    ];

    String actionSummary() {
      if (!hasAction) return 'Akcija još nije odabrana';
      return actionLabelBs(
        key: actionKey,
        label: input.nextDispositionActionLabel,
      );
    }

    String resolutionSummary() {
      final st = (input.ncrStatus ?? '').trim();
      if (st.isEmpty) return 'Status rješavanja nije postavljen';
      return QmsNcrDisplayLabels.status(st);
    }

    final ids = NcrHodogramStepId.values;
    final steps = <NcrHodogramStepView>[
      NcrHodogramStepView(
        id: ids[0],
        phase: phaseFor(0),
        summary: outcomeSummary(),
      ),
      NcrHodogramStepView(
        id: ids[1],
        phase: phaseFor(1),
        summary: containmentSummary(),
      ),
      NcrHodogramStepView(
        id: ids[2],
        phase: phaseFor(2),
        summary: ncrSummary(),
      ),
      NcrHodogramStepView(
        id: ids[3],
        phase: phaseFor(3, na: notifNa),
        summary: notifSummary(),
      ),
      NcrHodogramStepView(
        id: ids[4],
        phase: phaseFor(4),
        summary: actionSummary(),
        actionTone: tone,
        detailRows: actionDetails,
      ),
      NcrHodogramStepView(
        id: ids[5],
        phase: phaseFor(5),
        summary: resolutionSummary(),
      ),
    ];

    final currentId = ids[currentIndex];

    final String nextHint;
    switch (currentId) {
      case NcrHodogramStepId.evidenceOutcome:
        nextHint = 'Sačekajte završetak evidencije s negativnim ishodom.';
        break;
      case NcrHodogramStepId.containment:
        nextHint = 'Unesite mjeru zadržavanja na neusaglašenosti.';
        break;
      case NcrHodogramStepId.ncrCreated:
        nextHint = 'Neusaglašenost se kreira iz evidencije (automatski).';
        break;
      case NcrHodogramStepId.notificationSent:
        nextHint = 'Obavijest slijedi nakon kreiranja neusaglašenosti.';
        break;
      case NcrHodogramStepId.nextAction:
        nextHint = hasAction
            ? 'Pratite rok i izvršenje odabrane akcije.'
            : 'Odaberite sljedeću akciju i snimite odgovornu osobu i rok.';
        break;
      case NcrHodogramStepId.resolution:
        nextHint = closed
            ? 'Tok je zatvoren.'
            : 'Ažurirajte status rješavanja kad je mjerljivo riješeno.';
        break;
    }

    return NcrHodogramSnapshot(
      steps: steps,
      currentStepId: currentId,
      headlineNextStep: nextHint,
    );
  }
}
