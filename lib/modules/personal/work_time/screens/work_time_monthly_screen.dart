import 'dart:async' show unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_recompute_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_access.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_settlement_status.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_period_bar.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_settlement_status_badge.dart';

/// Mjesečni obračun — fond, kategorije sati, status i eventualne blokade.
class WorkTimeMonthlyScreen extends StatefulWidget {
  const WorkTimeMonthlyScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeMonthlyScreen> createState() => _WorkTimeMonthlyScreenState();
}

class _WorkTimeMonthlyScreenState extends State<WorkTimeMonthlyScreen> {
  final WorkTimeMatrixService _matrixSvc = WorkTimeMatrixService();
  final WorkTimeRecomputeService _recomputeSvc = WorkTimeRecomputeService();
  late int _year;
  late int _month;
  WorkTimeMatrixSnapshot? _matrix;
  bool _matrixLoading = true;
  bool _recomputeBusy = false;

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

  bool get _isTenantAdmin {
    final r = ProductionAccessHelper.normalizeRole(
      widget.companyData['role'],
    );
    return WorkTimeAccess.canOpenTenantAdminScreens(r);
  }

  Future<void> _onRecomputeMonth() async {
    if (_recomputeBusy) {
      return;
    }
    setState(() => _recomputeBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    final errColor = Theme.of(context).colorScheme.error;
    try {
      final res = await _recomputeSvc.recomputeMonth(
        companyId: workTimeCompanyIdFrom(widget.companyData),
        plantKey: workTimePlantKeyFrom(widget.companyData),
        year: _year,
        month: _month,
      );
      if (!mounted) {
        return;
      }
      if (res.ok) {
        _refreshMatrix();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Mjesečni sažetak ažuriran. '
              'Dnevnih redova: ${res.dailySummariesCount ?? 0}.',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Preračun nije uspio.'),
            backgroundColor: errColor,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message ?? e.code),
          backgroundColor: errColor,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: errColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _recomputeBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_matrix == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mjesečni obračun')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final s = _matrix!;
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mjesečni obračun'),
        actions: _isTenantAdmin
            ? [
                IconButton(
                  tooltip: 'Preračunaj mjesec iz dnevnih sažetaka',
                  onPressed: _recomputeBusy ? null : () => unawaited(_onRecomputeMonth()),
                  icon: _recomputeBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                ),
              ]
            : null,
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
          const SizedBox(height: 12),
          Text(
            'Mjesečni pregled sastavlja se iz provjerenih dnevnih podataka, ne iz pojedinačnih prijava bez kontrole.',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _section(
            t,
            'Pregled mjeseca po stavkama (probni prikaz):',
            child: _metricTable(
              t,
              [
                _MetricRow('Fond mjeseca', _h(s.fundHours), 'Ugovoreni / normativni sati mjeseca'),
                _MetricRow('Ostvareni sati', _h(s.workedHours), 'Zbroj zabilježenog rada'),
                _MetricRow('Redovni (u fondu)', _h(s.regularWithinFundHours), 'Unutar norme'),
                _MetricRow('Prekovremeno', _h(s.overtimeHours), 'Preko norme, po pravilu'),
                _MetricRow('Noćni', _h(s.nightHours), 'U noćni interval'),
                _MetricRow('Vikend', _h(s.weekendHours), 'Subota, nedjelja'),
                _MetricRow('Praznični', _h(s.holidayHours), 'Prema kalendaru praznika'),
                _MetricRow('Produž. topli obrok', '${s.extendedMealDays} d', 'Dani s produženim obrokom'),
                _MetricRow('Broj zabilježenih kašnjenja', '${s.lateCount}', 'Ako tvrtka to prati'),
                _MetricRow('Nepotpune prijave (d.)', '${s.incompleteEventDays}', 'Nedostaje ulaz ili izlaz'),
                _MetricRow('Korekcije (broj)', '${s.correctionsInMonth}', 'Ručno odobreni ispravci u mjesecu'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            t,
            'Status obračuna',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkTimeSettlementStatusBadge(wire: s.settlementStatus),
                const SizedBox(height: 6),
                Text(
                  'Mjesec prolazi faze: nacrt, pregled, odobrenje, zatvaranje, izvoz u plaće.',
                  style: t.textTheme.labelSmall,
                ),
                if (s.settlementStatus == WorkTimeSettlementStatus.needsReview) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.payrollBlockersNote ?? 'Postoje stavke za rješavanje.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _h(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()} h';
    return '${v.toStringAsFixed(1)} h';
  }

  Widget _section(ThemeData t, String title, {required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricTable(ThemeData t, List<_MetricRow> rows) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _th(t, 'Stavka'),
            _th(t, 'Vrijednost'),
                _th(t, 'Opis'),
          ],
        ),
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(r.label, style: t.textTheme.bodyMedium),
              ),
              Text(r.value, style: t.textTheme.titleSmall),
              Text(
                r.hint,
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _th(ThemeData t, String s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        s,
        style: t.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricRow {
  const _MetricRow(this.label, this.value, this.hint);
  final String label;
  final String value;
  final String hint;
}
