abstract final class WorkforceLeaveLabels {
  static String availabilityLabel(String code) {
    switch (code.trim()) {
      case 'unavailable':
        return 'Nedostupan';
      case 'reduced':
        return 'Smanjena dostupnost';
      case 'available':
        return 'Dostupan (info)';
      case 'unknown':
        return 'Nepoznato';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String categoryLabel(String code) {
    switch (code.trim()) {
      case 'undisclosed':
        return 'Ne navodi se';
      case 'annual':
        return 'Godišnji';
      case 'other_planned':
        return 'Drugo planirano';
      case 'other_unplanned':
        return 'Drugo neplanirano';
      case 'medical_category_operational':
        return 'Medicinsko odsustvo (kategorija)';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }
}
