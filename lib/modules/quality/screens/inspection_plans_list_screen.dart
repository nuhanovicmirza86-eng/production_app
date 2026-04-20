import 'package:flutter/material.dart';

class InspectionPlansListScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const InspectionPlansListScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planovi inspekcije')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Povezivanje kontrolnog plana s tipom kontrole (INCOMING / IN_PROCESS / FINAL). '
            'Kolekcija inspection_plans.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
