import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../services/quality_callable_service.dart';
import '../utils/ncr_next_disposition_catalog.dart';
import '../utils/ncr_qms_responsibility_matrix.dart';
import 'qms_iatf_help.dart';

/// Premium dijalog: dodjela akcije neusaglašenosti (matrica → faze → osoba).
Future<NcrNextDispositionDraft?> showNcrNextDispositionDialog({
  required BuildContext context,
  required NcrNextDispositionAction action,
  required String companyId,
  Map<String, dynamic>? existingNcr,
}) {
  return showDialog<NcrNextDispositionDraft>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _NcrNextDispositionDialog(
      action: action,
      companyId: companyId,
      existingNcr: existingNcr,
    ),
  );
}

class NcrNextDispositionDraft {
  const NcrNextDispositionDraft({
    required this.action,
    required this.flowPhase,
    required this.ownerDisplayName,
    required this.ownerUserKey,
    required this.roleOptionId,
    required this.roleLabelBs,
    required this.taskTemplate,
    required this.optionalNote,
    required this.priorityKey,
    required this.priorityLabelBs,
    required this.phaseKey,
    this.dueAt,
    this.executorDisplayName,
    this.executorUserKey,
    this.executorRoleOptionId,
    this.executorRoleLabelBs,
  });

  final NcrNextDispositionAction action;
  final NcrDispositionFlowPhase flowPhase;
  final String ownerDisplayName;
  final String ownerUserKey;
  final String roleOptionId;
  final String roleLabelBs;
  final DateTime? dueAt;
  final String taskTemplate;
  final String optionalNote;
  final String priorityKey;
  final String priorityLabelBs;
  final String phaseKey;
  final String? executorDisplayName;
  final String? executorUserKey;
  final String? executorRoleOptionId;
  final String? executorRoleLabelBs;

  bool get requiresDueAt =>
      flowPhase != NcrDispositionFlowPhase.initiateReworkOwner;

  String get reason => NcrNextDispositionCatalog.composeReason(
        taskTemplate: taskTemplate,
        optionalNote: optionalNote,
      );

  String? get dueAtIso {
    final d = dueAt;
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day'
        'T$hh:$mm';
  }
}

class _NcrAssignableUser {
  const _NcrAssignableUser({
    required this.userKey,
    required this.displayName,
    required this.roleKey,
  });

  final String userKey;
  final String displayName;
  final String roleKey;
}

class _NcrNextDispositionDialog extends StatefulWidget {
  const _NcrNextDispositionDialog({
    required this.action,
    required this.companyId,
    this.existingNcr,
  });

  final NcrNextDispositionAction action;
  final String companyId;
  final Map<String, dynamic>? existingNcr;

  @override
  State<_NcrNextDispositionDialog> createState() =>
      _NcrNextDispositionDialogState();
}

class _NcrNextDispositionDialogState extends State<_NcrNextDispositionDialog> {
  final _note = TextEditingController();
  final _svc = QualityCallableService();

  late final NcrDispositionFlowPhase _flowPhase;
  late NcrDispositionRoleOption _role;
  late DateTime _dueAt;
  List<_NcrAssignableUser> _allUsers = const [];
  List<_NcrAssignableUser> _users = const [];
  _NcrAssignableUser? _selectedUser;
  bool _loadingUsers = false;
  String? _usersError;
  bool _matrixHasAnyUser = false;

  String get _existingOwner =>
      (widget.existingNcr?['nextDispositionOwner'] ?? '').toString().trim();
  String get _existingOwnerRole =>
      (widget.existingNcr?['nextDispositionRoleLabel'] ?? '').toString().trim();

  List<NcrDispositionRoleOption> get _roleChoices {
    switch (_flowPhase) {
      case NcrDispositionFlowPhase.initiateReworkOwner:
        return NcrQmsResponsibilityMatrix.reworkOwnerRoles();
      case NcrDispositionFlowPhase.assignReworkExecutor:
        return NcrQmsResponsibilityMatrix.reworkExecutorRoles();
      case NcrDispositionFlowPhase.singleStep:
        return NcrQmsResponsibilityMatrix.rolesForActionKey(widget.action.key);
    }
  }

