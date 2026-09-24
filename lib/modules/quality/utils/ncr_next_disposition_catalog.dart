import 'package:flutter/material.dart';

import 'ncr_qms_responsibility_matrix.dart';

export 'ncr_qms_responsibility_matrix.dart'
    show NcrDispositionRoleOption, NcrDispositionFlowPhase;

/// M1-I10-A / M1-I12-B — preddefinisane sljedeće akcije na hodogramu neusaglašenosti.
enum NcrNextDispositionAction {
  sendToRework,
  scheduleRecheck,
  stopProduction,
}

extension NcrNextDispositionActionX on NcrNextDispositionAction {
  String get key {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return 'send_to_rework';
      case NcrNextDispositionAction.scheduleRecheck:
        return 'schedule_recheck';
      case NcrNextDispositionAction.stopProduction:
        return 'stop_production';
    }
  }

  /// CTA / gumb (pokretanje iz kontrole kvaliteta).
  String get labelHr {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return 'Pošalji na doradu';
      case NcrNextDispositionAction.scheduleRecheck:
        return 'Zakaži ponovnu kontrolu';
      case NcrNextDispositionAction.stopProduction:
        return 'Zaustavi proizvodnju';
    }
  }

  /// Poslovni naziv akcije na hodogramu / nakon pokretanja.
  String get businessLabelBs {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return 'Potrebna dorada';
      case NcrNextDispositionAction.scheduleRecheck:
        return 'Zakaži ponovnu kontrolu';
      case NcrNextDispositionAction.stopProduction:
        return 'Zaustavi proizvodnju';
    }
  }

  String get meaningBs {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return 'Pokrenuti potrebu za doradom.';
      case NcrNextDispositionAction.scheduleRecheck:
        return 'Zakazati ponovnu kontrolu kvaliteta.';
      case NcrNextDispositionAction.stopProduction:
        return 'Zaustaviti nastavak proizvodnje.';
    }
  }

  /// Objašnjenje postupka za info ikonicu uz naslov dijaloga.
  String processHelpBs(NcrDispositionFlowPhase phase) {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        if (phase == NcrDispositionFlowPhase.assignReworkExecutor) {
          return 'Menadžer proizvodnje dodjeljuje izvršioca dorade '
              '(operater proizvodnje ili vođa smjene / linije) '
              'i određuje proizvodni rok.';
        }
        return 'Kontrola kvaliteta pokreće potrebu za doradom. '
            'Odgovorni vlasnik je menadžer proizvodnje. '
            'On organizuje doradu, dodjeljuje izvršioca i određuje proizvodni rok.';
      case NcrNextDispositionAction.scheduleRecheck:
        return 'Odgovorna osoba iz kontrole kvaliteta izvršava ponovnu kontrolu '
            'nakon dorade ili dodatne provjere.';
      case NcrNextDispositionAction.stopProduction:
        return 'Odgovorna uloga zaustavlja nastavak proizvodnje dok se '
            'odluka o neusaglašenosti ne zatvori.';
    }
  }

  String get taskTemplateBs {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return NcrQmsResponsibilityMatrix.reworkOwnerTaskBs;
      case NcrNextDispositionAction.scheduleRecheck:
        return 'Izvršiti ponovnu kontrolu nakon dorade ili dodatne provjere.';
      case NcrNextDispositionAction.stopProduction:
        return 'Zaustaviti nastavak proizvodnje dok se odluka o neusaglašenosti '
            'ne zatvori.';
    }
  }

  String get priorityBs => NcrNextDispositionCatalog.priorityHighBs;

  String get priorityKey => NcrNextDispositionCatalog.priorityHighKey;

  List<NcrDispositionRoleOption> get roleOptions =>
      NcrQmsResponsibilityMatrix.rolesForActionKey(key);

  IconData get icon {
    switch (this) {
      case NcrNextDispositionAction.sendToRework:
        return Icons.build_circle_outlined;
      case NcrNextDispositionAction.scheduleRecheck:
        return Icons.fact_check_outlined;
      case NcrNextDispositionAction.stopProduction:
        return Icons.stop_circle_outlined;
    }
  }
}

abstract final class NcrNextDispositionCatalog {
  static const priorityHighKey = 'high';
  static const priorityHighBs = 'Visok';

  static const firstPieceActions = <NcrNextDispositionAction>[
    NcrNextDispositionAction.sendToRework,
    NcrNextDispositionAction.scheduleRecheck,
    NcrNextDispositionAction.stopProduction,
  ];

  static NcrNextDispositionAction? fromKey(String? raw) {
    final k = (raw ?? '').trim().toLowerCase();
    for (final a in NcrNextDispositionAction.values) {
      if (a.key == k) return a;
    }
    return null;
  }

  static String labelForKey(String? raw) {
    final a = fromKey(raw);
    if (a == null) return (raw ?? '').trim();
    return a.businessLabelBs;
  }

  static String priorityLabelBs(String? raw) {
    final k = (raw ?? '').trim().toLowerCase();
    if (k.isEmpty || k == priorityHighKey) return priorityHighBs;
    return (raw ?? '').trim();
  }

  static List<NcrNextDispositionAction> actionsForProfile(String? profileKey) {
    final pk = (profileKey ?? '').trim().toLowerCase();
    switch (pk) {
      case 'final_control':
      case 'in_process_quality_check':
      case 'packaging_control':
      case 'first_piece_approval':
      case '':
        return firstPieceActions;
      default:
        return firstPieceActions;
    }
  }

  static String composeReason({
    required String taskTemplate,
    required String optionalNote,
  }) {
    final task = taskTemplate.trim();
    final note = optionalNote.trim();
    if (note.isEmpty) return task;
    return '$task\n\nNapomena: $note';
  }
}
