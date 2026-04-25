import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_settlement_status_badge.dart';

/// KPI primjeri za **Pregled obračuna** (izvor u produkciji: mjesečni/dnevni agregat).
class WorkTimeKpiSnapshot {
  const WorkTimeKpiSnapshot({
    required this.monthLabel,
    required this.fundHours,
    required this.workedHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.weekendHours,
    required this.holidayHours,
    required this.extendedMealDays,
    required this.lateCount,
    required this.incompleteCount,
    required this.correctionsCount,
    required this.settlementStatus,
  });

  final String monthLabel;
  final double fundHours;
  final double workedHours;
  final double regularHours;
  final double overtimeHours;
  final double nightHours;
  final double weekendHours;
  final double holidayHours;
  final int extendedMealDays;
  final int lateCount;
  final int incompleteCount;
  final int correctionsCount;
  final String settlementStatus;

  static WorkTimeKpiSnapshot fromMatrix(WorkTimeMatrixSnapshot m) {
    return WorkTimeKpiSnapshot(
      monthLabel: m.monthLabel,
      fundHours: m.fundHours,
      workedHours: m.workedHours,
      regularHours: m.regularWithinFundHours,
      overtimeHours: m.overtimeHours,
      nightHours: m.nightHours,
      weekendHours: m.weekendHours,
      holidayHours: m.holidayHours,
      extendedMealDays: m.extendedMealDays,
      lateCount: m.lateCount,
      incompleteCount: m.incompleteEventDays,
      correctionsCount: m.correctionsInMonth,
      settlementStatus: m.settlementStatus,
    );
  }

  static WorkTimeKpiSnapshot forPeriod(int year, int month) {
    return fromMatrix(WorkTimeMatrixDemo.snapshotFor(year, month));
  }

  /// Usklađen s trenutnim [WorkTimeMatrixDemo] za (year, month).
  static WorkTimeKpiSnapshot demo(String monthLabel) {
    // backward compat: parsiranje GGGG-MM
    final p = monthLabel.split('-');
    if (p.length == 2) {
      final y = int.tryParse(p[0]) ?? 2026;
      final m = int.tryParse(p[1]) ?? 4;
      return forPeriod(y, m);
    }
    return forPeriod(2026, 4);
  }
}

class WorkTimeKpiGrid extends StatelessWidget {
  const WorkTimeKpiGrid({super.key, required this.data});

  final WorkTimeKpiSnapshot data;

  @override
  Widget build(BuildContext context) {
    final items = <({String kpi, String value, String hint})>[
      (
        kpi: 'Fond sati mjeseca',
        value: _h(data.fundHours),
        hint: 'Radni dani u mjesecu puta dnevna norma (npr. 176 h)',
      ),
      (
        kpi: 'Ostvareni sati',
        value: _h(data.workedHours),
        hint: 'Suma obračunatih sati',
      ),
      (
        kpi: 'Redovni unutar fonda',
        value: _h(data.regularHours),
        hint: 'Prema pravilu / kategoriji',
      ),
      (
        kpi: 'Prekovremeno',
        value: _h(data.overtimeHours),
        hint: 'Ostvareno − fond (kad primjenjivo)',
      ),
      (
        kpi: 'Noćni rad',
        value: _h(data.nightHours),
        hint: 'Presjek s noćnim intervalom',
      ),
      (
        kpi: 'Vikend',
        value: _h(data.weekendHours),
        hint: 'Sub/ned prema pravilu',
      ),
      (
        kpi: 'Praznični',
        value: _h(data.holidayHours),
        hint: 'Kalendar praznika',
      ),
      (
        kpi: 'Produženi topli obrok',
        value: '${data.extendedMealDays} d',
        hint: 'Dani preko praga (min)',
      ),
      (
        kpi: 'Kašnjenja',
        value: '${data.lateCount} slučajeva',
        hint: 'Ako tvrtka prati kašnjenja',
      ),
      (
        kpi: 'Nepotpune prijave',
        value: '${data.incompleteCount} d',
        hint: 'Bez ulaza/izlaza',
      ),
      (
        kpi: 'Ručne korekcije',
        value: '${data.correctionsCount} u mjesecu',
        hint: 'Zapis ispravaka u mjesecu',
      ),
      (
        kpi: 'Status obračuna',
        value: WorkTimeSettlementStatusBadge.labelHr(data.settlementStatus),
        hint: 'Faza mjeseca u obradi (nacrt, odobrenje, zatvaranje…)',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cross;
        if (w >= 1100) {
          cross = 4;
        } else if (w >= 700) {
          cross = 2;
        } else {
          cross = 1;
        }
        return GridView.count(
          crossAxisCount: cross,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cross == 1 ? 3.2 : 2.1,
          children: [
            for (final e in items)
              _KpiCard(title: e.kpi, value: e.value, hint: e.hint),
          ],
        );
      },
    );
  }

  String _h(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()}h';
    return '${v.toStringAsFixed(1)}h';
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.hint,
  });

  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
