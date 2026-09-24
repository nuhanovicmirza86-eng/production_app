import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../profile_driven_structured_runtime/utils/structured_datetime_value.dart';
import '../../station_evidence/models/profile_driven_evidence_session.dart';
import 'evidence_input_empty.dart';
import 'line_clearance_line_name.dart';

/// M1-I15-D-HOTFIX-27 — jednostavna verifikacija čišćenja mašine / linije.
const String lineClearanceProfileKey = 'line_clearance';
const String lineClearanceChangeoverType = 'product_changeover_clean';

const String lineClearanceSiteConditionCheckedKey = 'siteConditionChecked';
const String lineClearanceReadyForWorkKey = 'readyForWork';
const String lineClearanceReadinessCorrectionKey = 'readinessCorrection';

const String lineClearanceSiteConditionCheckedLabel =
    'Stanje provjereno na terenu';
const String lineClearanceReadyForWorkLabel = 'Spremno za rad';
const String lineClearanceReadinessCorrectionLabel =
    'Razlog / potrebna korekcija';
const String lineClearanceSiteVerificationTitle = 'Provjera na terenu';
const String lineClearancePlaceLabel = 'Mjesto';
const String lineClearanceChecklistLabel = 'Lista potvrđena';
const String lineClearanceShiftLabel = 'Smjena';
const String lineClearanceTypeLabel = 'Tip čišćenja';
const String lineClearanceStartLabel = 'Početak';
const String lineClearanceEndLabel = 'Kraj';
const String lineClearancePerformedByLabel = 'Izvršio';
const String lineClearanceOperatorCommentLabel = 'Komentar';

const String lineClearanceSiteCheckHelper =
    'Nadređeni fizički pogleda stanje na terenu i potvrdi da odgovara '
    'onome što je operater evidentirao.';

const Set<String> lineClearanceVerifierInputKeys = {
  lineClearanceSiteConditionCheckedKey,
  lineClearanceReadyForWorkKey,
  lineClearanceReadinessCorrectionKey,
};

const Set<String> lineClearanceHiddenOrderFieldKeys = {
  'productionOrderId',
  'productionOrderCode',
};

bool isLineClearanceProductChangeover(String? clearanceType) {
  return sanitizeEvidenceFormInput(clearanceType) ==
      lineClearanceChangeoverType;
}

bool? parseEvidenceYesNo(dynamic raw) {
  if (raw == true || raw == 'true' || raw == 1 || raw == '1') return true;
  if (raw == false || raw == 'false' || raw == 0 || raw == '0') return false;
  return null;
}

String formatEvidenceYesNo(dynamic raw) {
  final value = parseEvidenceYesNo(raw);
  if (value == true) return 'DA';
  if (value == false) return 'NE';
  return '';
}

String formatEvidenceYesNoOrDash(dynamic raw) {
  final value = formatEvidenceYesNo(raw);
  return value.isEmpty ? '—' : value;
}

bool _isPresentableBusinessCode(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t == '—' || t == '-') return false;
  if (RegExp(r'^PLANT_\d+$', caseSensitive: false).hasMatch(t)) return false;
  if (t.contains('@')) return false;
  if (t.length >= 16 &&
      t.length <= 32 &&
      !t.contains('-') &&
      !t.contains('_') &&
      !t.contains(' ') &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(t)) {
    return false;
  }
  return true;
}

String _humanNameFromLabel(String? label) {
  final text = sanitizeEvidenceFormInput(label);
  if (text.isEmpty) return '';
  const sep = ' — ';
  if (text.contains(sep)) {
    final name = text.split(sep).skip(1).join(sep).trim();
    if (name.isNotEmpty) return name;
  }
  return text;
}

String lineClearanceVerifiedPlaceLabel({
  required Map<String, dynamic> fieldValues,
  StructuredEntitySelection? workCenter,
  StructuredEntitySelection? machine,
}) {
  final code = sanitizeEvidenceFormInput(
    (workCenter?.raw['code'] ??
            workCenter?.raw['workCenterCode'] ??
            fieldValues['workCenterCodeSnapshot'] ??
            '')
        .toString(),
  );
  final presentableCode =
      _isPresentableBusinessCode(code) ? code : '';

  var lineName = lineClearanceLineNameFromWorkCenter(
    raw: workCenter?.raw,
    displayLabel: workCenter?.displayLabel,
  );
  if (lineName.isEmpty) {
    lineName = sanitizeEvidenceFormInput(
      (fieldValues['workCenterNameSnapshot'] ??
              fieldValues['lineName'] ??
              '')
          .toString(),
    );
  }
  if (lineName.isEmpty) {
    lineName = _humanNameFromLabel(workCenter?.displayLabel);
  }

  var machineName = sanitizeEvidenceFormInput(
    (machine?.raw['displayName'] ??
            machine?.raw['machineName'] ??
            fieldValues['machineNameSnapshot'] ??
            '')
        .toString(),
  );
  if (machineName.isEmpty) {
    machineName = _humanNameFromLabel(machine?.displayLabel);
  }

  if (presentableCode.isNotEmpty &&
      lineName.isNotEmpty &&
      machineName.isNotEmpty) {
    return '$presentableCode — $lineName / $machineName';
  }
  if (presentableCode.isNotEmpty && lineName.isNotEmpty) {
    return '$presentableCode — $lineName';
  }
  if (lineName.isNotEmpty && machineName.isNotEmpty) {
    return '$lineName / $machineName';
  }
  if (presentableCode.isNotEmpty && machineName.isNotEmpty) {
    return '$presentableCode / $machineName';
  }
  if (lineName.isNotEmpty) return lineName;
  if (machineName.isNotEmpty) return machineName;
  if (presentableCode.isNotEmpty) return presentableCode;
  return '';
}

String lineClearanceDateTimeLabel(dynamic raw) {
  return formatEvidenceDateTime(StructuredDateTimeValue.parse(raw));
}

String? lineClearanceSiteVerificationFinishMessage(
  Map<String, dynamic> fieldValues,
) {
  if (parseEvidenceYesNo(fieldValues[lineClearanceSiteConditionCheckedKey]) !=
      true) {
    return 'Potvrdite da je stanje provjereno na terenu.';
  }
  final ready = parseEvidenceYesNo(fieldValues[lineClearanceReadyForWorkKey]);
  if (ready == null) {
    return 'Odaberite je li linija / mašina spremna za rad.';
  }
  if (ready == false &&
      sanitizeEvidenceFormInput(
            (fieldValues[lineClearanceReadinessCorrectionKey] ?? '').toString(),
          )
          .isEmpty) {
    return 'Unesite razlog / potrebnu korekciju jer linija / mašina nije spremna za rad.';
  }
  return null;
}
