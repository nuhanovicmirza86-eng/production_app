import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../ooe_help_texts.dart';
import '../models/mes_tpm_six_losses.dart';
import '../models/ooe_shift_summary.dart';
import '../services/shift_context_service.dart';
import '../services/shift_context_window.dart';
import '../services/ooe_loss_reason_service.dart';
import '../services/ooe_summary_service.dart';
import '../widgets/ooe_info_icon.dart';
import '../widgets/ooe_loss_pareto_card.dart';

/// Pregled agregata smjene (summary kolekcija).
class OoeShiftSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Otvaranje iz MES obavijesti ([SHIFT_SUMMARY_READY]) — učitava stroj / smjenu / dan.
  final String? initialSummaryDocId;

  const OoeShiftSummaryScreen({
    super.key,
    required this.companyData,
    this.initialSummaryDocId,
  });

  @override
  State<OoeShiftSummaryScreen> createState() => _OoeShiftSummaryScreenState();
}

class _OoeShiftSummaryScreenState extends State<OoeShiftSummaryScreen> {
  final _machineCtrl = TextEditingController();
  final _shiftCodeCtrl = TextEditingController(text: 'DAY');
  final _orderIdCtrl = TextEditingController();
  final _productIdCtrl = TextEditingController();
  final _summary = OoeSummaryService();
  final _shiftCtxSvc = ShiftContextService();
  final _reasonSvc = OoeLossReasonService();

