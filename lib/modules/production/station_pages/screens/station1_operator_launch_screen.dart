import 'package:flutter/material.dart';

import '../../tracking/screens/production_preparation_station_screen.dart';

/// Legacy ulaz — Stanica 1 (pripremna): puni zaslon s brzim/ručnim unosom.
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
    return ProductionPreparationStationScreen(
      companyData: companyData,
      onCloseStation: onCloseStation,
      onStationTrackingSetupSaved: onStationTrackingSetupSaved,
    );
  }
}
