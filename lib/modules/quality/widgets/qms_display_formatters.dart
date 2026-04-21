/// Jedinstveni prikaz za QMS: ljudski nazivi/šifre, bez golih ID-eva u UI-ju.
class QmsDisplayFormatters {
  QmsDisplayFormatters._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Red iz šifrarnika `products` (naziv + šifra koju kompanija koristi).
  static String productLine(Map<String, dynamic> m) {
    final name = _s(m['productName']);
    final code = _s(m['productCode']);
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (code.isNotEmpty) parts.add('Šifra: $code');
    return parts.isEmpty
        ? 'Proizvod (bez naziva u šifarniku)'
        : parts.join(' · ');
  }

  static String qmsDocStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Nacrt';
      case 'approved':
        return 'Odobreno';
      case 'obsolete':
        return 'Zastarjelo';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  static String inspectionType(String t) {
    switch (t.toUpperCase()) {
      case 'INCOMING':
        return 'Ulazna';
      case 'IN_PROCESS':
        return 'U procesu';
      case 'FINAL':
        return 'Završna';
      default:
        return t.isEmpty ? '—' : t;
    }
  }
}
