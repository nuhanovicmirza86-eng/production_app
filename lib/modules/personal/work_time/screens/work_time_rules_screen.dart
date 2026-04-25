import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_annual_leave_display.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_rules_draft.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_rules_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Pravila obračuna (samo administrator tvrtke).
class WorkTimeRulesScreen extends StatefulWidget {
  const WorkTimeRulesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeRulesScreen> createState() => _WorkTimeRulesScreenState();
}

class _WorkTimeRulesScreenState extends State<WorkTimeRulesScreen> {
  final WorkTimeRulesService _rulesSvc = WorkTimeRulesService();
  late WorkTimeRulesDraft _d;
  bool _dirty = false;
  bool _loadingRemote = true;
  String? _loadError;
  bool _textListenersAttached = false;

  late final TextEditingController _weeklyC;
  late final TextEditingController _dailyC;
  late final TextEditingController _maxOvertimeC;
  late final TextEditingController _minBreakC;
  late final TextEditingController _lateGraceC;
  late final TextEditingController _mealThresholdC;
  late final TextEditingController _holidayTagC;
  late final TextEditingController _annualBaseC;
  late final TextEditingController _annualCarryC;
  late final TextEditingController _policyNoteC;

  @override
  void initState() {
    super.initState();
    _d = WorkTimeRulesDraft.initial;
    _weeklyC = TextEditingController();
    _dailyC = TextEditingController();
    _maxOvertimeC = TextEditingController();
    _minBreakC = TextEditingController();
    _lateGraceC = TextEditingController();
    _mealThresholdC = TextEditingController();
    _holidayTagC = TextEditingController();
    _annualBaseC = TextEditingController();
    _annualCarryC = TextEditingController();
    _policyNoteC = TextEditingController();
    _syncTextFromDraft(WorkTimeRulesDraft.initial);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final draft = await _rulesSvc.getRules(
        companyId: workTimeCompanyIdFrom(widget.companyData),
        plantKey: workTimePlantKeyFrom(widget.companyData),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _d = draft;
        _loadError = null;
        _loadingRemote = false;
        _dirty = false;
      });
      _syncTextFromDraft(draft);
    } catch (e, st) {
      debugPrint('workTimeGetRules: $e $st');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError =
            'Učitavanje s poslužitelja nije uspjelo. Prikazane su zadane vrijednosti.';
        _loadingRemote = false;
      });
    }
    if (!mounted) {
      return;
    }
    if (!_textListenersAttached) {
      _addTextListeners();
      _textListenersAttached = true;
    }
  }

  List<TextEditingController> get _allTextCtrs => [
        _weeklyC,
        _dailyC,
        _maxOvertimeC,
        _minBreakC,
        _lateGraceC,
        _mealThresholdC,
        _holidayTagC,
        _annualBaseC,
        _annualCarryC,
        _policyNoteC,
      ];

  void _addTextListeners() {
    for (final c in _allTextCtrs) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final c in _allTextCtrs) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) {
      return;
    }
    setState(() => _dirty = true);
  }

  void _syncTextFromDraft(WorkTimeRulesDraft v) {
    for (final c in _allTextCtrs) {
      c.removeListener(_markDirty);
    }
    _weeklyC.text = _fmtNum(v.weeklyStandardHours);
    _dailyC.text = _fmtNum(v.dailyStandardHours);
    _maxOvertimeC.text = _fmtNum(v.maxOvertimeHoursPerDay);
    _minBreakC.text = _fmtNum(v.minBreakBetweenShiftsHours);
    _lateGraceC.text = '${v.lateGraceMinutes}';
    _mealThresholdC.text = '${v.extendedMealThresholdMinutes}';
    _holidayTagC.text = v.holidayCalendarTag;
    _annualBaseC.text = _fmtNum(v.annualLeaveBaseDaysPerYear);
    _annualCarryC.text = _fmtNum(v.annualLeaveMaxCarryoverDays);
    _policyNoteC.text = v.annualLeavePolicyNote;
    for (final c in _allTextCtrs) {
      c.addListener(_markDirty);
    }
  }

  String _fmtNum(double x) {
    if (x == x.roundToDouble()) {
      return '${x.toInt()}';
    }
    return x.toStringAsFixed(1);
  }

  double _parseD(String t, double fallback) {
    final s = t.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? fallback;
  }

  int _parseI(String t, int fallback) {
    return int.tryParse(t.trim().replaceAll(',', '.')) ?? fallback;
  }

  void _applyDraft(WorkTimeRulesDraft next, {bool clearDirty = true}) {
    setState(() {
      _d = next;
      _syncTextFromDraft(next);
      if (clearDirty) {
        _dirty = false;
      }
    });
  }

  void _resetToDefaults() {
    _applyDraft(WorkTimeRulesDraft.initial, clearDirty: true);
  }

  Future<void> _save() async {
    final next = _d.copyWith(
      nightStartMinute: _nearestClockQuarter(_d.nightStartMinute),
      nightEndMinute: _nearestClockQuarter(_d.nightEndMinute),
      weeklyStandardHours: _parseD(_weeklyC.text, _d.weeklyStandardHours),
      dailyStandardHours: _parseD(_dailyC.text, _d.dailyStandardHours),
      maxOvertimeHoursPerDay: _parseD(
        _maxOvertimeC.text,
        _d.maxOvertimeHoursPerDay,
      ),
      minBreakBetweenShiftsHours: _parseD(
        _minBreakC.text,
        _d.minBreakBetweenShiftsHours,
      ),
      lateGraceMinutes: _parseI(_lateGraceC.text, _d.lateGraceMinutes),
      extendedMealThresholdMinutes: _parseI(
        _mealThresholdC.text,
        _d.extendedMealThresholdMinutes,
      ),
      holidayCalendarTag: _holidayTagC.text.trim().isEmpty
          ? 'BA'
          : _holidayTagC.text.trim().toUpperCase(),
      annualLeaveBaseDaysPerYear: _parseD(
        _annualBaseC.text,
        _d.annualLeaveBaseDaysPerYear,
      ),
      annualLeaveMaxCarryoverDays: _parseD(
        _annualCarryC.text,
        _d.annualLeaveMaxCarryoverDays,
      ),
      annualLeavePolicyNote: _policyNoteC.text.trim().isEmpty
          ? kCroatiaAnnualLeaveLawSummaryHr
          : _policyNoteC.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    final errColor = Theme.of(context).colorScheme.error;
    final ok = await _rulesSvc.setRules(
      companyId: workTimeCompanyIdFrom(widget.companyData),
      plantKey: workTimePlantKeyFrom(widget.companyData),
      rules: next,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      _applyDraft(next, clearDirty: true);
        messenger.showSnackBar(
        const SnackBar(
          content: Text('Postavke su spremljene.'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Spremanje nije uspjelo. Provjerite ovlasti, pristup modulu za radno vrijeme i mrežu.',
          ),
          backgroundColor: errColor,
        ),
      );
      setState(() => _dirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loadingRemote) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pravila obračuna'),
          actions: [
            TextButton(
              onPressed: null,
              child: const Text('Zadane vrijednosti'),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pravila obračuna'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Zadane vrijednosti'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const WorkTimeDemoBanner(),
                const SizedBox(height: 8),
                if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Postavke se čuvaju za vašu tvrtku i odabrani pogon. Samo administrator '
                  'ih može mijenjati.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  t,
                  initiallyExpanded: true,
                  title: 'Fond mjeseca i dnevna norma',
                    subtitle: 'Sedmična i dnevna satnica',
                    children: [
                      _numField(
                        c: _weeklyC,
                        label: 'Sedmična norma (h)',
                        hint: 'Npr. 40',
                      ),
                      const SizedBox(height: 8),
                      _numField(
                        c: _dailyC,
                        label: 'Dnevna norma (h)',
                        hint: 'Npr. 8',
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: _d.useDailyNormForDayFund,
                        title: const Text('Dnevni fond = dnevna norma (radni dan)'),
                        subtitle: const Text('Primjenjivo na radne dane'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(useDailyNormForDayFund: v);
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Noćni rad i kategorije',
                    subtitle: 'Noć, vikend, praznici',
                    children: [
                      Text('Raspored noćnog rada (početak / kraj)', style: t.textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _timeDropdowns(
                              label: 'Početak noći',
                              hour: _d.nightStartHour,
                              minute: _d.nightStartMinute,
                              onHour: (h) {
                                setState(() {
                                  _d = _d.copyWith(nightStartHour: h);
                                  _dirty = true;
                                });
                              },
                              onMinute: (m) {
                                setState(() {
                                  _d = _d.copyWith(nightStartMinute: m);
                                  _dirty = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _timeDropdowns(
                              label: 'Kraj noći (jutro)',
                              hour: _d.nightEndHour,
                              minute: _d.nightEndMinute,
                              onHour: (h) {
                                setState(() {
                                  _d = _d.copyWith(nightEndHour: h);
                                  _dirty = true;
                                });
                              },
                              onMinute: (m) {
                                setState(() {
                                  _d = _d.copyWith(nightEndMinute: m);
                                  _dirty = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prikaz: ${_d.nightIntervalLabel}',
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _d.saturdayAsWeekend,
                        title: const Text('Subotu tretiraj kao vikend'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(saturdayAsWeekend: v);
                            _dirty = true;
                          });
                        },
                      ),
                      SwitchListTile(
                        value: _d.sundayAsWeekend,
                        title: const Text('Nedjelju tretiraj kao vikend'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(sundayAsWeekend: v);
                            _dirty = true;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _holidayTagC,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Koji kalendar praznika koristiti (oznaka)',
                          hintText: 'BA, RS, EU…',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Prekovremeno',
                    subtitle: 'Limit i odobrenje',
                    children: [
                      _numField(
                        c: _maxOvertimeC,
                        label: 'Maks. prekovr. dnevno (h)',
                        hint: 'Npr. 4',
                      ),
                      SwitchListTile(
                        value: _d.overtimeRequiresApproval,
                        title: const Text('Iznad limita — potrebno odobrenje'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(overtimeRequiresApproval: v);
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Kašnjenja i rani odlazak',
                    subtitle: 'Pragovi',
                    children: [
                      SwitchListTile(
                        value: _d.latePenaltyEnabled,
                        title: const Text('Praćenje kašnjenja'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(latePenaltyEnabled: v);
                            _dirty = true;
                          });
                        },
                      ),
                      _intField(
                        c: _lateGraceC,
                        label: 'Tolerancija (min) prije slučaja',
                        enabled: _d.latePenaltyEnabled,
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Rano dolazak (prije smjene)',
                    subtitle: 'Ako netko otkuča prije početka smjene po rasporedu',
                    children: [
                      SwitchListTile(
                        value: _d.earlyArrivalPriznajStvarniDolazak,
                        title: const Text('Priznaj sati rada od stvarnog dolaska (prijave)'),
                        subtitle: const Text(
                          'Ako isključite, sati rada se broje od početka smjene, '
                          'čak i ako je radnik ranije otkucao.',
                        ),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(earlyArrivalPriznajStvarniDolazak: v);
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Produženi topli obrok',
                    subtitle: 'Prag u minutama',
                    children: [
                      SwitchListTile(
                        value: _d.extendedMealEnabled,
                        title: const Text('Praćenje produženog toplog obroka'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(extendedMealEnabled: v);
                            _dirty = true;
                          });
                        },
                      ),
                      _intField(
                        c: _mealThresholdC,
                        label: 'Prag (minute) ispod kojeg nije “produženo”',
                        enabled: _d.extendedMealEnabled,
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Obračun i zatvaranje',
                    subtitle: 'Potvrde i izvoz u plaće',
                    children: [
                      SwitchListTile(
                        value: _d.settlementRequiresApproval,
                        title: const Text('Mjesec mora biti odobren pri isplati'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(settlementRequiresApproval: v);
                            _dirty = true;
                          });
                        },
                      ),
                      SwitchListTile(
                        value: _d.lockEditsAfterExport,
                        title: const Text('Nakon izvoza u plaće nema više izmjena'),
                        onChanged: (v) {
                          setState(() {
                            _d = _d.copyWith(lockEditsAfterExport: v);
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Godišnji odmor (pravo i stjecanje)',
                    subtitle: 'Baza, prijenos, napomena o zakonu / UGO-u',
                    children: [
                      Text(
                        'Podaci o preostalim danima s prošle godine i u tekućoj '
                        'unose se po radniku; ovdje postavite normativ i tekst pravilnika.',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _numField(
                        c: _annualBaseC,
                        label: 'Baza radnih dana godišnjeg (po punoj godini, tipično 20)',
                        hint: '20',
                      ),
                      const SizedBox(height: 8),
                      _numField(
                        c: _annualCarryC,
                        label: 'Maks. prijenos s prošle godine (dana)',
                        hint: '7',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _policyNoteC,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Informativni tekst o stjecanju (Zakon, KU, pravilnik)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (!_dirty) {
                            setState(() => _dirty = true);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                _section(
                  t,
                  initiallyExpanded: false,
                  title: 'Pauza između smjena',
                    subtitle: 'Minimalno vrijeme odmora, radi zakonitosti unosa',
                    children: [
                      _numField(
                        c: _minBreakC,
                        label: 'Minimalna pauza između smjena (h)',
                        hint: 'Npr. 11',
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Material(
            elevation: 2,
            color: t.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _dirty ? () => unawaited(_save()) : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Spremi postavke'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    ThemeData t, {
    bool initiallyExpanded = true,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: t.textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static final RegExp _numRe = RegExp(r'[0-9.,]');

  Widget _numField({
    required TextEditingController c,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(_numRe)],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _intField({
    required TextEditingController c,
    required String label,
    bool enabled = true,
  }) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  /// 0, 15, 30, 45 — u skladu s padajućim izborom.
  static int _nearestClockQuarter(int m) {
    const o = <int>[0, 15, 30, 45];
    return o.reduce(
      (a, b) => (m - a).abs() <= (m - b).abs() ? a : b,
    );
  }

  Widget _timeDropdowns({
    required String label,
    required int hour,
    required int minute,
    required ValueChanged<int> onHour,
    required ValueChanged<int> onMinute,
  }) {
    final mSel = _nearestClockQuarter(minute);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: hour.clamp(0, 23),
                items: [
                  for (int h = 0; h < 24; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text(h.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    onHour(v);
                  }
                },
              ),
            ),
          ),
          const Text(':'),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: mSel,
                items: [0, 15, 30, 45]
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.toString().padLeft(2, '0')),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    onMinute(v);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
