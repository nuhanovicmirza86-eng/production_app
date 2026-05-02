import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// DropdownButtonFormField: kontrolirani value — i dalje ispravno do sljedeće API stabilizacije.
// ignore_for_file: deprecated_member_use

import '../../../../core/access/production_access_helper.dart';
import '../models/development_project_model.dart';
import '../models/development_project_team_member.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';

/// Uređivanje `team[]` — Callable [replaceDevelopmentProjectTeam].
class DevelopmentProjectTeamScreen extends StatefulWidget {
  const DevelopmentProjectTeamScreen({
    super.key,
    required this.companyData,
    required this.project,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;

  @override
  State<DevelopmentProjectTeamScreen> createState() =>
      _DevelopmentProjectTeamScreenState();
}

class _DevelopmentProjectTeamScreenState
    extends State<DevelopmentProjectTeamScreen> {
  final _service = DevelopmentProjectService();
  late List<DevelopmentProjectTeamMember> _members;
  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool get _elevated =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    final t = List<DevelopmentProjectTeamMember>.from(p.team);
    if (t.isEmpty) {
      _members = [
        DevelopmentProjectTeamMember(
          userId: p.projectManagerId,
          displayName: p.projectManagerName,
          projectRole: DevelopmentTeamProjectRoles.projectManager,
          systemRole: ProductionAccessHelper.roleProjectManager,
          canEditTasks: true,
          canUploadDocuments: true,
          canApproveGate: false,
        ),
      ];
    } else {
      _members = t;
    }
  }

  int _pmCount() {
    return _members
        .where(
          (m) =>
              m.projectRole.trim().toLowerCase() ==
              DevelopmentTeamProjectRoles.projectManager,
        )
        .length;
  }

  String? _validateTeam() {
    if (_members.isEmpty) return 'Tim ne smije biti prazan.';
    if (_pmCount() != 1) {
      return 'Mora postojati točno jedan voditelj projekta (project_manager).';
    }
    return null;
  }

  Future<void> _editMember({int? index}) async {
    final existing = index != null ? _members[index] : null;
    final uidCtrl = TextEditingController(text: existing?.userId ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    var projectRole = existing?.projectRole ?? DevelopmentTeamProjectRoles.projectManager;
    if (!DevelopmentTeamProjectRoles.all.contains(projectRole)) {
      projectRole = DevelopmentTeamProjectRoles.projectManager;
    }
    var canTasks = existing?.canEditTasks ?? true;
    var canDocs = existing?.canUploadDocuments ?? true;
    var canGate = existing?.canApproveGate ?? false;

    final uidLocked = existing != null &&
        !_elevated &&
        existing.projectRole.toLowerCase() ==
            DevelopmentTeamProjectRoles.projectManager;

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Novi član' : 'Uredi člana'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!uidLocked)
                  TextField(
                    controller: uidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Korisnik UID (Firestore)',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  Text(
                    'UID voditelja: ${existing.userId}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prikazno ime (opcionalno)',
                    hintText: 'prazno = iz profila',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: projectRole,
                  decoration: const InputDecoration(
                    labelText: 'Uloga na projektu',
                    border: OutlineInputBorder(),
                  ),
                  items: DevelopmentTeamProjectRoles.all
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(DevelopmentDisplay.teamProjectRoleLabel(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => projectRole = v);
                  },
                ),
                CheckboxListTile(
                  value: canTasks,
                  onChanged: (v) => setDialog(() => canTasks = v ?? false),
                  title: const Text('Može uređivati zadatke'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: canDocs,
                  onChanged: (v) => setDialog(() => canDocs = v ?? false),
                  title: const Text('Može učitavati dokumente'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: canGate,
                  onChanged: (v) => setDialog(() => canGate = v ?? false),
                  title: const Text('Može odobravati Gate (UI hint)'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) {
      uidCtrl.dispose();
      nameCtrl.dispose();
      return;
    }

    final uid = uidLocked ? existing.userId : uidCtrl.text.trim();
    final displayName = nameCtrl.text.trim();
    uidCtrl.dispose();
    nameCtrl.dispose();

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UID korisnika je obavezan.')),
      );
      return;
    }

    final member = DevelopmentProjectTeamMember(
      userId: uid,
      displayName: displayName,
      projectRole: projectRole,
      systemRole: existing?.systemRole ??
          ProductionAccessHelper.roleProductionOperator,
      canEditTasks: canTasks,
      canUploadDocuments: canDocs,
      canApproveGate: canGate,
    );

    setState(() {
      if (index != null) {
        _members[index] = member;
      } else {
        _members.add(member);
      }
    });
  }

  void _removeAt(int i) {
    if (_members.length <= 1) return;
    setState(() => _members.removeAt(i));
  }

  Future<void> _save() async {
    final err = _validateTeam();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_companyId.isEmpty || _plantKey.isEmpty) return;

    final pmUid = _members
        .firstWhere(
          (m) =>
              m.projectRole.trim().toLowerCase() ==
              DevelopmentTeamProjectRoles.projectManager,
        )
        .userId;
    if (!_elevated &&
        _currentUid != null &&
        pmUid != _currentUid!.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Samo admin može postaviti drugog voditelja projekta.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.replaceProjectTeamViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectId: widget.project.id,
        team: _members.map((e) => e.toCallableMap()).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spremanje nije uspjelo: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUse = DevelopmentPermissions.canEditDevelopmentProjectTeam(
      role: widget.companyData['role']?.toString(),
      companyData: widget.companyData,
      project: widget.project,
      currentUserId: _currentUid,
    );

    if (!canUse) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tim projekta')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nemaš pravo mijenjati tim ovog projekta.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tim projekta'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Spremi'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editMember(),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_elevated)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Kao voditelj projekta možeš dodavati članove i mijenjati uloge, '
                'ali ne i postaviti drugog korisnika kao project_manager (to radi admin).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          Text(
            widget.project.projectCode,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_members.length, (i) {
            final m = _members[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  m.displayName.isEmpty ? m.userId : m.displayName,
                ),
                subtitle: Text(
                  '${DevelopmentDisplay.teamProjectRoleLabel(m.projectRole)} · ${m.userId}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editMember(index: i),
                    ),
                    if (_members.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeAt(i),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
