import 'package:flutter/material.dart';

import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/services/production_station_page_service.dart';
import '../../tracking/screens/production_operator_tracking_station_screen.dart';
import '../../station_work/screens/station2_work_screen.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';

/// M2 pilot router: slot 2 + `standard_production` → [Station2WorkScreen], inače legacy.
class Station2OperatorLaunchScreen extends StatelessWidget {
  const Station2OperatorLaunchScreen({
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
      return ProductionOperatorTrackingStationScreen(
        companyData: companyData,
        phase: ProductionOperatorTrackingEntry.phaseFirstControl,
        onCloseStation: onCloseStation,
        onStationTrackingSetupSaved: onStationTrackingSetupSaved,
      );
    }

    return FutureBuilder<ProductionStationConfig?>(
      future: ProductionStationPageService().getConfigBySlot(
        companyId: companyId,
        stationSlot: 2,
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
            config.stationSlot == 2 &&
            config.processProfileType == 'standard_production' &&
            config.phase == ProductionOperatorTrackingEntry.phaseFirstControl;

        if (useM2Pilot) {
          return Station2WorkScreen(
            companyData: companyData,
            stationConfig: config,
            onCloseStation: onCloseStation,
          );
        }

        return ProductionOperatorTrackingStationScreen(
          companyData: companyData,
          phase: ProductionOperatorTrackingEntry.phaseFirstControl,
          onCloseStation: onCloseStation,
          onStationTrackingSetupSaved: onStationTrackingSetupSaved,
        );
      },
    );
  }
}
