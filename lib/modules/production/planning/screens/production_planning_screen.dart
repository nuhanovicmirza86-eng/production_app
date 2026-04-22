import 'package:flutter/material.dart';

import 'production_planning_hub_screen.dart';

/// Ulaz u planiranje (FCS). Sva logika i UI s komandnom trakom, tri panela i donjim tabovima
/// u [ProductionPlanningHubScreen].
///
/// [asHubTab] se zanemaruje; zadržan radi kompatibilnosti s ranijim kôdom.
class ProductionPlanningScreen extends StatelessWidget {
  const ProductionPlanningScreen({
    super.key,
    required this.companyData,
    this.asHubTab = false,
  });

  final Map<String, dynamic> companyData;

  @Deprecated('Hub je samostalan; nema ugnježđenog child Scaffold.')
  final bool asHubTab;

  @override
  Widget build(BuildContext context) {
    return ProductionPlanningHubScreen(companyData: companyData);
  }
}
