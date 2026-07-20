import 'package:flutter/material.dart';

import '../../../modules/auth/shared/services/auth_service.dart';
import '../../../modules/production/station_pages/screens/production_profile_station_launch_screen.dart';
import '../../../modules/production/station_pages/widgets/station_page_active_gate.dart';
import '../../../modules/production/tracking/models/production_operator_tracking_entry.dart';
import '../../../modules/production/tracking/screens/production_operator_tracking_station_screen.dart';
import '../../../modules/production/tracking/screens/production_preparation_station_screen.dart';
import '../services/production_station_terminal_launch_service.dart';

/// M1-G5-F1 — terminal account otvara isključivo dodijeljenu stanicu.
class ProductionStationTerminalRootScreen extends StatefulWidget {
  const ProductionStationTerminalRootScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<ProductionStationTerminalRootScreen> createState() =>
      _ProductionStationTerminalRootScreenState();
}

class _ProductionStationTerminalRootScreenState
    extends State<ProductionStationTerminalRootScreen> {
  final _launchService = ProductionStationTerminalLaunchService();
  final _authService = AuthService();

  bool _loading = true;
  Object? _error;
  ProductionStationTerminalLaunchResult? _launch;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _launchService.resolveLaunch(companyId: _companyId);
      if (!mounted) return;
      setState(() {
        _launch = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _signOutTerminal() async {
    await _authService.signOut();
  }

  Map<String, dynamic> get _sessionCompanyData {
    final launch = _launch!;
    final config = launch.stationConfig;
    final plantKey = config.assignedPlantKey.trim();
    return {
      ...widget.companyData,
      if (plantKey.isNotEmpty) 'plantKey': plantKey,
      'stationTerminalConfigId': launch.assignedStationConfigId,
      'isStationTerminalAccount': true,
    };
  }

  Widget _buildStationBody() {
    final launch = _launch!;
    final companyData = _sessionCompanyData;
    final onCloseStation = _signOutTerminal;

    if (launch.isLegacyPreparation) {
      return StationPageActiveGate(
        companyData: companyData,
        phase: ProductionOperatorTrackingEntry.phasePreparation,
        onCloseStation: onCloseStation,
        stationBuilder: (_) => ProductionPreparationStationScreen(
          companyData: companyData,
          onCloseStation: onCloseStation,
        ),
      );
    }

    if (launch.isLegacyFirstControl) {
      return StationPageActiveGate(
        companyData: companyData,
        phase: ProductionOperatorTrackingEntry.phaseFirstControl,
        onCloseStation: onCloseStation,
        stationBuilder: (_) => ProductionOperatorTrackingStationScreen(
          companyData: companyData,
          phase: ProductionOperatorTrackingEntry.phaseFirstControl,
          onCloseStation: onCloseStation,
        ),
      );
    }

    if (launch.isLegacyFinalControl) {
      return StationPageActiveGate(
        companyData: companyData,
        phase: ProductionOperatorTrackingEntry.phaseFinalControl,
        onCloseStation: onCloseStation,
        stationBuilder: (_) => ProductionOperatorTrackingStationScreen(
          companyData: companyData,
          phase: ProductionOperatorTrackingEntry.phaseFinalControl,
          showOperativeSessionStrip: false,
          onCloseStation: onCloseStation,
        ),
      );
    }

    if (launch.isProfileStation) {
      final profile = launch.profile;
      if (profile == null || !profile.isComplete) {
        return _errorScaffold('Profil stanice nije spreman za rad.');
      }
      return ProductionProfileStationLaunchScreen(
        companyData: companyData,
        stationConfig: launch.stationConfig,
        profile: profile,
        onCloseStation: onCloseStation,
      );
    }

    return _errorScaffold('Stanica nije podržana na terminal accountu.');
  }

  Widget _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal stanice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _signOutTerminal,
              icon: const Icon(Icons.logout),
              label: const Text('Odjavi se'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terminal stanice')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                productionStationTerminalLaunchErrorMessage(_error!),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _signOutTerminal,
                icon: const Icon(Icons.logout),
                label: const Text('Odjavi se'),
              ),
            ],
          ),
        ),
      );
    }

    if (_launch == null) {
      return _errorScaffold('Stanica nije učitana.');
    }

    return _buildStationBody();
  }
}
