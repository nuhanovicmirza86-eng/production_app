import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_data_layers_hint.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_kpi_grid.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_period_bar.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_settlement_status_badge.dart';

/// Pregled obračuna — KPI, mjesec, status (iz **matrice**; izvor: agregat, ne sirovi events).
class WorkTimeOverviewScreen extends StatefulWidget {
  const WorkTimeOverviewScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeOverviewScreen> createState() => _WorkTimeOverviewScreenState();
}

class _WorkTimeOverviewScreenState extends State<WorkTimeOverviewScreen> {
  final WorkTimeMatrixService _matrixSvc = WorkTimeMatrixService();
  late int _year;
  late int _month;
  WorkTimeMatrixSnapshot? _matrix;
  bool _matrixLoading = true;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _year = n.year;
    _month = n.month;
    _refreshMatrix();
  }

  void _refreshMatrix() {
    if (!mounted) return;
    setState(() => _matrixLoading = true);
    unawaited(
      _matrixSvc
          .getMonthSnapshot(
            companyId: workTimeCompanyIdFrom(widget.companyData),
            plantKey: workTimePlantKeyFrom(widget.companyData),
            year: _year,
            month: _month,
          )
          .then((s) {
        if (!mounted) return;
        setState(() {
          _matrix = s;
          _matrixLoading = false;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_matrix == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pregled obračuna')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final snap = _matrix!;
    final kpi = WorkTimeKpiSnapshot.fromMatrix(snap);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled obračuna'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_matrixLoading) const LinearProgressIndicator(minHeight: 2),
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          WorkTimePeriodBar(
            year: _year,
            month: _month,
            onChanged: (y, m) {
              setState(() {
                _year = y;
                _month = m;
              });
              _refreshMatrix();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Status mjeseca: '),
              WorkTimeSettlementStatusBadge(wire: snap.settlementStatus),
            ],
          ),
          if (snap.hasReviewBlocker && snap.payrollBlockersNote != null) ...[
            const SizedBox(height: 8),
            Text(
              snap.payrollBlockersNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          const WorkTimeDataLayersHint(),
          const SizedBox(height: 8),
          Text(
            'Sažetak za mjesec ${kpi.monthLabel}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          WorkTimeKpiGrid(data: kpi),
        ],
      ),
    );
  }
}
