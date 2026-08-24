/// M1-I6 — client mirror of evidence outcome action map (containment gate).
class EvidenceOutcomeActionHelper {
  EvidenceOutcomeActionHelper._();

  static const Map<String, Set<String>> _triggers = {
    'first_piece_approval': {'rejected', 'approved_with_deviation'},
    'in_process_quality_check': {'fail', 'conditional_pass'},
    'final_control': {'recheck_required', 'rework_required', 'blocked'},
    'packaging_control': {'hold', 'rework_packaging'},
  };

  static const Map<String, String> _outcomeFields = {
    'first_piece_approval': 'firstPieceDisposition',
    'in_process_quality_check': 'inspectionOutcome',
    'final_control': 'finalDisposition',
    'packaging_control': 'packagingDisposition',
  };

  static String? outcomeFieldForProfile(String profileKey) =>
      _outcomeFields[profileKey.trim().toLowerCase()];

  static bool requiresAction({
    required String profileKey,
    required Map<String, dynamic> fieldValues,
  }) {
    final pk = profileKey.trim().toLowerCase();
    final field = _outcomeFields[pk];
    final triggers = _triggers[pk];
    if (field == null || triggers == null) return false;
    final outcome = (fieldValues[field] ?? '').toString().trim();
    return outcome.isNotEmpty && triggers.contains(outcome);
  }

  static String? outcomeLabel({
    required String profileKey,
    required Map<String, dynamic> fieldValues,
  }) {
    final pk = profileKey.trim().toLowerCase();
    final field = _outcomeFields[pk];
    if (field == null) return null;
    final outcome = (fieldValues[field] ?? '').toString().trim();
    if (outcome.isEmpty) return null;
    const labels = <String, String>{
      'rejected': 'Odbijeno',
      'approved_with_deviation': 'Odobreno s odstupanjem',
      'fail': 'Ne prolazi',
      'conditional_pass': 'Uslovno prolazi',
      'recheck_required': 'Potrebna ponovna kontrola',
      'rework_required': 'Potrebna dorada',
      'blocked': 'Blokirano',
      'hold': 'Zadržano',
      'rework_packaging': 'Dorada pakovanja',
    };
    return labels[outcome] ?? outcome;
  }
}
