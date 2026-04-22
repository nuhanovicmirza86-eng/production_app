import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../planning_session_controller.dart';

/// Polja parametra FCS motora: performansa, setup, ciklus.
class PlanningEngineParamsFields extends StatelessWidget {
  const PlanningEngineParamsFields({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Parametri motora', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: session.perfController,
          enabled: !session.isLocked,
          decoration: const InputDecoration(
            labelText: 'Performansa (0–1)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: session.setupController,
          enabled: !session.isLocked,
          decoration: const InputDecoration(
            labelText: 'Setup (min)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: session.cycleController,
          enabled: !session.isLocked,
          decoration: const InputDecoration(
            labelText: 'Ciklus (s/kom) kad nema routingsa',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
