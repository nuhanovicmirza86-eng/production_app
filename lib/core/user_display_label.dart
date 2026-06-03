import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Human-readable user labels for UI. Never show raw Firebase UIDs to end users.
class UserDisplayLabel {
  UserDisplayLabel._();

  static final Map<String, String> _uidCache = {};

  /// Header / operator self-label from merged session map ([AuthWrapper]).
  static String fromSessionMap(Map<String, dynamic> m) {
    for (final key in ['userDisplayName', 'nickname', 'displayName']) {
      final v = (m[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    final e = (m['userEmail'] ?? '').toString().trim();
    if (e.isNotEmpty) return e;
    final u = FirebaseAuth.instance.currentUser;
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final em = u?.email?.trim();
    if (em != null && em.isNotEmpty) return em;
    return 'Korisnik';
  }

  static bool looksLikeFirebaseUid(String raw) {
    final s = raw.trim();
    if (s.length < 20 || s.length > 128) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(s);
  }

  /// Kratki / nestandardni auth id-jevi (npr. custom token) koji ipak trebaju ići kroz `users/{id}`.
  static bool looksLikeProbableAuthUserKey(String raw) {
    final s = raw.trim();
    if (s.contains('@')) return false;
    if (s.length < 10 || s.length > 128) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(s);
  }

  static bool _shouldLookupUserDocument(String t) {
    if (t.contains('@')) return false;
    if (t.toLowerCase() == 'system') return false;
    return looksLikeFirebaseUid(t) || looksLikeProbableAuthUserKey(t);
  }

  /// After [prefetchUids], returns cached label; otherwise null (still loading).
  static String? peekUidLabel(String uid) {
    final t = uid.trim();
    if (t.isEmpty) return null;
    return _uidCache[t];
  }

  static void _put(String uid, String label) {
    _uidCache[uid.trim()] = label;
  }

  /// Resolve stored audit value: emails pass through; UIDs load from `users/{id}`.
  static Future<String> resolveStored(
    FirebaseFirestore firestore,
    String stored,
  ) async {
    final t = stored.trim();
    if (t.isEmpty || t == '-') return '—';
    if (t.contains('@')) return t;
    final lower = t.toLowerCase();
    if (lower == 'system') return 'Sistem';
    if (!_shouldLookupUserDocument(t)) return t;

    final cached = _uidCache[t];
    if (cached != null) return cached;

    try {
      final doc = await firestore.collection('users').doc(t).get();
      if (!doc.exists) {
        _put(t, 'Korisnik');
        return 'Korisnik';
      }
      final d = doc.data() ?? {};
      final display = (d['displayName'] ?? '').toString().trim();
      if (display.isNotEmpty) {
        _put(t, display);
        return display;
      }
      final email = (d['email'] ?? '').toString().trim();
      if (email.isNotEmpty) {
        _put(t, email);
        return email;
      }
    } catch (_) {}
    _put(t, 'Korisnik');
    return 'Korisnik';
  }

  static Future<void> prefetchUids(
    FirebaseFirestore firestore,
    Iterable<String> values,
  ) async {
    final ids = <String>{};
    for (final v in values) {
      final s = v.trim();
      if (s.isEmpty) continue;
      if (s.contains('@')) continue;
      if (!_shouldLookupUserDocument(s)) continue;
      if (_uidCache.containsKey(s)) continue;
      ids.add(s);
    }
    if (ids.isEmpty) return;
    await Future.wait(ids.map((id) => resolveStored(firestore, id)));
  }

  /// Readable label for a stored actor string after [prefetchUids] for known UIDs.
  static String labelForStored(String stored) {
    final t = stored.trim();
    if (t.isEmpty || t == '-') return '—';
    if (t.contains('@')) return t;
    if (t.toLowerCase() == 'system') return 'Sistem';
    if (!_shouldLookupUserDocument(t)) return t;
    return _uidCache[t] ?? '…';
  }

  /// Uklanja legacy obrazac „ime (UID)” iz [displayName].
  static String stripEmbeddedUidFromDisplayName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    final m = RegExp(
      r'^(.+?)\s*\(([a-zA-Z0-9_-]{20,128})\)\s*$',
    ).firstMatch(s);
    if (m == null) return s;
    final inner = m.group(2) ?? '';
    if (looksLikeFirebaseUid(inner) || looksLikeProbableAuthUserKey(inner)) {
      return (m.group(1) ?? '').trim();
    }
    return s;
  }

  /// Ime osobe za audit / liste: nikad sirovi Firebase UID.
  static String personLine(String displayName, String storedId) {
    var name = stripEmbeddedUidFromDisplayName(displayName);
    final stored = storedId.trim();
    if (name.isNotEmpty && looksLikeFirebaseUid(name)) {
      name = '';
    }
    if (name.isNotEmpty) {
      if (name.contains('@') && stored.isNotEmpty) {
        final resolved = labelForStored(stored);
        if (resolved != '…') return resolved;
        return name;
      }
      return name;
    }
    if (stored.isEmpty) return '—';
    if (stored.contains('@')) return stored;
    final label = labelForStored(stored);
    return label == '…' ? '—' : label;
  }
}
