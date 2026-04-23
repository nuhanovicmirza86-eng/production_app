import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/planning_schedule_strategy.dart';
import '../planning_session_controller.dart';

/// Polja parametra FCS motora: performansa, setup, ciklus.
class PlanningEngineParamsFields extends StatelessWidget {
  const PlanningEngineParamsFields({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Parametri motora', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          'Strategija reda naloga (F4)',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PlanningScheduleStrategy>(
              value: session.scheduleStrategy,
              isExpanded: true,
              isDense: true,
              items: [
                for (final e in PlanningScheduleStrategy.values)
                  DropdownMenuItem(
                    value: e,
                    child: Text(e.labelHr, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: session.isLocked
                  ? null
                  : (v) {
                      if (v == null) {
                        return;
                      }
                      session.setScheduleStrategy(v);
                    },
            ),
          ),
        ),
        const SizedBox(height: 8),
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
      },
    );
  }
}
