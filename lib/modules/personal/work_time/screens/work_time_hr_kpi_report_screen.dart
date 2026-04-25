import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_hr_kpi_rollup.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Agregatni HR/KPI po tipovima događaja (kašnjenja, odsustva, prekovremeno).
/// U produkciji: stvarni agregati; ovdje primjer (YTD).
class WorkTimeHrKpiReportScreen extends StatelessWidget {
  const WorkTimeHrKpiReportScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const r = WorkTimeHrKpiRollup.demoYtd;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ponašanje i odsustva (ukupno)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Sažetak od početka godine: kašnjenja, rani dolazak, bolovanja, godišnji, '
            'ostala odsustva, prekovremene sate. Ispod su popisi za uočene obrasce.',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _metricRow(
            t,
            'Sati zbog kašnjenja (od početka godine)',
            '${r.lateArrivalHoursYtd} h',
          ),
          _metricRow(
            t,
            'Dana s priznatim ranim dolaskom (prema pravilu tvrtke)',
            '${r.earlyArrivalExcessYesCountYtd}',
          ),
          _metricRow(t, 'Bolovanje (dani)', '${r.sickLeaveDaysYtd}'),
          _metricRow(t, 'Godišnji (dani)', '${r.annualLeaveDaysYtd}'),
          _metricRow(t, 'Neplaćeno (dani)', '${r.unpaidAbsenceDaysYtd}'),
          _metricRow(t, 'Službeni put (dani)', '${r.businessTripDaysYtd}'),
          _metricRow(t, 'Plaćeno odsustvo (dani)', '${r.paidOtherDaysYtd}'),
          _metricRow(t, 'Smrtni slučaj (dani)', '${r.bereavementDaysYtd}'),
          _metricRow(t, 'Rođenje djeteta (dani)', '${r.childBirthDaysYtd}'),
          _metricRow(t, 'Vjenčanje (dani)', '${r.weddingDaysYtd}'),
          _metricRow(
            t,
            'Prekovremeni sati (od početka godine)',
            '${r.overtimeHoursYtd} h',
          ),
          const SizedBox(height: 16),
          Text('Upozorenja — učestala kašnjenja', style: t.textTheme.titleSmall),
          ...r.employeesFrequentLate.map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(s),
            ),
          ),
          Text('Upozorenja — česta bolovanja', style: t.textTheme.titleSmall),
          ...r.employeesFrequentSick.map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.local_hospital_outlined),
              title: Text(s),
            ),
          ),
          Text('Upozorenja — visoke prekovremene', style: t.textTheme.titleSmall),
          ...r.employeesOvertimeHigh.map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(ThemeData t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.textTheme.bodyMedium)),
          Text(value, style: t.textTheme.titleSmall),
        ],
      ),
    );
  }
}
