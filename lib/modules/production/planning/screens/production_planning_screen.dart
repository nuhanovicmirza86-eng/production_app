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
              Expanded(
                flex: 44,
                child: PlanningOrderPoolTable(session: session),
              ),
              Expanded(
                flex: 28,
                child: _filtersAndParams(context, session, fill: true),
              ),
              Expanded(flex: 28, child: _precheck(session, fill: true)),
            ],
          );
        }
        final bottom = MediaQuery.viewPaddingOf(context).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanningOrderPoolTable(session: session),
              const SizedBox(height: 8),
              _filtersAndParams(context, session, fill: false),
              const SizedBox(height: 8),
              _precheck(session, fill: false),
            ],
          ),
        );
      },
    );
  }

  Widget _filtersAndParams(
    BuildContext context,
    PlanningSessionController session, {
    required bool fill,
  }) {
    final children = <Widget>[
      PlanningFiltersBar(session: session),
      const SizedBox(height: 10),
      PlanningSummaryKpiRow(session: session),
      const Divider(height: 20),
      PlanningEngineParamsFields(session: session),
    ];
    return Card(
      margin: const EdgeInsets.all(4),
      child: fill
          ? ListView(padding: const EdgeInsets.all(10), children: children)
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
    );
  }

  Widget _precheck(PlanningSessionController session, {required bool fill}) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: PlanningPrecheckPanel(session: session, fill: fill),
    );
  }
}
