import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:production_app/services/fcm_token_service.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/production_admin_session_plant.dart';
import '../../../../core/station_launch_config.dart';
import '../../../../core/station_launch_preference.dart';
import '../../../production/dashboard/screens/production_dashboard_screen.dart';
import '../../../production/station_pages/widgets/station_page_active_gate.dart';
import '../../../production/tracking/models/production_operator_tracking_entry.dart';
import '../../../production/tracking/screens/production_operator_tracking_station_screen.dart';
import '../../../production/station/screens/station_tracking_setup_screen.dart';
import '../../../production/tracking/config/station_tracking_setup_store.dart';
import '../../../production/tracking/screens/production_preparation_station_screen.dart';
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

  /// Nakon ulaska na stanicu: korisnik zatvori stanicu → cijela aplikacija (do sljedećeg cold starta).
  bool _showFullAppAfterDedicated = false;

  /// Efektivna faza stanice: [StationLaunchConfig] (build) ili [StationLaunchPreference] (uređaj).
  String? _effLaunchPhase;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen(_handleAuth);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Kanonski tenant id — `companyId` u users često je string, ponekad DocumentReference.
  String _companyIdFromUserField(dynamic raw) {
    if (raw is DocumentReference) return raw.id.trim();
    return _s(raw);
  }

  Future<void> _handleAuth(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _user = null;
        _loading = false;
        _error = null;
        _companyData = null;
        _effLaunchPhase = null;
        _showFullAppAfterDedicated = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _user = user;
      _error = null;
      _companyData = null;
      _effLaunchPhase = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _error =
            'Tvoj korisnički profil ne postoji u sistemu.\n'
            'Admin mora prvo odobriti korisnika.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final data = userDoc.data() ?? <String, dynamic>{};

      final status = _s(data['status']).toLowerCase();
      final role = _s(data['role']).toLowerCase();
      final companyId = _companyIdFromUserField(data['companyId']);
      final plantKey = _s(data['plantKey']);

      final rawAppAccess = data['appAccess'];
      final appAccess = rawAppAccess is Map<String, dynamic>
          ? rawAppAccess
          : <String, dynamic>{};

      final canUseProduction = appAccess['production'] == true;

      if (status == 'pending') {
        _error =
            'Vaš zahtjev za registraciju je zaprimljen i čeka odobrenje Admina.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (status != 'active') {
        _error =
            'Tvoj račun nije aktivan (status: "$status").\n'
            'Pristup je zaključan dok Admin ne odobri nalog.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (!canUseProduction) {
        _error =
            'Nemaš odobren pristup za Operonix Production aplikaciju.\n'
            'Admin mora odobriti Production pristup.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (role.isEmpty) {
        _error =
            'U korisničkom profilu nije postavljena uloga.\n'
            'Administrator mora dodijeliti ulogu prije prijave.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (companyId.isEmpty) {
        _error =
            'Korisnik nije povezan s kompanijom.\n'
            'Obrati se administratoru da se profil poveže s tvrtkom.';
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (plantKey.isEmpty) {
        final normRole = ProductionAccessHelper.normalizeRole(role);
        final globalTenantAdmin =
            ProductionAccessHelper.isAdminRole(normRole) ||
                ProductionAccessHelper.isSuperAdminRole(normRole);
        if (!globalTenantAdmin) {
          _error =
              'U profilu nije postavljen pogon (tvornica / lokacija).\n'
              'Administrator mora dodijeliti pogon prije korištenja aplikacije.';
          if (!mounted) return;
          setState(() => _loading = false);
          return;
        }
        // Admin / super_admin u kompaniji: pogon nije obavezan na korisniku —
        // moduli biraju kontekst (Workforce, stanica, spremljeni odabir).
      }

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        _error =
            'Podaci o kompaniji nisu pronađeni. Obrati se administratoru.';
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
        // Maintenance-style plant resolution (report_fault / assets plantKey).
        'userHomePlantKey': _s(data['homePlantKey']),
        'userHomePlantId': _s(data['homePlantId']),
        'userLegacyPlantId': _s(data['plantId']),
        'userAppAccess': appAccess,
        'userDisplayName': _s(data['displayName']),
        'nickname': _s(data['nickname']),
        'userEmail': _s(data['email'] ?? user.email ?? ''),
      };

      try {
        _effLaunchPhase =
            StationLaunchConfig.phaseOrNull ??
            await StationLaunchPreference.getPhaseOptional();
      } catch (_) {
        _effLaunchPhase = StationLaunchConfig.phaseOrNull;
      }

      if (_companyData != null) {
        if (_effLaunchPhase != null) {
          final cid = _s(_companyData!['companyId']);
          final setup = await StationTrackingSetupStore.load(cid);
          final stationBound = setup?.plantKey.trim() ?? '';
          _companyData!['stationBoundPlantKey'] = stationBound;
          _companyData!['stationTrackingClassification'] =
              setup?.classification ?? '';
          _companyData!['stationLabelPrintingEnabled'] =
              setup?.labelPrintingEnabled ?? true;
          _companyData!['stationLabelLayout'] =
              setup?.labelLayoutKey ?? kStationLabelLayoutStandard;
          final userPk = _s(_companyData!['plantKey']);
          if (stationBound.isNotEmpty &&
              userPk.isNotEmpty &&
              stationBound != userPk) {
            _error =
                'Ova stanica je na ovom računalu vezana za jedan pogon, a tvoj korisnik '
                'pripada drugom pogonu.\n\n'
                'Odjavi se i prijavi računom korisnika tog pogona, ili zamoli Admina '
                'da na ovom računalu promijeni pogon stanice.';
            if (!mounted) return;
            setState(() => _loading = false);
            return;
          }
        } else {
          _companyData!['stationBoundPlantKey'] = '';
          final cid = _s(_companyData!['companyId']);
          final localSetup = await StationTrackingSetupStore.load(cid);
          if (localSetup != null) {
            _companyData!['stationTrackingClassification'] =
                localSetup.classification;
            _companyData!['stationLabelPrintingEnabled'] =
                localSetup.labelPrintingEnabled;
            _companyData!['stationLabelLayout'] = localSetup.labelLayoutKey;
          } else {
            _companyData!['stationTrackingClassification'] = '';
            _companyData!['stationLabelPrintingEnabled'] = true;
            _companyData!['stationLabelLayout'] = kStationLabelLayoutStandard;
          }
        }
      }

      if (_companyData != null) {
        await ProductionAdminSessionPlant.applyPreferenceIfAdmin(
          _companyData!,
        );
      }

      _error = null;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await FcmTokenService.instance.initialize();
          await FcmTokenService.instance.syncForUser(user);
        } catch (_) {}
      }
    } catch (e) {
      _error =
          'Greška pri učitavanju korisničkog konteksta.\n'
          'Detalj: $e';
      _effLaunchPhase = null;
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

    if (!_showFullAppAfterDedicated &&
        _effLaunchPhase != null &&
        _companyData != null) {
      final sb = _s(_companyData!['stationBoundPlantKey']);
      if (sb.isEmpty) {
        return StationTrackingSetupScreen(
          companyData: _companyData!,
          onSaved: _refreshSession,
        );
      }
    }

    if (!_showFullAppAfterDedicated && _effLaunchPhase != null) {
      final phase = _effLaunchPhase!;

      void goFullApp() {
        setState(() => _showFullAppAfterDedicated = true);
      }

      if (phase == ProductionOperatorTrackingEntry.phasePreparation) {
        return StationPageActiveGate(
          companyData: _companyData!,
          phase: phase,
          onCloseStation: goFullApp,
          stationBuilder: (_) => ProductionPreparationStationScreen(
            companyData: _companyData!,
            onCloseStation: goFullApp,
            onStationTrackingSetupSaved: _refreshSession,
          ),
        );
      }
      return StationPageActiveGate(
        companyData: _companyData!,
        phase: phase,
        onCloseStation: goFullApp,
        stationBuilder: (_) => ProductionOperatorTrackingStationScreen(
          companyData: _companyData!,
          phase: phase,
          showOperativeSessionStrip: false,
          onCloseStation: goFullApp,
          onStationTrackingSetupSaved: _refreshSession,
        ),
      );
    }

    return ProductionDashboardScreen(
      companyData: _companyData!,
    );
  }
}
