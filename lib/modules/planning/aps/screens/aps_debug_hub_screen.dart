import 'package:flutter/material.dart';

import 'aps_debug_hub_shared_state.dart';
import 'aps_p0_debug_screen.dart';
import 'aps_p1_debug_screen.dart';
import 'aps_p2_debug_screen.dart';

/// Interni APS debug hub — P0 master data + P1 scenariji + P2 schedule.
///
/// Ulaz: Registracije → bug ikona. Callable-only smoke testovi.
///
/// Zajedničko stanje ([ApsDebugHubSharedState]) preživljava promjenu tabova.
class ApsDebugHubScreen extends StatefulWidget {
  const ApsDebugHubScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ApsDebugHubScreen> createState() => _ApsDebugHubScreenState();
}

class _ApsDebugHubScreenState extends State<ApsDebugHubScreen> {
  final ApsDebugHubSharedState _shared = ApsDebugHubSharedState();

  void _onSharedStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('APS Debug / Internal'),
          backgroundColor: Colors.orange.shade900,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'P0 Master data'),
              Tab(text: 'P1 Scenarios'),
              Tab(text: 'P2 Schedule'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_shared.hasScenarioId || _shared.lastDemandId.isNotEmpty)
              Material(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _sharedContextLine(),
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  ApsP0DebugScreen(companyData: widget.companyData, embedInHub: true),
                  ApsP1DebugScreen(
                    companyData: widget.companyData,
                    embedInHub: true,
                    sharedState: _shared,
                    onSharedStateChanged: _onSharedStateChanged,
                  ),
                  ApsP2DebugScreen(
                    companyData: widget.companyData,
                    embedInHub: true,
                    sharedState: _shared,
                    onSharedStateChanged: _onSharedStateChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sharedContextLine() {
    final parts = <String>[];
    if (_shared.lastDemandId.isNotEmpty) {
      parts.add('demand: ${_short(_shared.lastDemandId)}');
    }
    if (_shared.lastScenarioId.isNotEmpty) {
      parts.add('scenario: ${_short(_shared.lastScenarioId)}');
    }
    if (_shared.lastScenarioItemId.isNotEmpty) {
      parts.add('item: ${_short(_shared.lastScenarioItemId)}');
    }
    if (_shared.lastScheduleRunId.isNotEmpty) {
      parts.add('run: ${_short(_shared.lastScheduleRunId)}');
    }
    if (_shared.lastPlanningInputSnapshotId.isNotEmpty) {
      parts.add('snapshot: ${_short(_shared.lastPlanningInputSnapshotId)}');
    }
    if (_shared.lastOptimizationRunId.isNotEmpty) {
      parts.add('optRun: ${_short(_shared.lastOptimizationRunId)}');
    }
    return 'Hub shared — ${parts.join(' · ')}';
  }

  String _short(String id) {
    if (id.length <= 14) return id;
    return '${id.substring(0, 10)}…';
  }
}
