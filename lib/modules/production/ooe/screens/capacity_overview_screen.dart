import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../models/capacity_calendar.dart';
import '../models/utilization_summary.dart';
import '../ooe_help_texts.dart';
import '../services/capacity_calendar_service.dart';
import '../services/utilization_summary_service.dart';
import '../widgets/oee_ooe_teep_hierarchy_card.dart';
import '../widgets/ooe_info_icon.dart';
import 'capacity_calendar_edit_screen.dart';

/// Menadžerski pregled: kalendarsko vs operativno vs plan — osnova za TEEP.
class CapacityOverviewScreen extends StatefulWidget {
  const CapacityOverviewScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<CapacityOverviewScreen> createState() => _CapacityOverviewScreenState();
}

class _CapacityOverviewScreenState extends State<CapacityOverviewScreen> {
  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  static String _formatDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}.';
  }

  static String _h(int sec) {
    if (sec <= 0) return '0 s';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h h $m min';
    return '$sec s';
  }

  static String _capScopeLine(CapacityCalendar c) {
    switch (c.scopeType) {
      case 'line':
        return 'Linija · ${c.scopeId}';
      case 'machine':
        return 'Stroj · ${c.scopeId}';
      default:
        return 'Cijeli pogon';
    }
  }

  static String _utilScopeLine(UtilizationSummary u) {
    switch (u.scopeType) {
      case 'line':
        return 'Linija · ${u.scopeId}';
      case 'machine':
        return 'Stroj · ${u.scopeId}';
      default:
        return 'Cijeli pogon';
    }
  }

  Future<void> _openEditor({CapacityCalendar? existing, DateTime? initialDate}) async {
    if (!_canManage) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CapacityCalendarEditScreen(
          companyData: widget.companyData,
          existing: existing,
          initialDate: initialDate,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final calSvc = CapacityCalendarService();
    final utilSvc = UtilizationSummaryService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapacitet i kalendar'),
        actions: [
          OoeInfoIcon(
            tooltip: OoeHelpTexts.capacityOverviewTooltip,
            dialogTitle: OoeHelpTexts.capacityOverviewTitle,
            dialogBody: OoeHelpTexts.capacityOverviewBody,
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Novi dan'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CompanyPlantLabelText(
              companyId: _companyId,
              plantKey: _plantKey,
              prefix: '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const OeeOoeTeepHierarchyCard(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Kalendarski dani (capacity_calendars)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    OoeInfoIcon(
                      tooltip: OoeHelpTexts.capacitySectionCalendarHeaderTooltip,
                      dialogTitle: OoeHelpTexts.capacitySectionCalendarHeaderTitle,
                      dialogBody: OoeHelpTexts.capacitySectionCalendarHeaderBody,
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: calSvc.watchRecentForPlant(
                    companyId: _companyId,
                    plantKey: _plantKey,
                  ),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        AppErrorMapper.toMessage(snap.error!),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rows = snap.data ?? const [];
                    if (rows.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Još nema zapisa kapaciteta za ovaj pogon. '
                                'Bez capacity_calendars nije pouzdan izračun TEEP-a.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              if (_canManage) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _openEditor(),
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('Unesi prvi dan'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: rows.map((c) {
                        return Card(
                          child: ListTile(
                            title: Text(_formatDay(c.date)),
                            subtitle: Text(
                              '${_capScopeLine(c)}\n'
                              'Kalendar ${_h(c.calendarTimeSeconds)} · '
                              'operativno ${_h(c.scheduledOperatingTimeSeconds)} · '
                              'plan proizvodnje ${_h(c.plannedProductionTimeSeconds)}',
                            ),
                            isThreeLine: true,
                            trailing: _canManage
                                ? IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _openEditor(existing: c),
                                    tooltip: 'Uredi',
                                  )
                                : null,
                            onTap: _canManage ? () => _openEditor(existing: c) : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Iskorištenje (utilization_summaries)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    OoeInfoIcon(
                      tooltip: OoeHelpTexts.capacitySectionUtilizationHeaderTooltip,
                      dialogTitle: OoeHelpTexts.capacitySectionUtilizationHeaderTitle,
                      dialogBody: OoeHelpTexts.capacitySectionUtilizationHeaderBody,
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: utilSvc.watchRecentForPlant(
                    companyId: _companyId,
                    plantKey: _plantKey,
                  ),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        AppErrorMapper.toMessage(snap.error!),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rows = snap.data ?? const [];
                    if (rows.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Nema sažetaka iskorištenja. Računaju se kad postoje '
                            'tri vremenska sloja i backend agregat.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: rows.map((u) {
                        return Card(
                          child: ListTile(
                            title: Text(_formatDay(u.periodDate)),
                            subtitle: Text(
                              '${_utilScopeLine(u)} · ${u.periodType}\n'
                              'Utilization ${(u.utilization * 100).toStringAsFixed(1)} % · '
                              'kal. ${_h(u.calendarTimeSeconds)} · op. ${_h(u.operatingTimeSeconds)} · '
                              'plan ${_h(u.plannedProductionTimeSeconds)}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
