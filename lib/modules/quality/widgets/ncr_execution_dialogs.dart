import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'qms_iatf_help.dart';

/// M1-I12-D — evidencija izvršene dorade (korak 7).
class NcrReworkExecutionDraft {
  const NcrReworkExecutionDraft({
    required this.reworkedQty,
    required this.separatedQty,
    required this.toRecheckQty,
    required this.workDescription,
    required this.machineCorrectionDone,
    required this.executedAt,
    this.correctionDescription,
    this.separatedDescription,
    this.note,
  });

  final int reworkedQty;
  final int separatedQty;
  final int toRecheckQty;
  final String workDescription;
  final bool machineCorrectionDone;
  final DateTime executedAt;
  final String? correctionDescription;
  final String? separatedDescription;
  final String? note;
}

/// M1-I12-D — evidencija ponovne kontrole (korak 9).
class NcrRecheckResultDraft {
  const NcrRecheckResultDraft({
    required this.checkedQty,
    required this.okQty,
    required this.rejectedQty,
    required this.separatedQty,
    required this.checkDescription,
    this.note,
  });

  final int checkedQty;
  final int okQty;
  final int rejectedQty;
  final int separatedQty;
  final String checkDescription;
  final String? note;
}

/// M1-I12-D — evidencija zaustavljanja proizvodnje.
class NcrProductionStopDraft {
  const NcrProductionStopDraft({
    required this.machineLabel,
    required this.reason,
    required this.restartCondition,
    required this.separatedQty,
    required this.releaseApproverUserKey,
    required this.releaseApproverName,
    this.separatedDescription,
  });

  final String machineLabel;
  final String reason;
  final String restartCondition;
  final int separatedQty;
  final String releaseApproverUserKey;
  final String releaseApproverName;
  final String? separatedDescription;
}

/// M1-I12-D — odobrenje nastavka proizvodnje.
class NcrStopReleaseDraft {
  const NcrStopReleaseDraft({required this.releaseNote});

  final String releaseNote;
}

final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

InputDecoration _dec(String label, {String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      border: const OutlineInputBorder(),
      isDense: true,
    );

int _parseQty(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

/// Zastarjeli dijalog — koristi [openNcrReworkExecutionEvidence] (puna forma).
@Deprecated('Koristi openNcrReworkExecutionEvidence')
class NcrReworkExecutionDialog extends StatelessWidget {
  const NcrReworkExecutionDialog({super.key, required this.taskBs});

  final String taskBs;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// Uklonjen inline AlertDialog — forma je na NcrReworkExecutionEvidenceScreen.

/// Zastarjeli dijalog — koristi [openNcrRecheckExecutionEvidence] (puna forma).
@Deprecated('Koristi openNcrRecheckExecutionEvidence')
class NcrRecheckResultDialog extends StatelessWidget {
  const NcrRecheckResultDialog({super.key, this.expectedQty});

  final int? expectedQty;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Dijalog: evidencija zaustavljanja proizvodnje.
class NcrProductionStopDialog extends StatefulWidget {
  const NcrProductionStopDialog({
    super.key,
    required this.approverOptions,
    this.machineSuggestion,
  });

  /// Aktivni korisnici koji mogu odobriti nastavak (menadžer proizvodnje).
  final List<Map<String, dynamic>> approverOptions;
  final String? machineSuggestion;

  @override
  State<NcrProductionStopDialog> createState() =>
      _NcrProductionStopDialogState();
}

class _NcrProductionStopDialogState extends State<NcrProductionStopDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _machine = TextEditingController(
    text: widget.machineSuggestion ?? '',
  );
  final _reason = TextEditingController();
  final _restart = TextEditingController();
  final _separated = TextEditingController(text: '0');
  final _separatedDesc = TextEditingController();
  String? _approverKey;

  @override
  void dispose() {
    _machine.dispose();
    _reason.dispose();
    _restart.dispose();
    _separated.dispose();
    _separatedDesc.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final approver = widget.approverOptions.firstWhere(
      (u) => (u['userKey'] ?? u['uid'] ?? '').toString() == _approverKey,
      orElse: () => const <String, dynamic>{},
    );
    if (approver.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi ko odobrava nastavak.')),
      );
      return;
    }
    Navigator.of(context).pop(
      NcrProductionStopDraft(
        machineLabel: _machine.text.trim(),
        reason: _reason.text.trim(),
        restartCondition: _restart.text.trim(),
        separatedQty: _parseQty(_separated),
        releaseApproverUserKey: _approverKey!,
        releaseApproverName:
            (approver['displayName'] ?? approver['name'] ?? '').toString(),
        separatedDescription: _parseQty(_separated) > 0
            ? _separatedDesc.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.block_outlined, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Zaustavljanje proizvodnje')),
          const QmsIatfInfoIcon(
            title: 'Zaustavljanje proizvodnje',
            message:
                'Evidentira se šta je zaustavljeno, zašto, šta je odvojeno i '
                'pod kojim uslovom se proizvodnja može nastaviti. Nastavak '
                'mora biti odobren.',
            size: 20,
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _machine,
                  decoration: _dec('Mašina ili linija'),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Obavezno' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: _dec('Razlog zaustavljanja'),
                  validator: (v) =>
                      (v ?? '').trim().length < 4 ? 'Obavezno' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _separated,
                  keyboardType: TextInputType.number,
                  inputFormatters: _qtyFormatters,
                  decoration: _dec('Koliko je odvojeno'),
                  onChanged: (_) => setState(() {}),
                ),
                if (_parseQty(_separated) > 0) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _separatedDesc,
                    maxLines: 2,
                    decoration: _dec('Šta je odvojeno'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _restart,
                  maxLines: 2,
                  decoration: _dec('Uslov za ponovno pokretanje'),
                  validator: (v) =>
                      (v ?? '').trim().length < 4 ? 'Obavezno' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _approverKey,
                  decoration: _dec('Ko odobrava nastavak'),
                  items: widget.approverOptions.map((u) {
                    final key = (u['userKey'] ?? u['uid'] ?? '').toString();
                    final name =
                        (u['displayName'] ?? u['name'] ?? '').toString();
                    final role = (u['roleLabel'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(role.isEmpty ? name : '$name — $role'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _approverKey = v),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Odaberi osobu' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Evidentiraj zaustavljanje'),
        ),
      ],
    );
  }
}

/// Dijalog: odobrenje nastavka proizvodnje.
class NcrStopReleaseDialog extends StatefulWidget {
  const NcrStopReleaseDialog({super.key, required this.restartConditionBs});

  final String restartConditionBs;

  @override
  State<NcrStopReleaseDialog> createState() => _NcrStopReleaseDialogState();
}

class _NcrStopReleaseDialogState extends State<NcrStopReleaseDialog> {
  final _note = TextEditingController();
  bool _conditionMet = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Odobrenje nastavka proizvodnje'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.restartConditionBs.trim().isNotEmpty) ...[
              Text(
                'Uslov za nastavak: ${widget.restartConditionBs.trim()}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _conditionMet,
              onChanged: (v) => setState(() => _conditionMet = v ?? false),
              title: const Text('Potvrđujem da je uslov ispunjen'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: _dec('Šta je poduzeto prije nastavka'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _conditionMet && _note.text.trim().length >= 4
              ? () => Navigator.of(context).pop(
                    NcrStopReleaseDraft(releaseNote: _note.text.trim()),
                  )
              : null,
          icon: const Icon(Icons.play_arrow_outlined),
          label: const Text('Odobri nastavak'),
        ),
      ],
    );
  }
}
