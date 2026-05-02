/// Član projektnog tima na dokumentu `development_projects` (polje `team`).
///
/// [projectRole] = funkcija na projektu (npr. `technical_owner`); [systemRole] = `users.role` u tenantu.
class DevelopmentProjectTeamMember {
  const DevelopmentProjectTeamMember({
    required this.userId,
    required this.displayName,
    required this.projectRole,
    required this.systemRole,
    required this.canEditTasks,
    required this.canUploadDocuments,
    required this.canApproveGate,
  });

  final String userId;
  final String displayName;
  final String projectRole;
  final String systemRole;
  final bool canEditTasks;
  final bool canUploadDocuments;
  final bool canApproveGate;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static bool _bool(dynamic v, {bool defaultValue = false}) {
    if (v == true) return true;
    if (v == false) return false;
    return defaultValue;
  }

  factory DevelopmentProjectTeamMember.fromMap(Map<String, dynamic> m) {
    return DevelopmentProjectTeamMember(
      userId: _s(m['userId']),
      displayName: _s(m['displayName']),
      projectRole: _s(m['projectRole']),
      systemRole: _s(m['systemRole']),
      canEditTasks: _bool(m['canEditTasks']),
      canUploadDocuments: _bool(m['canUploadDocuments']),
      canApproveGate: _bool(m['canApproveGate']),
    );
  }

  /// Payload za Callable [replaceDevelopmentProjectTeam].
  Map<String, dynamic> toCallableMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'projectRole': projectRole,
      'systemRole': systemRole,
      'canEditTasks': canEditTasks,
      'canUploadDocuments': canUploadDocuments,
      'canApproveGate': canApproveGate,
    };
  }

  static List<DevelopmentProjectTeamMember> listFromField(dynamic raw) {
    if (raw is! List) return [];
    final out = <DevelopmentProjectTeamMember>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = e.map((k, v) => MapEntry(k.toString(), v));
      if (_s(m['userId']).isEmpty) continue;
      out.add(DevelopmentProjectTeamMember.fromMap(m));
    }
    return out;
  }
}
