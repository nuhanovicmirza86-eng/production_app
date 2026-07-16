abstract final class WorkforceComplianceLabels {
  static String docTypeLabel(String code) {
    switch (code.trim()) {
      case 'statement':
        return 'Izjava';
      case 'policy_ack':
        return 'Potvrda procedure';
      case 'disciplinary':
        return 'Disciplinski zapisnik';
      case 'training_ack':
        return 'Potvrda obuke';
      case 'other':
        return 'Ostalo';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String statusLabel(String code) {
    switch (code.trim()) {
      case 'active':
        return 'Aktivan';
      case 'archived':
        return 'Arhiviran';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }
}
