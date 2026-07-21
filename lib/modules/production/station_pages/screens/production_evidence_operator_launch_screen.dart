import 'package:flutter/material.dart';

import '../../station_pages/models/production_evidence_config.dart';
import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_profile_catalog_entry.dart';
import '../../station_work/screens/profile_driven_work_screen.dart';
import '../../../../features/catalog_evidence_runtime/screens/catalog_evidence_station_screen.dart';

/// M1-H3 — operator ulaz u company evidence runtime.
class ProductionEvidenceOperatorLaunchScreen extends StatelessWidget {
  const ProductionEvidenceOperatorLaunchScreen({
    super.key,
    required this.companyData,
    required this.evidenceConfig,
    required this.profile,
    this.onClose,
  });

  final Map<String, dynamic> companyData;
  final ProductionEvidenceConfig evidenceConfig;
  final ProductionStationProfileCatalogEntry profile;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (!evidenceConfig.active || evidenceConfig.isArchived) {
      return Scaffold(
        appBar: AppBar(title: Text(evidenceConfig.displayName)),
        body: const Center(
          child: Text('Evidencija nije aktivna. Kontaktirajte administratora.'),
        ),
      );
    }

    if (profile.profileKey != evidenceConfig.profileKey) {
      return Scaffold(
        appBar: AppBar(title: Text(evidenceConfig.displayName)),
        body: const Center(
          child: Text('Profil evidencije nije podržan u operator runtime-u.'),
        ),
      );
    }

    if (ProductionStationConfig.isCatalogEvidenceRuntimeProfile(
          profile.profileKey,
        ) &&
        profile.isComplete) {
      return CatalogEvidenceStationScreen.companyEvidence(
        companyData: companyData,
        evidenceConfig: evidenceConfig,
        profile: profile,
        onCloseStation: onClose,
      );
    }

    if (ProductionStationConfig.isProfileDrivenRuntimeProfile(
          profile.profileKey,
        ) &&
        profile.isComplete) {
      return ProfileDrivenWorkScreen.companyEvidence(
        companyData: companyData,
        evidenceConfig: evidenceConfig,
        profile: profile,
        onCloseStation: onClose,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(evidenceConfig.displayName)),
      body: Center(
        child: Text(
          'Profil ${profile.displayName} još nije spreman za operator unos.',
        ),
      ),
    );
  }
}
