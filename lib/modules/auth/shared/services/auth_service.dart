import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _safeEmail(String v) => v.trim().toLowerCase();

  String _safeText(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _safeCode(String v) => v.trim().toUpperCase();

  String _nameFromEmail(String email) {
    final e = _safeEmail(email);
    final at = e.indexOf('@');
    final local = (at > 0) ? e.substring(0, at) : e;

    final cleaned = local
        .replaceAll(RegExp(r'[_\\-\\.]+'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return 'Korisnik';

    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');
  }

  bool _looksLikeEmail(String v) {
    final x = v.trim();
    if (x.isEmpty) return false;
    return RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$').hasMatch(x);
  }

  Future<_CompanyBinding> _resolveCompanyByCode(String companyCode) async {
    final code = _safeCode(companyCode);

    if (code.isEmpty) {
      throw Exception('Šifra firme je obavezna.');
    }

    final query = await _db
        .collection('companies')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Šifra firme nije pronađena.');
    }

    final doc = query.docs.first;
    final data = doc.data();

    final active = data['active'] == true;
    if (!active) {
      throw Exception('Firma nije aktivna. Registracija nije dozvoljena.');
    }

    return _CompanyBinding(
      companyId: doc.id,
      companyCode: code,
      companyName: _safeText((data['name'] ?? '').toString()),
    );
  }

  Future<User?> registerUser({
    required String email,
    required String password,
    String role = 'operator',
    String? fullName,
    String? displayName,
    String? workEmail,
    required String companyCode,
  }) async {
    final e = _safeEmail(email);

    final cred = await _auth.createUserWithEmailAndPassword(
      email: e,
      password: password,
    );

    final user = cred.user;
    if (user == null) return null;

    try {
      final resolvedCompany = await _resolveCompanyByCode(companyCode);

      final inputWorkEmail = _safeText(workEmail ?? '');
      final resolvedWorkEmail = _looksLikeEmail(inputWorkEmail)
          ? _safeEmail(inputWorkEmail)
          : e;

      final inputFullName = _safeText(fullName ?? '');
      final resolvedFullName = inputFullName.isNotEmpty
          ? inputFullName
          : _nameFromEmail(e);

      final inputDisplayName = _safeText(displayName ?? '');
      final resolvedDisplayName = inputDisplayName.isNotEmpty
          ? inputDisplayName
          : resolvedFullName;

      final normalizedRole = role.trim().isEmpty
          ? 'operator'
          : role.trim().toLowerCase();

      final now = FieldValue.serverTimestamp();

      // ================= USERS =================
      final userDoc = <String, dynamic>{
        'uid': user.uid,
        'email': e,
        'role': normalizedRole,
        'status': 'pending',
        'active': false,
        'approved': false,

        'companyId': resolvedCompany.companyId,
        'companyCode': resolvedCompany.companyCode,
        'companyName': resolvedCompany.companyName,

        // plant
        'homePlantKey': '',
        'plantKey': '',

        // user info
        'workEmail': resolvedWorkEmail,
        'fullName': resolvedFullName,
        'displayName': resolvedDisplayName,

        // 🔴 KLJUČNO (APP ACCESS)
        'appAccess': {'maintenance': false, 'production': false},

        'createdAt': now,
        'updatedAt': now,
        'createdByUid': user.uid,
        'updatedByUid': user.uid,
      };

      // ================= REGISTRATION REQUEST =================
      final reqDoc = <String, dynamic>{
        'uid': user.uid,
        'email': e,
        'role': normalizedRole,

        'displayName': resolvedDisplayName,
        'fullName': resolvedFullName,
        'workEmail': resolvedWorkEmail,

        'companyId': resolvedCompany.companyId,
        'companyCode': resolvedCompany.companyCode,
        'companyName': resolvedCompany.companyName,

        'status': 'pending',

        // 🔴 KLJUČNO (KOJA APP)
        'requestedApp': 'production',

        'requestedHomePlantKey': '',

        'createdAt': now,
        'updatedAt': now,
        'createdByUid': user.uid,
        'updatedByUid': user.uid,
      };

      final reqRef = _db.collection('registration_requests').doc(user.uid);
      final userRef = _db.collection('users').doc(user.uid);

      await reqRef.set(reqDoc, SetOptions(merge: true));
      await userRef.set(userDoc, SetOptions(merge: true));

      return user;
    } catch (e) {
      try {
        await _db.collection('registration_requests').doc(user.uid).delete();
      } catch (_) {}

      try {
        await _db.collection('users').doc(user.uid).delete();
      } catch (_) {}

      try {
        await user.delete();
      } catch (_) {}

      rethrow;
    }
  }
}

class _CompanyBinding {
  final String companyId;
  final String companyCode;
  final String companyName;

  const _CompanyBinding({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
  });
}
