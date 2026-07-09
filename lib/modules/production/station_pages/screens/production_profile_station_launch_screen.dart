import 'package:flutter/material.dart';

import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_profile_catalog_entry.dart';
import '../../station_work/screens/profile_driven_work_screen.dart';

/// M1-B — operator ulaz u profile-driven runtime (npr. `chemical_dosing`).
class ProductionProfileStationLaunchScreen extends StatelessWidget {
  const ProductionProfileStationLaunchScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    required this.profile,
    this.onCloseStation,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationConfig stationConfig;
  final ProductionStationProfileCatalogEntry profile;
  final VoidCallback? onCloseStation;

  @override
  Widget build(BuildContext context) {
    if (!stationConfig.active) {
      return Scaffold(
        appBar: AppBar(title: Text(stationConfig.title)),
        body: const Center(
          child: Text('Stanica nije aktivna. Kontaktirajte administratora.'),
        ),
      );
    }

    if (profile.profileKey != stationConfig.processProfileType) {
      return Scaffold(
        appBar: AppBar(title: Text(stationConfig.title)),
        body: const Center(
          child: Text('Profil stanice nije podržan u operator runtime-u.'),
        ),
      );
    }

    if (profile.profileKey == 'chemical_dosing' && profile.isComplete) {
      return ProfileDrivenWorkScreen(
        companyData: companyData,
        stationConfig: stationConfig,
        profile: profile,
        onCloseStation: onCloseStation,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(stationConfig.title)),
      body: Center(
        child: Text(
          'Profil ${profile.displayName} još nije spreman za operator unos.',
        ),
      ),
    );
  }
}
