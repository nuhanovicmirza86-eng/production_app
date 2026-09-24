import '../models/profile_driven_evidence_session.dart';
import '../../../modules/production/station_work/models/production_station_work_session.dart';

/// M1-I14-B/C/D — poslovni prikaz routing/order konteksta (bez raw ID).
class EvidenceOrderContextDisplay {
  EvidenceOrderContextDisplay._();

  static const notRecorded = 'Nije evidentirano';
  static const notDefined = 'Nije definisano';

  static String orderCode(ProfileDrivenEvidenceOrderContext? ctx) {
    if (ctx == null || !ctx.hasSnapshot) return notRecorded;
    final code = (ctx.productionOrderCode ?? '').trim();
    return code.isNotEmpty ? code : notRecorded;
  }

  static String productLabel(ProfileDrivenEvidenceOrderContext? ctx) {
    if (ctx == null || !ctx.hasSnapshot) return notRecorded;
    return _productFromParts(ctx.productCode, ctx.productName);
  }

  static String productLabelFromSnapshot(ProductionStationWorkOrderSnapshot snap) {
    return _productFromParts(snap.productCode, snap.productName);
  }

  static String operationLabel(ProfileDrivenEvidenceOrderContext? ctx) {
    if (ctx == null || !ctx.hasSnapshot) return notRecorded;
    final stepLabel = _stepLabel(
      stepOrder: ctx.routingStepOrder,
      operationCode: ctx.routingStepOperationCode,
      operationName: ctx.routingStepOperationName,
    );
    // M1-I14-E — ista semantika kao detalj: bez koraka = Nije evidentirano.
    return stepLabel ?? notRecorded;
  }

  static String operationLabelFromSnapshot(ProductionStationWorkOrderSnapshot snap) {
    final step = snap.routingStep;
    final stepLabel = _stepLabel(
      stepOrder: step?.stepOrder,
      operationCode: step?.operationCode,
      operationName: step?.operationName ?? snap.operationName,
    );
    if (stepLabel != null) return stepLabel;
    return _routingFromParts(
      routingId: snap.routingId,
      routingVersion: snap.routingVersion,
      operationName: snap.operationName,
      emptyFallback: notDefined,
    );
  }

  /// M1-I14-D — Proizvodni kontekst: Korak N · naziv, inače „Nije evidentirano”.
  static String operationStepLabelForEvidenceDetail(
    ProductionStationWorkOrderSnapshot? snap,
  ) {
    if (snap == null) return notRecorded;
    final step = snap.routingStep;
    final stepLabel = _stepLabel(
      stepOrder: step?.stepOrder,
      operationCode: step?.operationCode,
      operationName: step?.operationName,
    );
    return stepLabel ?? notRecorded;
  }

  static String workCenterLabel(ProfileDrivenEvidenceOrderContext? ctx) {
    if (ctx == null || !ctx.hasSnapshot) return notRecorded;
    return _workCenterFromParts(ctx.workCenterCode, ctx.workCenterName) ??
        notRecorded;
  }

  static String? workCenterLabelFromSnapshot(
    ProductionStationWorkOrderSnapshot snap,
  ) {
    final fromOrder =
        _workCenterFromParts(snap.workCenterCode, snap.workCenterName);
    if (fromOrder != null) return fromOrder;
    final step = snap.routingStep;
    return _workCenterFromParts(step?.workCenterCode, step?.workCenterName);
  }

  static String bomVersionLabel(ProfileDrivenEvidenceOrderContext? ctx) {
    if (ctx == null || !ctx.hasSnapshot) return notRecorded;
    final version = (ctx.bomVersion ?? '').trim();
    if (version.isEmpty || version == '0') return notRecorded;
    return 'Verzija $version';
  }

  static String? bomVersionLabelFromSnapshot(
    ProductionStationWorkOrderSnapshot snap,
  ) {
    final version = (snap.bomVersion ?? '').trim();
    if (version.isEmpty || version == '0') return null;
    return 'Verzija $version';
  }

  static String _productFromParts(String? codeRaw, String? nameRaw) {
    final code = (codeRaw ?? '').trim();
    final name = (nameRaw ?? '').trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return notRecorded;
  }

  /// npr. "Korak 3 · Brizganje" — bez raw routingStepId.
  static String? _stepLabel({
    required int? stepOrder,
    required String? operationCode,
    required String? operationName,
  }) {
    final name = (operationName ?? '').trim();
    final code = (operationCode ?? '').trim();
    final op = name.isNotEmpty ? name : code;
    if (stepOrder == null && op.isEmpty) return null;
    final parts = <String>[];
    if (stepOrder != null) parts.add('Korak $stepOrder');
    if (op.isNotEmpty) parts.add(op);
    return parts.join(' · ');
  }

  static String _routingFromParts({
    required String? routingId,
    required String? routingVersion,
    required String? operationName,
    required String emptyFallback,
  }) {
    final version = (routingVersion ?? '').trim();
    final operation = (operationName ?? '').trim();
    final rid = (routingId ?? '').trim().toLowerCase();
    final placeholderId = rid.isEmpty || rid == 'unspecified';
    final placeholderVersion = version.isEmpty || version == '0';
    if (placeholderId && placeholderVersion && operation.isEmpty) {
      return emptyFallback;
    }
    final parts = <String>[];
    if (!placeholderVersion) parts.add(version);
    if (operation.isNotEmpty) parts.add(operation);
    if (parts.isEmpty) return emptyFallback;
    return parts.join(' · ');
  }

  static String? _workCenterFromParts(String? codeRaw, String? nameRaw) {
    final code = (codeRaw ?? '').trim();
    final name = (nameRaw ?? '').trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return null;
  }
}
