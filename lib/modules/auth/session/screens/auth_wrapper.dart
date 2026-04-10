import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../production/dashboard/screens/production_dashboard_screen.dart';
import '../../screens/login_screen.dart';
import '../../shared/services/auth_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  User? _user;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _companyData;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen(_handleAuth);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _handleAuth(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _user = null;
        _loading = false;
        _error = null;
        _companyData = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _user = user;
      _error = null;
      _companyData = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _error =
            'Tvoj korisnički profil ne postoji u sistemu.\n'
            'Administrator mora prvo odobriti korisnika.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final data = userDoc.data() ?? <String, dynamic>{};

      final status = _s(data['status']).toLowerCase();
      final role = _s(data['role']).toLowerCase();
      final companyId = _s(data['companyId']);
      final plantKey = _s(data['plantKey']);

      final rawAppAccess = data['appAccess'];
      final appAccess = rawAppAccess is Map<String, dynamic>
          ? rawAppAccess
          : <String, dynamic>{};

      final canUseProduction = appAccess['production'] == true;

      if (status == 'pending') {
        _error =
            'Vaš zahtjev za registraciju je zaprimljen i čeka odobrenje Administratora.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (status != 'active') {
        _error =
            'Tvoj račun nije aktivan (status: "$status").\n'
            'Pristup je zaključan dok Administrator ne odobri nalog.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (!canUseProduction) {
        _error =
            'Nemaš odobren pristup za Operonix Production aplikaciju.\n'
            'Administrator mora odobriti Production pristup.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (role.isEmpty) {
        _error =
            'Nedostaje role u users dokumentu.\n'
            'Bez role korisnik ne može ući u aplikaciju.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (companyId.isEmpty) {
        _error =
            'Nedostaje companyId u users dokumentu.\n'
            'Bez company konteksta aplikacija ne može raditi.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (plantKey.isEmpty) {
        _error =
            'Nedostaje plantKey u users dokumentu.\n'
            'Bez plant konteksta Production app ne može raditi.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        _error = 'Company dokument ne postoji za companyId "$companyId".';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final company = companyDoc.data() ?? <String, dynamic>{};

      final active = company['active'] == true;
      if (!active) {
        _error =
            'Kompanija nije aktivna.\n'
            'Pristup aplikaciji nije dozvoljen.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      _companyData = {
        ...company,
        'companyId': companyId,
        'userId': user.uid,
        'role': role,
        'plantKey': plantKey,
        'userDisplayName': _s(data['displayName']),
        'userEmail': _s(data['email'] ?? user.email ?? ''),
      };

      _error = null;
    } catch (e) {
      _error =
          'Greška pri učitavanju korisničkog konteksta.\n'
          'Detalj: $e';
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshSession() async {
    await _handleAuth(FirebaseAuth.instance.currentUser);
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return LoginScreen(onLoginSuccess: _refreshSession);
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pristup zaključan')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _refreshSession,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Provjeri opet'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Odjavi se'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ProductionDashboardScreen(companyData: _companyData!);
  }
}
