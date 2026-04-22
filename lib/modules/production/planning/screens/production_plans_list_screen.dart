import 'package:flutter/material.dart';

import '../../../../core/ui/company_plant_label_text.dart';
import '../planning_ui_formatters.dart';
import '../models/saved_production_plan_summary.dart';
import '../services/production_plan_persistence_service.dart';
import 'production_plan_details_screen.dart';
import 'production_plan_gantt_screen.dart';

/// Pregled spremljenih nacrta plana (Firestore) za isti pogon.
class ProductionPlansListScreen extends StatefulWidget {
  const ProductionPlansListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionPlansListScreen> createState() =>
      _ProductionPlansListScreenState();
}

class _ProductionPlansListScreenState extends State<ProductionPlansListScreen> {
  final _persistence = ProductionPlanPersistenceService();
  List<SavedProductionPlanSummary> _items = [];
  bool _loading = true;
  String? _error;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cid.isEmpty || _pk.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji ili pogonu.';
        _items = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _persistence.listRecentPlans(
        companyId: _cid,
        plantKey: _pk,
        limit: 50,
      );
      if (mounted) {
        setState(() => _items = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nije moguće učitati listu planova. Provjerite prijavu, mrežu i pristup.';
          _items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spremljeni planovi'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CompanyPlantLabelText(
              companyId: _cid,
              plantKey: _pk,
              prefix: '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: _error != null
                            ? const SizedBox.shrink()
                            : Text(
                                'Još nema spremljenih planova za ovaj pogon.',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = _items[i];
                          return Card(
                            child: ListTile(
                              isThreeLine: true,
                              title: Text(
                                s.planCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${PlanningUiFormatters.planStatus(s.status)} · '
                                '${PlanningUiFormatters.formatDateTime(s.createdAt)}\n'
                                '${s.strategy.isNotEmpty ? "${PlanningUiFormatters.engineStrategy(s.strategy)}\n" : ""}'
                                'U rasporedu: ${s.scheduledOperationCount} oper. · '
                                'Mogući nalozi: ${s.feasibleOrderCount} · '
                                'Nemogući: ${s.infeasibleOrderCount} · '
                                'Upozorenja: ${s.totalConflicts}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Gantt',
                                    onPressed: () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProductionPlanGanttScreen(
                                            companyData: widget.companyData,
                                            planId: s.id,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.view_timeline_outlined),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProductionPlanDetailsScreen(
                                      companyData: widget.companyData,
                                      planId: s.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
