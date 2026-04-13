import 'package:flutter/material.dart';

import '../models/production_operator_tracking_entry.dart';
import '../widgets/preparation_tracking_tab.dart';

/// Operativno praćenje toka proizvodnje (pripremna → prva kontrola → završna kontrola).
/// Svaki tab predstavlja zaseban dnevni radni list za unos; Firestore model i štampa se dodaju iterativno.
class ProductionOperatorTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionOperatorTrackingScreen({super.key, required this.companyData});

  @override
  State<ProductionOperatorTrackingScreen> createState() =>
      _ProductionOperatorTrackingScreenState();
}

class _ProductionOperatorTrackingScreenState
    extends State<ProductionOperatorTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _todayLine(BuildContext context) {
    final d = DateTime.now();
    return MaterialLocalizations.of(context).formatFullDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praćenje proizvodnje'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pripremna'),
            Tab(text: 'Prva kontrola'),
            Tab(text: 'Završna kontrola'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Radni dan: ${_todayLine(context)}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PreparationTrackingTab(companyData: widget.companyData),
                PreparationTrackingTab(
                  companyData: widget.companyData,
                  phase: ProductionOperatorTrackingEntry.phaseFirstControl,
                ),
                PreparationTrackingTab(
                  companyData: widget.companyData,
                  phase: ProductionOperatorTrackingEntry.phaseFinalControl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
