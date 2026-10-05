import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/operonix_premium_icon.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import '../../production_orders/models/production_order_model.dart';
import '../planning_order_pool_view_mode.dart';
import '../planning_session_controller.dart';
import '../services/planning_engine_service.dart';
import '../services/planning_pool_view_prefs.dart';
import 'planning_help_icon.dart';
import 'planning_order_card.dart';
import 'planning_order_display_helpers.dart';

/// Panel liste naloga za planiranje: pretraga, gumbi odabira, prikaz tablice ili kartica.
class PlanningOrderPoolTable extends StatefulWidget {
  const PlanningOrderPoolTable({super.key, required this.session});

  final PlanningSessionController session;

  @override
  State<PlanningOrderPoolTable> createState() => _PlanningOrderPoolTableState();
}

class _PlanningOrderPoolTableState extends State<PlanningOrderPoolTable> {
  PlanningOrderPoolViewMode _view = PlanningOrderPoolViewMode.table;

  PlanningSessionController get session => widget.session;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedView());
  }

  Future<void> _loadSavedView() async {
    final m = await PlanningPoolViewPrefs.read(
      session.companyId,
      session.plantKey,
    );
    if (!mounted || m == null) return;
    setState(() => _view = m);
  }

  Future<void> _persistView(PlanningOrderPoolViewMode m) async {
    await PlanningPoolViewPrefs.write(session.companyId, session.plantKey, m);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(4),
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final chrome = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Nalozi za planiranje',
                                style: t.textTheme.titleSmall,
                              ),
                            ),
                            PlanningHelpIcon(
                              title: PlanningHelpTexts.ordersPanelTitle,
                              message: PlanningHelpTexts.ordersPanelMessage,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Označite naloge za plan. Zatim „Generiši plan” ili „Preračunaj” — raspored je na tabu Raspored. '
                          'Desno su filtri i parametri motora; kontekst i spremanje u bočnoj traci (ikonica ili široki prikaz).',
                          maxLines: constraints.maxWidth < 560 ? 3 : null,
                          overflow: constraints.maxWidth < 560
                              ? TextOverflow.ellipsis
                              : null,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                    final viewToggle =
                        SegmentedButton<PlanningOrderPoolViewMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: PlanningOrderPoolViewMode.table,
                              label: Text('Tablica'),
                              icon: Icon(Icons.table_rows, size: 18),
                            ),
                            ButtonSegment(
                              value: PlanningOrderPoolViewMode.cards,
                              label: Text('Kartice'),
                              icon: Icon(Icons.view_agenda_outlined, size: 18),
                            ),
                          ],
                          selected: {_view},
                          onSelectionChanged: (s) async {
                            if (s.isEmpty) return;
                            final next = s.first;
                            setState(() => _view = next);
                            await _persistView(next);
                          },
                        );
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleBlock,
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: viewToggle,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 8),
                        viewToggle,
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Pretraga (šifra, proizvod…)',
                  ),
                  onChanged: session.setSearchQuery,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: session.isLocked
                        ? null
                        : session.selectAllInPool,
                    child: const Text('Sve'),
                  ),
                  TextButton(
                    onPressed:
                        session.isLocked || session.searchQuery.trim().isEmpty
                        ? null
                        : session.selectFiltered,
                    child: const Text('+ filtrirane'),
                  ),
                  TextButton(
                    onPressed:
                        session.isLocked || session.searchQuery.trim().isEmpty
                        ? null
                        : session.clearFilteredFromSelection,
                    child: const Text('− filtrirane'),
                  ),
                  TextButton(
                    onPressed: session.isLocked ? null : session.clearSelection,
                    child: const Text('Očisti odabir'),
                  ),
                ],
              ),
              Text(
                'Maks. ${PlanningEngineService.maxOrdersPerRun} naloga; isključeni ne ulaze u odabir.',
                style: t.textTheme.labelSmall,
              ),
            ],
          );
          Widget body({required bool grow}) {
            if (session.loadingPool) {
              const indicator = SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
              if (grow) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: indicator,
                );
              }
              return const Center(child: indicator);
            }
            if (session.poolError != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(session.poolError!, textAlign: TextAlign.center),
              );
            }
            if (session.pool.isEmpty) {
              return _emptyPool(context);
            }
            if (_view == PlanningOrderPoolViewMode.table) {
              return _OrderDataTable(session: session, growVertically: grow);
            }
            return _OrderCardList(session: session, growVertically: grow);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (!constraints.hasBoundedHeight) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [chrome, body(grow: true)],
                );
              }
              final tight = constraints.maxHeight < 520;
              if (!tight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chrome,
                    Expanded(child: body(grow: false)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: SingleChildScrollView(child: chrome)),
                  Expanded(flex: 2, child: body(grow: false)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyPool(BuildContext context) {
    const message =
        'Nema naloga u statusima „Pušten” i „U toku” za ovaj pogon.';
    if (!OperonixVisualTokens.of(context).isPremium) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Text(message, textAlign: TextAlign.center),
      );
    }
    return const PremiumEmptyState(
      icon: Icons.assignment_outlined,
      glyph: OperonixPremiumGlyph.productionOrder,
      role: PremiumIconRole.info,
      title: message,
    );
  }
}

