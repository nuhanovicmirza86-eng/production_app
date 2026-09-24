import '../../../core/access/production_access_helper.dart';

/// M1-I15-C — kanonske `roleKeys` za person polja evidencije (usklađeno s I15-B backend mapom).
///
/// Polja s labelom **„Operater kvaliteta”** (`controllerEmployeeId`, `inspectorEmployeeId`)
/// → samo [ProductionAccessHelper.roleQualityOperator].
/// `verifiedByEmployeeId` — katalog default; tenant `verifierRoleKeys` je izvor na runtimeu.
/// 5S default: Menadžer proizvodnje + Vođa smjene / linije (M1-I15-D-HOTFIX-15).
List<String>? controlledEvidenceRoleKeysForPersonField(
  String fieldKey, {
  String? profileKey,
}) {
  final key = fieldKey.trim();
  final profile = (profileKey ?? '').trim();
  switch (key) {
    case 'controllerEmployeeId':
    case 'inspectorEmployeeId':
      return const [ProductionAccessHelper.roleQualityOperator];
    case 'verifiedByEmployeeId':
      if (profile == 'workspace_5s_cleaning') {
        return const [
          ProductionAccessHelper.roleProductionManager,
          ProductionAccessHelper.roleShiftLead,
        ];
      }
      if (profile == 'line_clearance') {
        return const [
          ProductionAccessHelper.roleQualityControl,
          ProductionAccessHelper.roleQualityOperator,
          ProductionAccessHelper.roleProductionManager,
        ];
      }
      return const [
        ProductionAccessHelper.roleQualityControl,
        ProductionAccessHelper.roleQualityOperator,
      ];
    case 'packagingOperatorEmployeeId':
    case 'productionOperatorEmployeeId':
    case 'performedByEmployeeId':
    case 'operatorId':
      return const [ProductionAccessHelper.roleProductionOperator];
    default:
      return null;
  }
}

/// M1-I15-D-HOTFIX-07 — helper ispod polja Proizvodni operater.
const String productionOperatorWorkforceSearchHelper =
    'Pretražite aktivne radnike s funkcijom Operater proizvodnje. '
    'Korisnički nalog nije potreban za proizvodnog operatera.';

const String workspace5sVerifierHelperText =
    'Verifikacija je potpis prijavljenog korisnika s dozvoljenom ulogom iz '
    'postavki evidencije. Nije izbor tuđeg imena.';

const String workspace5sVerifierFieldLabel = 'Verifikovao neposredni rukovodilac';

const String workspace5sPerformedByFieldLabel = 'Izvršio';

const String workspace5sPerformedByHandoffHelper =
    'Radnik koji je popunio i spremio evidenciju. Verifikator ne mijenja ovo ime.';

const String signedEvidenceVerifierDeniedMessage =
    'Verifikacija nije dostupna za vašu ulogu.';

const String workspace5sVerifierDeniedMessage =
    signedEvidenceVerifierDeniedMessage;

String? controlledEvidencePersonHelperText(
  String fieldKey, {
  String? profileKey,
}) {
  final key = fieldKey.trim();
  switch (key) {
    case 'controllerEmployeeId':
    case 'inspectorEmployeeId':
      return 'Samo osobe s ulogom Operater kvaliteta. '
          'Kontrolisani izbor — nije slobodan unos imena.';
    case 'verifiedByEmployeeId':
      return workspace5sVerifierHelperText;
    case 'packagingOperatorEmployeeId':
    case 'performedByEmployeeId':
    case 'operatorId':
      return 'Samo aktivni radnici s ulogom Operater proizvodnje na ovom pogonu. '
          'Nije potreban korisnički nalog. Kontrolisani izbor — nije slobodan unos imena.';
    case 'productionOperatorEmployeeId':
      return productionOperatorWorkforceSearchHelper;
    default:
      return null;
  }
}
