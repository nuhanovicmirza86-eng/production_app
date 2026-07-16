abstract final class WorkforceTrainingLabels {
  static String typeLabel(String code) {
    switch (code.trim()) {
      case 'classroom':
        return 'Učionica';
      case 'practical':
        return 'Praktično';
      case 'online':
        return 'Online';
      case 'other':
        return 'Ostalo';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String statusLabel(String code) {
    switch (code.trim()) {
      case 'planned':
        return 'Planirano';
      case 'in_progress':
        return 'U toku';
      case 'completed':
        return 'Završeno';
      case 'failed':
        return 'Nije položeno';
      case 'cancelled':
        return 'Otkazano';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }
}
