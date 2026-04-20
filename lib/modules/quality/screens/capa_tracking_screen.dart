import 'package:flutter/material.dart';

/// CAPA prati action_plans gdje je sourceType = non_conformance.
class CapaTrackingScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const CapaTrackingScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CAPA — praćenje')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Korektivne i preventivne akcije vezane za NCR (action_plans). Filtri: rok, odgovoran, status.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
