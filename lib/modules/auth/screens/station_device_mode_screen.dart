import 'package:flutter/material.dart';

import '../../../core/station_launch_config.dart';
import '../../../core/station_launch_preference.dart';

/// Lokalna postavka uređaja: nakon prijave cijela aplikacija ili jedna stanica.
/// Vidljivo samo korisniku s ulogom Admin u firmi (ne Super admin; ne na ekranu prijave).
class StationDeviceModeScreen extends StatefulWidget {
  const StationDeviceModeScreen({super.key});

  @override
  State<StationDeviceModeScreen> createState() =>
      _StationDeviceModeScreenState();
}

class _StationDeviceModeScreenState extends State<StationDeviceModeScreen> {
  String _mode = StationLaunchPreference.modeFull;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await StationLaunchPreference.getModeRaw();
      if (!mounted) return;
      setState(() {
        _mode = m;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _setMode(String? v) async {
    if (v == null) return;
    setState(() => _mode = v);
    await StationLaunchPreference.setMode(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Postavka je spremljena na ovom uređaju.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildOverrides = StationLaunchConfig.isDedicatedLaunch;

    return Scaffold(
      appBar: AppBar(title: const Text('Način rada na ovom uređaju')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Određuje što se nakon prijave otvara na ovom računalu ili tabletu '
            '(ne za cijelu firmu). Postavku može mijenjati samo uloga Admin u tvrtki.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          if (buildOverrides) ...[
            Material(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'U ovom buildu postavljen je OPERONIX_STATION (${StationLaunchConfig.phaseOrNull ?? "?"}) '
                  '— ta vrijednost ima prednost i lokalni odabir ispod se ne primjenjuje '
                  'dok god je isti exe / web build.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_loaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Način rada nakon prijave',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _mode,
                  items: const [
                    DropdownMenuItem(
                      value: StationLaunchPreference.modeFull,
                      child: Text('Cijela aplikacija'),
                    ),
                    DropdownMenuItem(
                      value: StationLaunchPreference.modePreparation,
                      child: Text('Stanica 1 — pripremna'),
                    ),
                    DropdownMenuItem(
                      value: StationLaunchPreference.modeFirstControl,
                      child: Text('Stanica 2 — prva kontrola'),
                    ),
                    DropdownMenuItem(
                      value: StationLaunchPreference.modeFinalControl,
                      child: Text('Stanica 3 — završna kontrola'),
                    ),
                  ],
                  onChanged: buildOverrides ? null : _setMode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Postavka je lokalna (SharedPreferences). '
              'Za IT nadjačavanje na cijelom buildu vidi OPERONIX_STATION u dokumentaciji / buildu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
