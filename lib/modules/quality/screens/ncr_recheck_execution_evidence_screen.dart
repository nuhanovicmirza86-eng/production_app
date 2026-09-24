import 'package:flutter/material.dart';

import '../utils/ncr_recheck_execution_choice_options.dart';
import '../utils/ncr_recheck_qty_validation.dart';
import '../widgets/ncr_evidence_form_fields.dart';
import '../widgets/ncr_execution_dialogs.dart';
import '../widgets/qms_iatf_help.dart';

/// M1-I12-D — premium forma evidencije ponovne kontrole (korak 9).
class NcrRecheckExecutionEvidenceScreen extends StatefulWidget {
  const NcrRecheckExecutionEvidenceScreen({
    super.key,
    this.expectedCheckedQty,
  });

  /// Broj komada poslanih na ponovnu kontrolu (predložak, ne default nula).
  final int? expectedCheckedQty;

  @override
  State<NcrRecheckExecutionEvidenceScreen> createState() =>
      _NcrRecheckExecutionEvidenceScreenState();
}

class _NcrRecheckExecutionEvidenceScreenState
    extends State<NcrRecheckExecutionEvidenceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _checked;
  final _ok = TextEditingController();
  final _rejected = TextEditingController();
  final _separated = TextEditingController();
  final _checkOther = TextEditingController();
  final _note = TextEditingController();

  final _fnChecked = FocusNode();
  final _fnOk = FocusNode();
  final _fnRejected = FocusNode();
  final _fnSeparated = FocusNode();
  final _fnCheckOther = FocusNode();
  final _fnNote = FocusNode();

  final _checkAspectKey = GlobalKey<FormFieldState<String>>();
  final _outcomeKey = GlobalKey<FormFieldState<String>>();

  String? _checkAspect;
  String? _outcome;
  String? _qtySumDetailError;
  String? _outcomeMismatchError;

  @override
  void initState() {
    super.initState();
    final expected = widget.expectedCheckedQty;
    _checked = TextEditingController(
      text: expected != null && expected > 0 ? expected.toString() : '',
    );
    for (final c in [_checked, _ok, _rejected, _separated]) {
      c.addListener(_clearQtyErrors);
    }
    _rejected.addListener(_onQtyChanged);
    _ok.addListener(_onQtyChanged);
  }

  void _onQtyChanged() => setState(() {});

  void _clearQtyErrors() {
    if (_qtySumDetailError == null && _outcomeMismatchError == null) return;
    setState(() {
      _qtySumDetailError = null;
      _outcomeMismatchError = null;
    });
  }

  @override
  void dispose() {
    _checked.dispose();
    _ok.dispose();
    _rejected.dispose();
    _separated.dispose();
    _checkOther.dispose();
    _note.dispose();
    _fnChecked.dispose();
    _fnOk.dispose();
    _fnRejected.dispose();
    _fnSeparated.dispose();
    _fnCheckOther.dispose();
    _fnNote.dispose();
    super.dispose();
  }

  int _parseQty(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  String? _choiceValidator({
    required String? selected,
    required TextEditingController other,
    String otherLabel = ncrRecheckChoiceOther,
  }) {
    if (selected == null || selected.isEmpty) return 'Odaberi opciju';
    if (selected == otherLabel && other.text.trim().length < 2) {
      return 'Unesi kratki opis';
    }
    return null;
  }

  void _focusNext(FocusNode next) => next.requestFocus();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final checked = _parseQty(_checked);
    final ok = _parseQty(_ok);
    final rejected = _parseQty(_rejected);
    final separated = _parseQty(_separated);

    final sumDetail = ncrRecheckQtySumDetailError(
      checked: checked,
      ok: ok,
      rejected: rejected,
      separated: separated,
    );
    if (sumDetail != null) {
      setState(() => _qtySumDetailError = sumDetail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provjeri količine — zbir nije ispravan.'),
        ),
      );
      return;
    }

    final outcomeSelected =
        _outcomeKey.currentState?.value ?? _outcome;
    final outcomeMismatch = ncrRecheckOutcomeMismatchError(
      outcome: outcomeSelected,
      ok: ok,
      rejected: rejected,
    );
    if (outcomeMismatch != null) {
      setState(() => _outcomeMismatchError = outcomeMismatch);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ishod kontrole nije usklađen s količinama.'),
        ),
      );
      return;
    }

    final checkSelected =
        _checkAspectKey.currentState?.value ?? _checkAspect;
    final checkDescription = resolveNcrRecheckCheckDescription(
      selected: checkSelected,
      otherText: _checkOther.text,
    );
    if (checkDescription == null || outcomeSelected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dovrši obavezne izbore u formi.')),
      );
      return;
    }

    Navigator.of(context).pop(
      NcrRecheckResultDraft(
        checkedQty: checked,
        okQty: ok,
        rejectedQty: rejected,
        separatedQty: separated,
        checkDescription: checkDescription,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
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

  Widget _outcomeMismatchBanner(ThemeData theme) {
    final msg = _outcomeMismatchError;
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

  Widget _outcomeHintBanner(ThemeData theme) {
    final outcome = _outcomeKey.currentState?.value ?? _outcome;
    if (outcome == null || outcome.isEmpty) {
      return const SizedBox.shrink();
    }
    final isNegative = outcome == 'Nije odobreno' ||
        outcome == 'Djelimično odobreno';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (isNegative
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.secondaryContainer)
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            recheckOutcomeHintBs(outcome),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtySumError = _qtySumDetailError != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ponovna kontrola'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: QmsIatfInfoIcon(
              title: 'Ponovna kontrola',
              message:
                  'Kontrola kvaliteta evidentira stvarni ishod. Ako je ijedan '
                  'komad ponovo odbijen, neusaglašenost ostaje otvorena i traži '
                  'novu odluku za te komade.',
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
            NcrEvidenceSectionCard(
              title: 'Količine kontrole',
              icon: Icons.pin_outlined,
              children: [
                NcrEvidenceQtyField(
                  controller: _checked,
                  focusNode: _fnChecked,
                  label: 'Kontrolisano komada',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () => _focusNext(_fnOk),
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
                  controller: _ok,
                  focusNode: _fnOk,
                  label: 'Ispravno komada',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () => _focusNext(_fnRejected),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Obavezno' : null,
                ),
                const SizedBox(height: 12),
                NcrEvidenceQtyField(
                  controller: _rejected,
                  focusNode: _fnRejected,
                  label: 'Ponovo odbijeno komada',
                  qtySumError: qtySumError,
                  onFieldSubmitted: () => _focusNext(_fnSeparated),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final n = int.tryParse((v ?? '').trim()) ?? -1;
                    if (n < 0) return 'Neispravan broj';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                NcrEvidenceQtyField(
                  controller: _separated,
                  focusNode: _fnSeparated,
                  label: 'Odvojeno komada',
                  qtySumError: qtySumError,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: () {
                    _checkAspectKey.currentState?.validate();
                    if (_checkAspect == ncrRecheckChoiceOther) {
                      _focusNext(_fnCheckOther);
                    }
                  },
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final n = int.tryParse((v ?? '').trim()) ?? -1;
                    if (n < 0) return 'Neispravan broj';
                    return null;
                  },
                ),
                _qtySumErrorBanner(theme),
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Šta je kontrolisano',
              icon: Icons.fact_check_outlined,
              children: [
                NcrEvidenceControlledChoiceField(
                  key: _checkAspectKey,
                  label: 'Odaberi aspekt kontrole',
                  options: ncrRecheckCheckedAspectOptions,
                  initialValue: _checkAspect,
                  otherController: _checkOther,
                  otherFocusNode: _fnCheckOther,
                  otherLabel: ncrRecheckChoiceOther,
                  onSelectionChanged: (v) => setState(() => _checkAspect = v),
                  validator: (v) => _choiceValidator(
                    selected: v,
                    other: _checkOther,
                    otherLabel: ncrRecheckChoiceOther,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Ishod ponovne kontrole',
              icon: Icons.rule_outlined,
              children: [
                NcrEvidenceControlledChoiceField(
                  key: _outcomeKey,
                  label: 'Odaberi ishod',
                  options: ncrRecheckOutcomeOptions,
                  initialValue: _outcome,
                  onSelectionChanged: (v) => setState(() {
                    _outcome = v;
                    _outcomeMismatchError = null;
                  }),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Odaberi ishod kontrole' : null,
                ),
                _outcomeMismatchBanner(theme),
                _outcomeHintBanner(theme),
              ],
            ),
            const SizedBox(height: 16),
            NcrEvidenceSectionCard(
              title: 'Napomena',
              icon: Icons.notes_outlined,
              children: [
                TextFormField(
                  controller: _note,
                  focusNode: _fnNote,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Dodatna napomena (opcionalno)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
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
              label: const Text('Spremi ishod kontrole'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Otvara premium formu evidencije ponovne kontrole.
Future<NcrRecheckResultDraft?> openNcrRecheckExecutionEvidence(
  BuildContext context, {
  int? expectedCheckedQty,
}) {
  return Navigator.of(context).push<NcrRecheckResultDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NcrRecheckExecutionEvidenceScreen(
        expectedCheckedQty: expectedCheckedQty,
      ),
    ),
  );
}