  late DateTime _shiftDay;
  late String _windowLine;
  Timer? _debounceWindow;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  Stream<Map<String, String>> get _ooeReasonLabelStream => _reasonSvc
      .watchAllReasonsForPlant(companyId: _companyId, plantKey: _plantKey)
      .map((list) => {for (final r in list) r.code: r.name});

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canRecompute => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.ooe,
  );

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _shiftDay = DateTime(n.year, n.month, n.day);
    _windowLine = ShiftContextWindowHelper.describeLabel(
      ShiftContextWindowHelper.eventWindowForSummary(
        shiftCalendarDayLocal: _shiftDay,
        context: null,
      ),
    );
    _shiftCodeCtrl.addListener(_onShiftCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sid = (widget.initialSummaryDocId ?? '').trim();
      if (sid.isNotEmpty) {
        await _applyOpenedSummary(sid);
      } else {
        await _refreshWindowLine();
      }
    });
  }

  Future<void> _applyOpenedSummary(String docId) async {
    final s = await _summary.getSummaryForTenant(
      companyId: _companyId,
      plantKey: _plantKey,
      docId: docId,
    );
    if (!mounted) return;
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sažetak nije pronađen ili nije u tvom pogonu.')),
      );
      await _refreshWindowLine();
      return;
    }
    final d = s.shiftDate.toLocal();
    setState(() {
      _machineCtrl.text = s.machineId;
      final sid = (s.shiftId ?? '').trim();
      _shiftCodeCtrl.text = sid.isEmpty ? 'DAY' : sid;
      _shiftDay = DateTime(d.year, d.month, d.day);
    });
    await _refreshWindowLine();
  }

  @override
  void dispose() {
    _debounceWindow?.cancel();
    _shiftCodeCtrl.removeListener(_onShiftCodeChanged);
    _machineCtrl.dispose();
    _shiftCodeCtrl.dispose();
    _orderIdCtrl.dispose();
    _productIdCtrl.dispose();
    super.dispose();
  }

  void _onShiftCodeChanged() {
    _debounceWindow?.cancel();
    _debounceWindow = Timer(
      const Duration(milliseconds: 400),
      _refreshWindowLine,
    );
  }

  Future<void> _refreshWindowLine() async {
    if (!mounted || _companyId.isEmpty || _plantKey.isEmpty) return;
    final raw = _shiftCodeCtrl.text.trim().toUpperCase();
    final shiftId = raw.isEmpty ? 'DAY' : raw;
    try {
      final ctx = await _shiftCtxSvc.getContext(
        companyId: _companyId,
        plantKey: _plantKey,
        shiftDateLocal: _shiftDay,
        shiftCode: shiftId,
      );
      if (!mounted) return;
      final w = ShiftContextWindowHelper.eventWindowForSummary(
        shiftCalendarDayLocal: _shiftDay,
        context: ctx,
      );
      setState(() {
        _windowLine = ShiftContextWindowHelper.describeLabel(w);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _windowLine = ShiftContextWindowHelper.describeLabel(
          ShiftContextWindowHelper.eventWindowForSummary(
            shiftCalendarDayLocal: _shiftDay,
            context: null,
          ),
        );
      });
    }
  }

  Future<void> _pickShiftDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _shiftDay,
      firstDate: DateTime(_shiftDay.year - 2),
      lastDate: DateTime(_shiftDay.year + 2),
    );
    if (picked != null && mounted) {
      setState(
        () => _shiftDay = DateTime(picked.year, picked.month, picked.day),
      );
      await _refreshWindowLine();
    }
  }

  static String _formatDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}.';
  }

  static String _formatSummaryShiftLine(OoeShiftSummary s) {
    final l = s.shiftDate.toLocal();
    final dateStr = '${l.day}.${l.month}.${l.year}.';
    final sid = (s.shiftId ?? '').trim();
    return sid.isEmpty ? dateStr : '$dateStr · $sid';
  }

  Future<void> _recompute() async {
    final mid = _machineCtrl.text.trim();
    if (mid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upiši šifru stroja.')),
      );
      return;
    }
    final rawCode = _shiftCodeCtrl.text.trim().toUpperCase();
    final shiftId = rawCode.isEmpty ? 'DAY' : rawCode;

    late DateTime start;
    late DateTime end;
    try {
      final ctx = await _shiftCtxSvc.getContext(
        companyId: _companyId,
        plantKey: _plantKey,
        shiftDateLocal: _shiftDay,
        shiftCode: shiftId,
      );
      final w = ShiftContextWindowHelper.eventWindowForSummary(
        shiftCalendarDayLocal: _shiftDay,
        context: ctx,
      );
      start = w.start;
      end = w.end;
    } catch (_) {
      final fb = ShiftContextWindowHelper.eventWindowForSummary(
        shiftCalendarDayLocal: _shiftDay,
        context: null,
      );
      start = fb.start;
      end = fb.end;
    }

    try {
      final oid = _orderIdCtrl.text.trim();
      final pid = _productIdCtrl.text.trim();
      final r = await _summary.recomputeShiftSummary(
        companyId: _companyId,
        plantKey: _plantKey,
        machineId: mid,
        windowStart: start,
        windowEnd: end,
        shiftId: shiftId,
        orderId: oid.isEmpty ? null : oid,
        productId: pid.isEmpty ? null : pid,
      );
      if (mounted) {
        final ooe = r['ooe'];
        final msg = ooe is num
            ? 'Sažetak izračunat. OOE ${(ooe.toDouble() * 100).toStringAsFixed(1)} %'
            : 'Sažetak smjene izračunat.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mid = _machineCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sažetak smjene'),
        actions: [
          OoeInfoIcon(
            tooltip: OoeHelpTexts.shiftSummaryTooltip,
            dialogTitle: OoeHelpTexts.shiftSummaryTitle,
            dialogBody: OoeHelpTexts.shiftSummaryBody,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CompanyPlantLabelText(
                    companyId: _companyId,
                    plantKey: _plantKey,
                    prefix: '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _machineCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Šifra stroja',
                            helperText:
                                'Ista kao u izvršenju i u imovini pogona (assets).',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_canRecompute)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton(
                            onPressed: _recompute,
                            child: const Text('Preračunaj'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: _pickShiftDay,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Dan smjene',
                                suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                              ),
                              child: Text(_formatDay(_shiftDay)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _shiftCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_-]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Oznaka smjene',
                            hintText: 'DAY',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$_windowLine · operativno vrijeme za A koristi kontekst '
                      'smjene ako je definisan.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _orderIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Proizvodni nalog (opc.)',
                            hintText: 'Unutrašnja referenca',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _productIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Proizvod (opc.)',
                            hintText: 'Unutrašnja referenca',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (mid.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyHint(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Odaberi stroj',
                subtitle:
                    'Upiši šifru stroja da vidiš zadnji sažetak i pokreneš preračun.',
              ),
            )
          else
            SliverFillRemaining(
              child: StreamBuilder<Map<String, String>>(
                stream: _ooeReasonLabelStream,
                builder: (context, reasonSnap) {
                  final ooeReasonLabels =
                      reasonSnap.hasData ? reasonSnap.data : null;
                  return StreamBuilder<List<OoeShiftSummary>>(
                    stream: _summary.watchSummariesForMachineRecent(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      machineId: mid,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              AppErrorMapper.toMessage(snap.error!),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final list = snap.data ?? const [];
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (list.isEmpty) {
                        return const _EmptyHint(
                          icon: Icons.analytics_outlined,
                          title: 'Još nema sažetka',
                          subtitle:
                              'Pritisni „Preračunaj“ da se agregat spremi na server.',
                        );
                      }
                      final s = list.first;
                      return ListView(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          Card(
                            child: ListTile(
                              title: Text(_formatSummaryShiftLine(s)),
                              subtitle: Text(
                                'OOE ${(s.ooe * 100).toStringAsFixed(1)} %',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OoeLossParetoCard(
                            losses: s.topLosses,
                            reasonLabels: ooeReasonLabels,
                            title: OoeHelpTexts.paretoTitle,
                            titleTrailing: OoeInfoIcon(
                              tooltip: OoeHelpTexts.paretoTooltip,
                              dialogTitle: OoeHelpTexts.paretoTitle,
                              dialogBody: OoeHelpTexts.paretoBody,
                              iconSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OoeLossParetoCard(
                            losses: s.topTpmLosses,
                            reasonLabels: MesTpmLossKeys.reasonKeyLabelMapHr(),
                            title: 'Gubici po TPM (sažetak smjene)',
                            titleTrailing: OoeInfoIcon(
                              tooltip: 'TPM agregat',
                              dialogTitle: 'Gubici po TPM u smjeni',
                              dialogBody:
                                  'Isti prozor vremena kao gornji Pareto; sekunde su '
                                  'zbrojene po ključu tpm_* (Callable recomputeOoeShiftSummary, v2).',
                              iconSize: 18,
                            ),
                          ),
                          Card(
                            child: ListTile(
                              title: const Text('Run / stop (s)'),
                              subtitle: Text(
                                '${s.runTimeSeconds} / ${s.stopTimeSeconds}',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
