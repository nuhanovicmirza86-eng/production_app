import 'package:flutter/material.dart';

import '../planning_session_controller.dart';
import '../planning_workflow_scope.dart';
import '../widgets/planning_engine_params_fields.dart';
import '../widgets/planning_filters_bar.dart';
import '../widgets/planning_order_pool_table.dart';
import '../widgets/planning_precheck_panel.dart';
import '../widgets/planning_summary_kpi_row.dart';

/// Tab **Nalozi**: pool, filteri (placeholder), pre-check / konflikti, parametri motora.
class ProductionPlanningScreen extends StatelessWidget {
  const ProductionPlanningScreen({super.key});

  static const _wide = 1180.0;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _wide;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 44, child: PlanningOrderPoolTable(session: session)),
              Expanded(flex: 28, child: _filtersAndParams(context, session)),
              Expanded(flex: 28, child: _precheck(session)),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            SizedBox(height: 420, child: PlanningOrderPoolTable(session: session)),
            const Divider(),
            SizedBox(height: 260, child: _filtersAndParams(context, session)),
            const Divider(),
            SizedBox(height: 280, child: _precheck(session)),
          ],
        );
      },
    );
  }

  Widget _filtersAndParams(BuildContext context, PlanningSessionController session) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          PlanningFiltersBar(session: session),
          const SizedBox(height: 10),
          PlanningSummaryKpiRow(session: session),
          const Divider(height: 20),
          PlanningEngineParamsFields(session: session),
        ],
      ),
    );
  }

  Widget _precheck(PlanningSessionController session) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: PlanningPrecheckPanel(
        pool: session.pool,
        result: session.result,
      ),
    );
  }
}
