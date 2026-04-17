import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../data/activity_sector_catalog.dart';
import '../services/company_activity_sector_settings_service.dart';

/// Uključivanje/isključivanje djelatnosti koje se prikazuju u filterima i na partneru.
class ActivitySectorSettingsScreen extends StatefulWidget {
  const ActivitySectorSettingsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ActivitySectorSettingsScreen> createState() =>
      _ActivitySectorSettingsScreenState();
}

class _ActivitySectorSettingsScreenState
    extends State<ActivitySectorSettingsScreen> {
  final CompanyActivitySectorSettingsService _service =
      CompanyActivitySectorSettingsService();
  final TextEditingController _search = TextEditingController();

  bool _saving = false;
  String? _error;

  late Set<String> _enabled;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final raw = widget.companyData['enabledActivitySectorCodes'];
    if (raw == null) {
      _enabled = Set<String>.from(activitySectorKnownCodes);
    } else if (raw is List) {
      final codes = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (codes.isEmpty) {
        _enabled = Set<String>.from(activitySectorKnownCodes);
      } else {
        _enabled = codes;
      }
    } else {
      _enabled = Set<String>.from(activitySectorKnownCodes);
    }
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ActivitySectorDef> get _filteredCatalog {
    final q = _search.text.trim().toLowerCase();
    final all = activitySectorCatalogSorted;
    if (q.isEmpty) return all;
    return all
        .where(
          (e) =>
              e.label.toLowerCase().contains(q) ||
              e.code.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _save() async {
    if (_companyId.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveEnabledCodesSmart(
        companyId: _companyId,
        enabledCodes: _enabled,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppErrorMapper.toMessage(e);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nEnabled = _enabled.length;
    final nTotal = kActivitySectorCatalog.length;
    final modeLabel = nEnabled >= nTotal
        ? 'Prikaz: cijeli šifarnik ($nTotal)'
        : 'Prikaz: $nEnabled / $nTotal odabranih';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivne djelatnosti'),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                    _enabled = Set<String>.from(activitySectorKnownCodes);
                  }),
            child: const Text('Uključi sve'),
          ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'Sačuvaj',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saving) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Material(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Logistika / admin: uključi samo djelatnosti koje vam trebaju. '
              'Isključene se neće pojavljivati u filteru liste ni u padajućem izboru na partneru.',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              modeLabel,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Pretraga u šifarniku',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _filteredCatalog.length,
              itemBuilder: (context, i) {
                final e = _filteredCatalog[i];
                final on = _enabled.contains(e.code);
                return SwitchListTile(
                  title: Text(e.label, maxLines: 3),
                  subtitle: Text(
                    e.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                  value: on,
                  onChanged: (v) {
                    if (!v && _enabled.length <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Barem jedna djelatnost mora ostati uključena.',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      if (v) {
                        _enabled.add(e.code);
                      } else {
                        _enabled.remove(e.code);
                      }
                      _error = null;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
