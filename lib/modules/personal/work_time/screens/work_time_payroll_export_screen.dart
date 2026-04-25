import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_settlement_status.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_period_bar.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_settlement_status_badge.dart';

/// Payroll export — [payroll_exports]; samo nakon [locked] / politike tenant-a.
class WorkTimePayrollExportScreen extends StatefulWidget {
  const WorkTimePayrollExportScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimePayrollExportScreen> createState() =>
      _WorkTimePayrollExportScreenState();
}

class _WorkTimePayrollExportScreenState
    extends State<WorkTimePayrollExportScreen> {
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
        appBar: AppBar(title: const Text('Izvoz za plaće')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final s = _matrix!;
    final t = Theme.of(context);
    const exportOk = {
      WorkTimeSettlementStatus.locked,
      WorkTimeSettlementStatus.approved,
      WorkTimeSettlementStatus.exported,
    };
    final canExport = exportOk.contains(s.settlementStatus);

    return Scaffold(
      appBar: AppBar(title: const Text('Izvoz za plaće')),
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
            'Redoslijed: nacrt → za pregled (greške) → spremno za odobrenje → '
            'odobreno → zaključano → poslano u obračun plaća',
            style: t.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Trenutno: '),
              WorkTimeSettlementStatusBadge(wire: s.settlementStatus),
            ],
          ),
          if (!canExport) ...[
            const SizedBox(height: 8),
            Text(
              s.settlementStatus == WorkTimeSettlementStatus.needsReview
                  ? 'Izvoz je blokiran: mjesec još ima greške koje treba riješiti.'
                  : s.settlementStatus == WorkTimeSettlementStatus.draft
                      ? 'Izvoz nije dozvoljen dok je mjesec u nacrtu. Odobrite ili ga zaključajte.'
                      : 'Izvoz uobičajeno dolazi nakon odobrenja ili zaključavanja, prema pravilu tvrtke.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canExport
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Izvoz u sustav za plaće još nije uključen. Kontaktirajte podršku kad bude dostupno.'),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Napravi datoteku za plaće'),
          ),
        ],
      ),
    );
  }
}
