import 'package:flutter/material.dart';

import '../utils/ncr_rework_execution_choice_options.dart';
import '../widgets/ncr_evidence_form_fields.dart';
import '../utils/ncr_rework_qty_validation.dart';
import '../widgets/ncr_execution_dialogs.dart';
import '../widgets/qms_iatf_help.dart';

/// M1-I12-D — puna forma evidencije izvršenja dorade (korak 7).
class NcrReworkExecutionEvidenceScreen extends StatefulWidget {
  const NcrReworkExecutionEvidenceScreen({
    super.key,
    required this.taskBs,
  });

  final String taskBs;

  @override
  State<NcrReworkExecutionEvidenceScreen> createState() =>
      _NcrReworkExecutionEvidenceScreenState();
}

class _NcrReworkExecutionEvidenceScreenState
    extends State<NcrReworkExecutionEvidenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reworked = TextEditingController();
  final _separated = TextEditingController();
  final _toRecheck = TextEditingController();
  final _workOther = TextEditingController();
  final _correctionOther = TextEditingController();
  final _separatedOther = TextEditingController();
  final _note = TextEditingController();

  final _fnReworked = FocusNode();
  final _fnSeparated = FocusNode();
  final _fnToRecheck = FocusNode();
  final _fnWorkOther = FocusNode();
  final _fnCorrectionOther = FocusNode();
  final _fnSeparatedOther = FocusNode();
  final _fnNote = FocusNode();

  final _workDoneKey = GlobalKey<FormFieldState<String>>();
  final _separatedReasonKey = GlobalKey<FormFieldState<String>>();
  final _correctionTypeKey = GlobalKey<FormFieldState<String>>();

  String? _workDone;
  String? _separatedReason;
  String? _correctionType;
  bool _machineCorrection = false;
  late DateTime _executedAt;
  String? _qtySumDetailError;

  @override
  void initState() {
    super.initState();
    _executedAt = DateTime.now();
    _reworked.addListener(_clearQtySumError);
    _toRecheck.addListener(_clearQtySumError);
    _separated.addListener(_onSeparatedChanged);
  }

  void _onSeparatedChanged() {
    _clearQtySumError();
    setState(() {});
  }

  void _clearQtySumError() {
    if (_qtySumDetailError == null) return;
    setState(() => _qtySumDetailError = null);
  }

  @override
  void dispose() {
    _reworked.dispose();
    _separated.dispose();
    _toRecheck.dispose();
    _workOther.dispose();
    _correctionOther.dispose();
    _separatedOther.dispose();
    _note.dispose();
    _fnReworked.dispose();
    _fnSeparated.dispose();
    _fnToRecheck.dispose();
    _fnWorkOther.dispose();
    _fnCorrectionOther.dispose();
    _fnSeparatedOther.dispose();
    _fnNote.dispose();
    super.dispose();
  }

  int _parseQty(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y. $h:$min';
  }

  Future<void> _pickExecutedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _executedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Vrijeme izvršenja (datum)',
      cancelText: 'Odustani',
      confirmText: 'Dalje',
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_executedAt),
      helpText: 'Vrijeme izvršenja (sat)',
      cancelText: 'Odustani',
      confirmText: 'Spremi',
    );
    if (!mounted) return;
    final tod = time ?? TimeOfDay.fromDateTime(_executedAt);
    setState(() {
      _executedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        tod.hour,
        tod.minute,
      );
    });
  }

  String? _buildQtySumDetailError() {
    return ncrReworkQtySumDetailError(
      reworked: _parseQty(_reworked),
      separated: _parseQty(_separated),
      toRecheck: _parseQty(_toRecheck),
    );
  }

  String? _choiceValidator({
    required String? selected,
    required TextEditingController other,
  }) {
    if (selected == null || selected.isEmpty) return 'Odaberi opciju';
    if (selected == ncrReworkChoiceOther && other.text.trim().length < 2) {
      return 'Unesi kratki opis';
    }
    return null;
  }

  void _focusNext(FocusNode next) {
    next.requestFocus();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sumDetail = _buildQtySumDetailError();
    if (sumDetail != null) {
      setState(() => _qtySumDetailError = sumDetail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provjeri količine — zbir nije ispravan.'),
        ),
      );
      return;
    }
    if (_executedAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vrijeme izvršenja ne može biti u budućnosti.'),
        ),
      );
      return;
    }

    final workSelected =
        _workDoneKey.currentState?.value ?? _workDone;
    final correctionSelected =
        _correctionTypeKey.currentState?.value ?? _correctionType;
    final separatedReasonSelected =
        _separatedReasonKey.currentState?.value ?? _separatedReason;

    final workDescription = resolveNcrEvidenceChoiceValue(
      selected: workSelected,
      otherText: _workOther.text,
    );
    final correctionDescription = _machineCorrection
        ? resolveNcrEvidenceChoiceValue(
            selected: correctionSelected,
            otherText: _correctionOther.text,
          )
        : null;
    final separatedQty = _parseQty(_separated);
    final separatedDescription = separatedQty > 0
        ? resolveNcrEvidenceChoiceValue(
            selected: separatedReasonSelected,
            otherText: _separatedOther.text,
          )
        : null;

    if (workDescription == null ||
        (_machineCorrection && correctionDescription == null) ||
        (separatedQty > 0 && separatedDescription == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dovrši obavezne izbore u formi.')),
      );
      return;
    }

    Navigator.of(context).pop(
      NcrReworkExecutionDraft(
        reworkedQty: _parseQty(_reworked),
        separatedQty: separatedQty,
        toRecheckQty: _parseQty(_toRecheck),
        workDescription: workDescription,
        machineCorrectionDone: _machineCorrection,
        correctionDescription: correctionDescription,
        separatedDescription: separatedDescription,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        executedAt: _executedAt,
      ),
    );
  }

  Widget _qtySumErrorBanner(ThemeData theme) {
    final msg = _qtySumDetailError;
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final separatedQty = _parseQty(_separated);
    final qtySumError = _qtySumDetailError != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidencija izvršenja dorade'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: QmsIatfInfoIcon(
              title: 'Evidencija izvršenja dorade',
              message:
                  'Unesi količine i odaberi šta je urađeno. Tek nakon spremanja '
                  'evidencije dorada prelazi na ponovnu kontrolu kvaliteta.',
              size: 22,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (widget.taskBs.trim().isNotEmpty)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Zadatak: ${widget.taskBs.trim()}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            if (widget.taskBs.trim().isNotEmpty) const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Količine',
              icon: Icons.pin_outlined,
              children: [
                NcrEvidenceQtyField(
                  controller: _reworked,
                  focusNode: _fnReworked,
                  label: 'Koliko komada je dorađeno',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () => _focusNext(_fnSeparated),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim()) ?? 0;
                    if ((v ?? '').trim().isEmpty || n < 1) {
                      return 'Obavezno';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                NcrEvidenceQtyField(
                  controller: _separated,
                  focusNode: _fnSeparated,
                  label: 'Koliko komada je odvojeno',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () => _focusNext(_fnToRecheck),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final n = int.tryParse((v ?? '').trim()) ?? -1;
                    if (n < 0) return 'Neispravan broj';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                NcrEvidenceQtyField(
                  controller: _toRecheck,
                  focusNode: _fnToRecheck,
                  label: 'Koliko komada ide na ponovnu kontrolu',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () {
                    _workDoneKey.currentState?.validate();
                    if (_workDone == ncrReworkChoiceOther) {
                      _focusNext(_fnWorkOther);
                    }
                  },
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Obavezno' : null,
                ),
                _qtySumErrorBanner(theme),
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Šta je urađeno',
              icon: Icons.build_circle_outlined,
              children: [
                NcrEvidenceControlledChoiceField(
                  key: _workDoneKey,
                  label: 'Odaberi vrstu dorade',
                  options: ncrReworkWorkDoneOptions,
                  initialValue: _workDone,
                  otherController: _workOther,
                  otherFocusNode: _fnWorkOther,
                  onSelectionChanged: (v) => setState(() => _workDone = v),
                  validator: (v) => _choiceValidator(
                    selected: v,
                    other: _workOther,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Korekcija na mašini / liniji',
              icon: Icons.precision_manufacturing_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _machineCorrection,
                  onChanged: (v) => setState(() {
                    _machineCorrection = v;
                    if (!v) _correctionType = null;
                  }),
                  title: const Text('Rađena je korekcija na mašini / liniji'),
                ),
                if (_machineCorrection) ...[
                  const SizedBox(height: 8),
                  NcrEvidenceControlledChoiceField(
                    key: _correctionTypeKey,
                    label: 'Vrsta korekcije',
                    options: ncrReworkMachineCorrectionOptions,
                    initialValue: _correctionType,
                    otherController: _correctionOther,
                    otherFocusNode: _fnCorrectionOther,
                    onSelectionChanged: (v) => setState(() => _correctionType = v),
                    validator: (v) => _choiceValidator(
                      selected: v,
                      other: _correctionOther,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Vrijeme i napomena',
              icon: Icons.schedule_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vrijeme izvršenja'),
                  subtitle: Text(_formatDateTime(_executedAt)),
                  trailing: OutlinedButton.icon(
                    onPressed: _pickExecutedAt,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Odaberi'),
                  ),
                ),
                if (separatedQty > 0) ...[
                  const SizedBox(height: 8),
                  NcrEvidenceControlledChoiceField(
                    key: _separatedReasonKey,
                    label: 'Šta je odvojeno i zašto',
                    options: ncrReworkSeparatedReasonOptions,
                    initialValue: _separatedReason,
                    otherController: _separatedOther,
                    otherFocusNode: _fnSeparatedOther,
                    onSelectionChanged: (v) =>
                        setState(() => _separatedReason = v),
                    validator: (v) => _choiceValidator(
                      selected: v,
                      other: _separatedOther,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  focusNode: _fnNote,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Dodatna napomena (opcionalno)',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Spremi evidenciju i završi doradu'),
            ),
            const SizedBox(height: 8),
            Text(
              'Dorada se ne završava bez unosa evidencije izvršenja.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Otvara punu formu evidencije izvršenja dorade.
Future<NcrReworkExecutionDraft?> openNcrReworkExecutionEvidence(
  BuildContext context, {
  required String taskBs,
}) {
  return Navigator.of(context).push<NcrReworkExecutionDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NcrReworkExecutionEvidenceScreen(taskBs: taskBs),
    ),
  );
}
