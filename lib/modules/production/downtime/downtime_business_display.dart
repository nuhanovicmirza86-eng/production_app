import '../../../core/user_display_label.dart';

/// Poslovni prikaz zastoja — ne mijenja zapis u bazi.
class DowntimeBusinessDisplay {
  DowntimeBusinessDisplay._();

  static final RegExp _plantToken = RegExp(
    r'^PLANT[_-]?\w+$',
    caseSensitive: false,
  );

  static bool isBusinessPersonName(String raw) {
    final t = UserDisplayLabel.stripEmbeddedUidFromDisplayName(raw).trim();
    if (t.isEmpty || t == '—' || t == '-' || t == '…') return false;
    if (t.contains('@')) return false;
    if (UserDisplayLabel.looksLikeFirebaseUid(t)) return false;
    if (_plantToken.hasMatch(t)) return false;
    final lower = t.toLowerCase();
    if (lower == 'korisnik' || lower == 'sistem' || lower == 'system') {
      return false;
    }
    return true;
  }

  /// `Z-PLANT_2-260603-2717` → `Zastoj 2717`. Nikad sirovi plantKey.
  static String codeLabel(String downtimeCode) {
    final raw = downtimeCode.trim();
    if (raw.isEmpty) return 'Zastoj';
    final tokens = raw.split(RegExp(r'[-_/\s]+'));
    for (final token in tokens.reversed) {
      final t = token.trim();
      if (t.isEmpty || _plantToken.hasMatch(t)) continue;
      if (RegExp(r'^\d{1,8}$').hasMatch(t)) {
        return 'Zastoj $t';
      }
    }
    return 'Zastoj';
  }

  /// displayName / fullName; inače `—`. Nikad e-mail / UID / plantKey.
  static String personLabel({
    required String storedName,
    required String storedId,
  }) {
    final cleaned = UserDisplayLabel.stripEmbeddedUidFromDisplayName(
      storedName,
    );
    if (isBusinessPersonName(cleaned)) return cleaned;
    final id = storedId.trim();
    if (id.isEmpty || id.contains('@')) return '—';
    final cached = UserDisplayLabel.peekUidLabel(id);
    if (cached != null && isBusinessPersonName(cached)) return cached;
    final resolved = UserDisplayLabel.labelForStored(id);
    if (isBusinessPersonName(resolved)) return resolved;
    return '—';
  }
}
