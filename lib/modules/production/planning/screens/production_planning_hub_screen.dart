import 'package:flutter/material.dart';

import 'production_planning_home_screen.dart';

/// Zastarjeli alias: cijeli tok je u [ProductionPlanningHomeScreen].
@Deprecated('Koristite ProductionPlanningHomeScreen (dashboard već vodi ovdje).')
class ProductionPlanningHubScreen extends StatelessWidget {
  const ProductionPlanningHubScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return ProductionPlanningHomeScreen(companyData: companyData);
  }
}
