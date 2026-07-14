/// Profil ciljeva optimizacije (P0 master data).
class ApsObjectiveProfileView {
  const ApsObjectiveProfileView({
    required this.id,
    required this.profileName,
    this.isActive = true,
    this.objectives = const {},
  });

  final String id;
  final String profileName;
  final bool isActive;
  final Map<String, String> objectives;

  /// Default „Balansiran plan“ — po nazivu profila ili prvi aktivan.
  static ApsObjectiveProfileView? pickBalancedDefault(
    List<ApsObjectiveProfileView> profiles,
  ) {
    if (profiles.isEmpty) return null;
    for (final p in profiles) {
      final lower = p.profileName.toLowerCase();
      if (lower.contains('balans')) return p;
    }
    final active = profiles.where((p) => p.isActive).toList();
    if (active.isNotEmpty) return active.first;
    return profiles.first;
  }

  factory ApsObjectiveProfileView.fromMap(Map<String, dynamic> map) {
    final active = map['isActive'];
    final rawObjectives = map['objectives'];
    final objectives = <String, String>{};
    if (rawObjectives is Map) {
      for (final entry in rawObjectives.entries) {
        objectives[entry.key.toString()] = (entry.value ?? '').toString().trim();
      }
    }
    return ApsObjectiveProfileView(
      id: (map['id'] ?? '').toString().trim(),
      profileName: (map['profileName'] ?? '').toString().trim(),
      isActive: active is bool ? active : true,
      objectives: objectives,
    );
  }
}
