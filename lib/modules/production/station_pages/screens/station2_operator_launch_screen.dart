import 'package:flutter/material.dart';

import '../../tracking/models/production_operator_tracking_entry.dart';
import '../../tracking/screens/production_operator_tracking_station_screen.dart';

/// Legacy ulaz — Stanica 2 (prva kontrola): puni zaslon s brzim/ručnim unosom.
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
    return ProductionOperatorTrackingStationScreen(
      companyData: companyData,
      phase: ProductionOperatorTrackingEntry.phaseFirstControl,
      onCloseStation: onCloseStation,
      onStationTrackingSetupSaved: onStationTrackingSetupSaved,
    );
  }
}