  @override
  void initState() {
    super.initState();
    final n = widget.existingNcr;
    _flowPhase = NcrQmsResponsibilityMatrix.resolveFlowPhase(
      actionKey: widget.action.key,
      existingActionKey: (n?['nextDispositionActionKey'] ?? '').toString(),
      existingOwner: (n?['nextDispositionOwner'] ?? '').toString(),
      existingExecutor: (n?['nextDispositionExecutor'] ?? '').toString(),
    );
    _role = _roleChoices.first;
    final now = DateTime.now();
    _dueAt = DateTime(now.year, now.month, now.day, 16, 0)
        .add(const Duration(days: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUsers());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<_NcrAssignableUser> _usersForRole(NcrDispositionRoleOption role) {
    final keys =
        role.matchRoles.map(ProductionAccessHelper.normalizeRole).toSet();
    return _allUsers
        .where(
          (u) => keys.contains(ProductionAccessHelper.normalizeRole(u.roleKey)),
        )
        .toList(growable: false);
  }

  void _applyRoleFilter({required bool preferAutoSelectRole}) {
    final roles = _roleChoices;
    var role = _role;
    if (preferAutoSelectRole) {
      final withUsers = roles.where((r) => _usersForRole(r).isNotEmpty);
      role = withUsers.isNotEmpty ? withUsers.first : roles.first;
    }
    final filtered = _usersForRole(role);
    setState(() {
      _role = role;
      _users = filtered;
      _selectedUser = filtered.length == 1 ? filtered.first : null;
      _matrixHasAnyUser = _allUsers.isNotEmpty;
      _loadingUsers = false;
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
      _selectedUser = null;
      _users = const [];
      _allUsers = const [];
      _matrixHasAnyUser = false;
    });
    try {
      final rows = await _svc.listUsersForNcrDispositionAssignment(
        companyId: widget.companyId,
        roleKeys: NcrQmsResponsibilityMatrix.allMatchRolesForOptions(
          _roleChoices,
        ),
      );
      if (!mounted) return;
      final mapped = rows
          .map(
            (r) => _NcrAssignableUser(
              userKey: (r['userKey'] ?? '').toString().trim(),
              displayName: (r['displayName'] ?? '').toString().trim(),
              roleKey: (r['roleKey'] ?? '').toString().trim(),
            ),
          )
          .where((u) => u.userKey.isNotEmpty && u.displayName.isNotEmpty)
          .toList()
        ..sort(
          (a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase()),
        );
      _allUsers = mapped;
      _applyRoleFilter(preferAutoSelectRole: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _usersError = 'Nije moguće učitati osobe za ovu odgovornost.';
      });
    }
  }

  void _onRoleChanged(String? id) {
    if (id == null) return;
    final next = _roleChoices.firstWhere((e) => e.id == id);
    setState(() {
      _role = next;
      _users = _usersForRole(next);
      _selectedUser = _users.length == 1 ? _users.first : null;
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Odaberi rok (datum)',
      cancelText: 'Odustani',
      confirmText: 'Dalje',
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
      helpText: 'Odaberi rok (vrijeme)',
      cancelText: 'Odustani',
      confirmText: 'Spremi',
    );
    if (!mounted) return;
    final tod = time ?? TimeOfDay.fromDateTime(_dueAt);
    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        tod.hour,
        tod.minute,
      );
    });
  }

  void _submit() {
    final user = _selectedUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _flowPhase == NcrDispositionFlowPhase.assignReworkExecutor
                ? 'Odaberi izvršioca dorade iz liste.'
                : 'Odaberi odgovornog vlasnika iz liste.',
          ),
        ),
      );
      return;
    }

    if (_flowPhase == NcrDispositionFlowPhase.initiateReworkOwner) {
      Navigator.pop(
        context,
        NcrNextDispositionDraft(
          action: widget.action,
          flowPhase: _flowPhase,
          ownerDisplayName: user.displayName,
          ownerUserKey: user.userKey,
          roleOptionId: _role.id,
          roleLabelBs: _role.labelBs,
          dueAt: null,
          taskTemplate: NcrQmsResponsibilityMatrix.reworkOwnerTaskBs,
          optionalNote: _note.text.trim(),
          priorityKey: widget.action.priorityKey,
          priorityLabelBs: widget.action.priorityBs,
          phaseKey: 'awaiting_executor',
        ),
      );
      return;
    }

    if (_flowPhase == NcrDispositionFlowPhase.assignReworkExecutor) {
      final ownerName = _existingOwner.isNotEmpty
          ? _existingOwner
          : user.displayName;
      final ownerRole = _existingOwnerRole.isNotEmpty
          ? _existingOwnerRole
          : 'Menadžer proizvodnje';
      final ownerKey =
          (widget.existingNcr?['nextDispositionOwnerUserKey'] ?? '').toString();
      Navigator.pop(
        context,
        NcrNextDispositionDraft(
          action: widget.action,
          flowPhase: _flowPhase,
          ownerDisplayName: ownerName,
          ownerUserKey: ownerKey.isNotEmpty ? ownerKey : user.userKey,
          roleOptionId: ProductionAccessHelper.roleProductionManager,
          roleLabelBs: ownerRole,
          dueAt: _dueAt,
          taskTemplate: NcrQmsResponsibilityMatrix.reworkExecutorTaskBs,
          optionalNote: _note.text.trim(),
          priorityKey: widget.action.priorityKey,
          priorityLabelBs: widget.action.priorityBs,
          phaseKey: 'executor_assigned',
          executorDisplayName: user.displayName,
          executorUserKey: user.userKey,
          executorRoleOptionId: _role.id,
          executorRoleLabelBs: _role.labelBs,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      NcrNextDispositionDraft(
        action: widget.action,
        flowPhase: _flowPhase,
        ownerDisplayName: user.displayName,
        ownerUserKey: user.userKey,
        roleOptionId: _role.id,
        roleLabelBs: _role.labelBs,
        dueAt: _dueAt,
        taskTemplate: widget.action.taskTemplateBs,
        optionalNote: _note.text.trim(),
        priorityKey: widget.action.priorityKey,
        priorityLabelBs: widget.action.priorityBs,
        phaseKey: 'assigned',
      ),
    );
  }

  String get _dueLabel {
    final dd = _dueAt.day.toString().padLeft(2, '0');
    final mm = _dueAt.month.toString().padLeft(2, '0');
    final hh = _dueAt.hour.toString().padLeft(2, '0');
    final mi = _dueAt.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${_dueAt.year}. $hh:$mi';
  }

  String get _dialogTitle {
    switch (_flowPhase) {
      case NcrDispositionFlowPhase.initiateReworkOwner:
        return 'Potrebna dorada';
      case NcrDispositionFlowPhase.assignReworkExecutor:
        return 'Dodjela izvršioca dorade';
      case NcrDispositionFlowPhase.singleStep:
        return widget.action.labelHr;
    }
  }

  String get _personLabel {
    switch (_flowPhase) {
      case NcrDispositionFlowPhase.initiateReworkOwner:
        return 'Odgovorni vlasnik (osoba)';
      case NcrDispositionFlowPhase.assignReworkExecutor:
        return 'Izvršilac dorade';
      case NcrDispositionFlowPhase.singleStep:
        return 'Odgovorna osoba';
    }
  }

  String get _roleLabel {
    switch (_flowPhase) {
      case NcrDispositionFlowPhase.initiateReworkOwner:
        return 'Odgovorni vlasnik (uloga)';
      case NcrDispositionFlowPhase.assignReworkExecutor:
        return 'Uloga izvršioca';
      case NcrDispositionFlowPhase.singleStep:
        return 'Odgovorna uloga';
    }
  }

  String get _emptyResponsibilityMessage {
    if (!_matrixHasAnyUser) {
      return 'Nema aktivne osobe za ovu odgovornost. '
          'Dodaj aktivnog korisnika s potrebnom ulogom.';
    }
    return 'Nema aktivne osobe za ulogu „${_role.labelBs}”. '
        'Odaberi drugu ulogu.';
  }

  String get _taskText {
    switch (_flowPhase) {
      case NcrDispositionFlowPhase.initiateReworkOwner:
        return NcrQmsResponsibilityMatrix.reworkOwnerTaskBs;
      case NcrDispositionFlowPhase.assignReworkExecutor:
        return NcrQmsResponsibilityMatrix.reworkExecutorTaskBs;
      case NcrDispositionFlowPhase.singleStep:
        return widget.action.taskTemplateBs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = _roleChoices;
    final showDue = _flowPhase != NcrDispositionFlowPhase.initiateReworkOwner;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.action.icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _dialogTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          QmsIatfInfoIcon(
            title: _dialogTitle,
            message: widget.action.processHelpBs(_flowPhase),
            size: 20,
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Šta treba uraditi',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.action.meaningBs,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_flowPhase == NcrDispositionFlowPhase.assignReworkExecutor &&
                  _existingOwner.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Odgovorni vlasnik: $_existingOwner'
                  '${_existingOwnerRole.isNotEmpty ? ' ($_existingOwnerRole)' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('ncr-role-${_role.id}-$_flowPhase'),
                initialValue: _role.id,
                decoration: InputDecoration(
                  labelText: _roleLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(value: r.id, child: Text(r.labelBs)),
                ],
                onChanged: _loadingUsers ||
                        _flowPhase == NcrDispositionFlowPhase.initiateReworkOwner
                    ? null
                    : _onRoleChanged,
              ),
              const SizedBox(height: 12),
              if (_loadingUsers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_usersError != null)
                Text(
                  _usersError!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else if (_users.isEmpty)
                Text(
                  _emptyResponsibilityMessage,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'ncr-user-${_role.id}-${_selectedUser?.userKey ?? 'none'}',
                  ),
                  initialValue: _selectedUser?.userKey,
                  decoration: InputDecoration(
                    labelText: _personLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final u in _users)
                      DropdownMenuItem(
                        value: u.userKey,
                        child: Text(u.displayName),
                      ),
                  ],
                  onChanged: (key) {
                    if (key == null) return;
                    setState(() {
                      _selectedUser =
                          _users.firstWhere((u) => u.userKey == key);
                    });
                  },
                ),
              if (showDue) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _flowPhase == NcrDispositionFlowPhase.assignReworkExecutor
                        ? 'Proizvodni rok: $_dueLabel'
                        : 'Rok: $_dueLabel',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text('Prioritet: ${widget.action.priorityBs}'),
                  onSelected: (_) {},
                  selected: true,
                  showCheckmark: false,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _flowPhase == NcrDispositionFlowPhase.initiateReworkOwner
                    ? 'Zadatak vlasnika'
                    : 'Predloženi zadatak',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_taskText, style: theme.textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Opcionalna napomena',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  helperText: 'Slobodan unos samo kao dodatna napomena',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _loadingUsers || _users.isEmpty || _selectedUser == null
              ? null
              : _submit,
          child: Text(
            _flowPhase == NcrDispositionFlowPhase.assignReworkExecutor
                ? 'Dodijeli izvršioca'
                : 'Spremi akciju',
          ),
        ),
      ],
    );
  }
}