class _OrderDataTable extends StatelessWidget {
  const _OrderDataTable({required this.session, required this.growVertically});

  final PlanningSessionController session;
  final bool growVertically;

  @override
  Widget build(BuildContext context) {
    final list = session.ordersForTable;
    final table = DataTable(
      headingRowHeight: 40,
      dataRowMinHeight: 40,
      columns: const [
        DataColumn(label: Text('')),
        DataColumn(label: Text('Nalog')),
        DataColumn(
          label: Text('Signali'),
          tooltip: 'Stroj, rok — isto kao lijevi rub (zeleno/žuto/crveno).',
        ),
        DataColumn(label: Text('Proizvod')),
        DataColumn(label: Text('Kol.')),
        DataColumn(label: Text('Rok')),
        DataColumn(label: Text('Kupac')),
        DataColumn(label: Text('Routing')),
        DataColumn(label: Text('Izv. stroj')),
        DataColumn(label: Text('Akcije')),
      ],
      rows: list.map((o) => _dataRow(context, session, o)).toList(),
    );
    final horizontal = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
    if (growVertically) return horizontal;
    return SingleChildScrollView(child: horizontal);
  }
}

class _OrderCardList extends StatelessWidget {
  const _OrderCardList({required this.session, required this.growVertically});

  final PlanningSessionController session;
  final bool growVertically;

  @override
  Widget build(BuildContext context) {
    final list = session.ordersForTable;
    return ListView.builder(
      shrinkWrap: growVertically,
      physics: growVertically ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      itemCount: list.length,
      itemBuilder: (context, i) {
        return PlanningOrderCard(order: list[i], session: session);
      },
    );
  }
}

DataRow _dataRow(
  BuildContext context,
  PlanningSessionController session,
  ProductionOrderModel o,
) {
  final t = Theme.of(context);
  final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
  final rem = (o.plannedQty - o.producedGoodQty).clamp(0, double.infinity);
  final due = o.requestedDeliveryDate;
  final ex = session.excludedOrderIds.contains(o.id);
  final exStyle = ex ? planningOrderExcludedStyle(t) : null;
  return DataRow(
    selected: !ex && session.selectedOrder?.id == o.id,
    onSelectChanged: ex || session.isLocked
        ? null
        : (v) {
            session.setSelectedOrder(o);
          },
    cells: [
      DataCell(
        Checkbox(
          value: ex ? false : session.selectedOrderIds.contains(o.id),
          onChanged: ex || session.isLocked
              ? null
              : (v) => session.toggleOrderSelected(o.id, v),
        ),
      ),
      DataCell(
        Text(
          o.productionOrderCode,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: exStyle?.color,
            decoration: exStyle?.decoration,
            decorationColor: exStyle?.decorationColor,
          ),
        ),
      ),
      DataCell(planningOrderSignalRow(t, o)),
      DataCell(
        SizedBox(
          width: 120,
          child: Text(
            o.productName,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: exStyle,
          ),
        ),
      ),
      DataCell(
        Text(
          '${rem.toStringAsFixed(rem == rem.roundToDouble() ? 0 : 1)} ${o.unit}',
          style: exStyle,
        ),
      ),
      DataCell(Text(formatPlanningDueDate(due), style: exStyle)),
      DataCell(Text(formatPlanningCustomerLine(o), style: exStyle)),
      DataCell(
        Text(
          o.routingId.isEmpty ? '—' : o.routingId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: exStyle,
        ),
      ),
      DataCell(
        Text(
          ex ? 'isključen' : (hasMachine ? 'da' : 'ne'),
          style: ex
              ? exStyle
              : TextStyle(
                  color: hasMachine ? null : t.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
        ),
      ),
      DataCell(
        PopupMenuButton<String>(
          enabled: !session.isLocked,
          onSelected: (v) {
            if (v == 'ex') {
              session.excludeFromPlan(o.id);
            } else if (v == 'in') {
              session.includeInPlan(o.id);
            }
          },
          itemBuilder: (c) => [
            if (!ex)
              const PopupMenuItem(
                value: 'ex',
                child: Text('Isključi iz plana'),
              ),
            if (ex)
              const PopupMenuItem(value: 'in', child: Text('Uključi u plan')),
          ],
          child: const Icon(Icons.more_vert, size: 20),
        ),
      ),
    ],
  );
}
