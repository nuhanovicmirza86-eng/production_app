import 'package:cloud_functions/cloud_functions.dart';

import '../models/operonix_ai_feedback_signals_snapshot.dart';

/// AI-M2-G2/G4 — submit + list kontrolisanog feedbacka (D4 Callables).
///
/// Šalje/čita samo metapodatke i agregate.
/// Ne šalje i ne prikazuje prompt, payload ni cijeli AI odgovor.
class ProductionAiAssistantFeedbackService {
  ProductionAiAssistantFeedbackService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Kanonske D4 ocjene (UI „positive/negative” mapira ovdje).
  static const String ratingHelpful = 'helpful';
  static const String ratingNotHelpful = 'not_helpful';

  /// D4 reasonCode — mapirani na premium BCS opcije u UI.
  static const String reasonClearAndUseful = 'clear_and_useful';
  static const String reasonNotActionable = 'not_actionable';
  static const String reasonIncomplete = 'incomplete';
  static const String reasonWrongFacts = 'wrong_facts';
  static const String reasonOther = 'other';

  static const String confirmationNote =
      'Hvala. Povratna informacija je zabilježena.';

  static const Set<String> allowedContracts = {
    'aiChat',
    'getOperonixAiOperationalContext',
    'aiGetEvidenceSessionContext',
    'aiGetProductionOrderContext',
    'aiGetMachineRiskContext',
    'aiGetWorkerFitContext',
    'aiGetNcrContext',
    'aiGetMaterialLotRiskContext',
    'aiGetRoutingContext',
    'explainNcrActionRiskSignals',
    'aiChat_operational_context',
  };

  static String resolveContract(String? raw) {
    final v = (raw ?? 'aiChat').trim();
    if (v.isEmpty) return 'aiChat';
    if (allowedContracts.contains(v)) return v;
    return 'aiChat';
  }

  Future<String> submit({
    required String companyId,
    required String rating,
    required String reasonCode,
    String? comment,
    String? module,
    String? contract,
    String? plantKey,
    String? plantDisplayName,
    String? periodFrom,
    String? periodTo,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke za povratnu informaciju.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'rating': rating,
      'reasonCode': reasonCode,
      'assistantSurface': 'chat',
      'module': (module ?? 'production').trim().isEmpty
          ? 'production'
          : module!.trim(),
      'contract': resolveContract(contract),
    };

    final c = comment?.trim();
    if (c != null && c.isNotEmpty) {
      payload['comment'] = c;
    }
    final pk = plantKey?.trim();
    if (pk != null && pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }
    final pd = plantDisplayName?.trim();
    if (pd != null && pd.isNotEmpty) {
      payload['plantDisplayName'] = pd;
    }
    final from = periodFrom?.trim();
    if (from != null && from.isNotEmpty) {
      payload['periodFrom'] = from;
    }
    final to = periodTo?.trim();
    if (to != null && to.isNotEmpty) {
      payload['periodTo'] = to;
    }

    final callable = _functions.httpsCallable('aiSubmitAssistantFeedback');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    if (data['success'] != true && data['accepted'] != true) {
      throw StateError('Povratna informacija nije zabilježena.');
    }
    final note = (data['note'] ?? '').toString().trim();
    if (note.isNotEmpty) {
      // Preferiraj kratku G2 potvrdu u UI; backend note ostaje D4 (ne diramo freeze).
      return confirmationNote;
    }
    return confirmationNote;
  }

  /// AI-M2-G4 — agregirani signali (read-only).
  Future<OperonixAiFeedbackSignalsSnapshot> listSignals({
    required String companyId,
    String? dateFrom,
    String? dateTo,
    String? plantKey,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      throw StateError('Nedostaje kontekst tvrtke za pregled signala.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
    };
    final from = dateFrom?.trim();
    if (from != null && from.isNotEmpty) {
      payload['dateFrom'] = from;
    }
    final to = dateTo?.trim();
    if (to != null && to.isNotEmpty) {
      payload['dateTo'] = to;
    }
    final pk = plantKey?.trim();
    if (pk != null && pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }

    final callable = _functions.httpsCallable('aiListAssistantFeedbackSignals');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    return OperonixAiFeedbackSignalsSnapshot.fromMap(
      Map<String, dynamic>.from(raw.data),
    );
  }
}
