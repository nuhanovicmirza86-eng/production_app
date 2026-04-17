import 'package:flutter/material.dart';

import '../models/station_page_gate_result.dart';
import '../services/production_station_page_service.dart';

/// Učitava `production_station_pages` ako postoji; blokira samo ako je zapis **neaktivan**.
/// Nema obaveznog CRUD-a za sve tri stanice.
class StationPageActiveGate extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String phase;
  final Widget Function(BuildContext context) stationBuilder;
  final VoidCallback? onCloseStation;

  const StationPageActiveGate({
    super.key,
    required this.companyData,
    required this.phase,
    required this.stationBuilder,
    this.onCloseStation,
  });

  @override
  State<StationPageActiveGate> createState() => _StationPageActiveGateState();
}

class _StationPageActiveGateState extends State<StationPageActiveGate> {
  final _service = ProductionStationPageService();
  late Future<StationPageGateResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(StationPageActiveGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oc = (oldWidget.companyData['companyId'] ?? '').toString().trim();
    final nc = (widget.companyData['companyId'] ?? '').toString().trim();
    final op = (oldWidget.companyData['plantKey'] ?? '').toString().trim();
    final np = (widget.companyData['plantKey'] ?? '').toString().trim();
    if (oc != nc || op != np || oldWidget.phase != widget.phase) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<StationPageGateResult> _load() {
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
    return _service.checkStationPageForLaunchPhase(
      companyId: cid,
      plantKey: pk,
      phase: widget.phase,
    );
  }

  void _close(BuildContext context) {
    if (widget.onCloseStation != null) {
      widget.onCloseStation!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StationPageGateResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final r = snap.data;
        if (r == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Stanica')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nepoznata greška pri provjeri stanice.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }
        if (r.isAllowed) {
          return widget.stationBuilder(context);
        }
        final msg = r.blockingMessage ?? 'Stanica nije dostupna.';
        return Scaffold(
          appBar: AppBar(title: const Text('Stanica nije dostupna')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      msg,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _close(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    widget.onCloseStation != null ? 'Natrag u aplikaciju' : 'Natrag',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
