import 'package:flutter/material.dart';

import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/services/production_station_page_service.dart';
import '../../tracking/screens/production_preparation_station_screen.dart';
import '../../station_work/screens/station1_work_screen.dart';

/// M2 pilot router: slot 1 + `standard_production` → [Station1WorkScreen], inače legacy pripremna.
class Station1OperatorLaunchScreen extends StatelessWidget {
  const Station1OperatorLaunchScreen({
    super.key,
    required this.companyData,
    this.onCloseStation,
    this.onStationTrackingSetupSaved,
  });

  final Map<String, dynamic> companyData;
  final VoidCallback? onCloseStation;
  final VoidCallback? onStationTrackingSetupSaved;

  @override
  Widget build(BuildContext context) {
    final companyId = (companyData['companyId'] ?? '').toString().trim();
    if (companyId.isEmpty) {
      return ProductionPreparationStationScreen(
        companyData: companyData,
        onCloseStation: onCloseStation,
        onStationTrackingSetupSaved: onStationTrackingSetupSaved,
      );
    }

    return FutureBuilder<ProductionStationConfig?>(
      future: ProductionStationPageService().getConfigBySlot(
        companyId: companyId,
        stationSlot: 1,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final config = snap.data;
        final useM2Pilot = config != null &&
            config.active &&
            config.stationSlot == 1 &&
            config.processProfileType == 'standard_production';

        if (useM2Pilot) {
          return Station1WorkScreen(
            companyData: companyData,
            stationConfig: config,
            onCloseStation: onCloseStation,
          );
        }

        return ProductionPreparationStationScreen(
          companyData: companyData,
          onCloseStation: onCloseStation,
          onStationTrackingSetupSaved: onStationTrackingSetupSaved,
        );
      },
    );
  }
}
