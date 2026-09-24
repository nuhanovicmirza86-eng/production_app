import 'package:flutter/material.dart';

import '../../../../core/ui/company_plant_label_text.dart';
import 'downtime_analytics_tab.dart';
import 'downtimes_operative_tab.dart';

/// Zastoji: operativa (lista) + puna analitika (tab). Pregled; prijava nije ovdje.
class DowntimesScreen extends StatefulWidget {
  const DowntimesScreen({
    super.key,
    required this.companyData,
    this.initialTabIndex = 0,
    this.initialOperativeWorkCenterIdOrCode,
    this.initialEventRangeStart,
    this.initialEventRangeEndExclusive,
    this.openOperativeFiltersOnOpen = false,
    this.initialAnalyticsRangeStart,
    this.initialAnalyticsRangeEndExclusive,
    this.initialAnalyticsIncludeRejected,
  });

  final Map<String, dynamic> companyData;

  /// 0 = Operativa, 1 = Analitika.
  final int initialTabIndex;

  /// Predfilter liste (isti radni centar / šifra kao u analitici).
  final String? initialOperativeWorkCenterIdOrCode;

  /// Događaj se prikazuje ako mu je [DowntimeEventModel.startedAt] u [start, end) (lokalno), usklađeno s Operonix Analytics.
  final DateTime? initialEventRangeStart;
  final DateTime? initialEventRangeEndExclusive;

  /// Npr. nakon poveznice s analitike — odmah otvoreni filteri.
  final bool openOperativeFiltersOnOpen;

  /// Tab Analitika: isti [rangeStart, rangeEndExclusive) kao Operonix / izvještaj.
  final DateTime? initialAnalyticsRangeStart;
  final DateTime? initialAnalyticsRangeEndExclusive;
  final bool? initialAnalyticsIncludeRejected;

  @override
  State<DowntimesScreen> createState() => _DowntimesScreenState();
}

class _DowntimesScreenState extends State<DowntimesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zastoji')),
        body: const Center(
          child: Text('Nedostaje kontekst kompanije ili pogona.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zastoji'),
            CompanyPlantLabelText(
              companyId: _companyId,
              plantKey: _plantKey,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: (Theme.of(context).appBarTheme.foregroundColor ??
                            Theme.of(context).colorScheme.onSurface)
                        .withValues(alpha: 0.88),
                  ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_outlined), text: 'Operativa'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Analitika'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DowntimesOperativeTab(
            companyData: widget.companyData,
            initialWorkCenterIdOrCode: widget.initialOperativeWorkCenterIdOrCode,
            initialEventRangeStart: widget.initialEventRangeStart,
            initialEventRangeEndExclusive: widget.initialEventRangeEndExclusive,
            startWithFiltersExpanded: widget.openOperativeFiltersOnOpen,
          ),
          DowntimeAnalyticsTab(
            companyData: widget.companyData,
            initialRangeStart: widget.initialAnalyticsRangeStart,
            initialRangeEndExclusive: widget.initialAnalyticsRangeEndExclusive,
            initialIncludeRejected: widget.initialAnalyticsIncludeRejected,
          ),
        ],
      ),
    );
  }
}
