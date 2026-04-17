import 'package:flutter/material.dart';

import '../models/production_operator_tracking_entry.dart';
import 'production_operator_tracking_station_screen.dart';

/// **Stanica 1 — samo pripremna faza** (puni zaslon): traka sesije + unos pripreme.
///
/// Namjena: centralni PC na podu s jasnim audit kontekstom i placeholderom za QR prijavu.
/// Ostale faze i dalje koriste [ProductionOperatorTrackingStationScreen] s odgovarajućim [phase].
class ProductionPreparationStationScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  /// Vidi [ProductionOperatorTrackingStationScreen.onCloseStation].
  final VoidCallback? onCloseStation;

  /// Vidi [ProductionOperatorTrackingStationScreen.onStationTrackingSetupSaved].
  final VoidCallback? onStationTrackingSetupSaved;

  const ProductionPreparationStationScreen({
    super.key,
    required this.companyData,
    this.onCloseStation,
    this.onStationTrackingSetupSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionOperatorTrackingStationScreen(
      companyData: companyData,
      phase: ProductionOperatorTrackingEntry.phasePreparation,
      showOperativeSessionStrip: true,
      onCloseStation: onCloseStation,
      onStationTrackingSetupSaved: onStationTrackingSetupSaved,
    );
  }
}
