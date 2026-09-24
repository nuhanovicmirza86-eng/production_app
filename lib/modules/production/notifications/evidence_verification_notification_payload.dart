/// M1-I15-D-HOTFIX-17 — payload obavijesti za verifikaciju evidencije.
class EvidenceVerificationNotificationPayload {
  EvidenceVerificationNotificationPayload._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Identitet obrasca iz inbox `extra` ili FCM data. Ne prikazivati u UI.
  static String evidenceConfigIdFromData(Map<String, dynamic> data) {
    final top = _s(data['evidenceConfigId']);
    if (top.isNotEmpty) return top;
    final extra = data['extra'];
    if (extra is Map) {
      return _s(extra['evidenceConfigId']);
    }
    return '';
  }

  static String plantKeyFromData(Map<String, dynamic> data) {
    final top = _s(data['plantKey']);
    if (top.isNotEmpty) return top;
    final extra = data['extra'];
    if (extra is Map) {
      return _s(extra['plantKey']);
    }
    return '';
  }

  /// Inbox `entityId` je sessionId; FCM može imati `sessionId` na vrhu ili u extra.
  static String sessionIdFromData(Map<String, dynamic> data) {
    final top = _s(data['sessionId']);
    if (top.isNotEmpty) return top;
    final extra = data['extra'];
    if (extra is Map) {
      final fromExtra = _s(extra['sessionId']);
      if (fromExtra.isNotEmpty) return fromExtra;
    }
    return _s(data['entityId']);
  }
}
