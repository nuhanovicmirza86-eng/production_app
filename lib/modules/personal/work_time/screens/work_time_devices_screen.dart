import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_access.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_operational_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// LAN / kiosk uređaji — [workTimeListDevices] / [workTimeUpsertDevice] (samo admin).
class WorkTimeDevicesScreen extends StatefulWidget {
  const WorkTimeDevicesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeDevicesScreen> createState() => _WorkTimeDevicesScreenState();
}

class _WorkTimeDevicesScreenState extends State<WorkTimeDevicesScreen> {
  final _svc = WorkTimeOperationalService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _err;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _admin => WorkTimeAccess.canOpenTenantAdminScreens(
        ProductionAccessHelper.normalizeRole(widget.companyData['role']),
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final l = await _svc.listDevices(companyId: _companyId);
      if (mounted) {
        setState(() {
          _items = l;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEdit({String? id}) async {
    if (!_admin) {
      return;
    }
    final name = TextEditingController();
    final net = TextEditingController();
    for (final d in _items) {
      if (d['id'] == id) {
        name.text = (d['displayName'] ?? '').toString();
        net.text = (d['networkLabel'] ?? '').toString();
        break;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Novi uređaj' : 'Uređaj'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Naziv (npr. Kiosk 1) *',
                ),
              ),
              TextField(
                controller: net,
                decoration: const InputDecoration(
                  labelText: 'Mrežna oznaka (opis, ne IP u ovom unosu)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) {
      return;
    }
    try {
      await _svc.upsertDevice(
        companyId: _companyId,
        plantKey: _plantKey,
        displayName: name.text.trim(),
        deviceId: id,
        networkLabel: net.text.trim(),
        isActive: true,
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uređaj spremljen (audit zabilježen).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uređaji za evidenciju')),
      floatingActionButton: _admin
          ? FloatingActionButton(
              onPressed: () => unawaited(_openEdit()),
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const WorkTimeDemoBanner(),
                if (_err != null) Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
                Text(
                  'Uređaji se prijavljuju u sustav putem općeg Callable toka (kiosk, gateway). '
                  'Klijent ovdje upravlja isključivo popisom i opisom — ne izravnim IP pristupom u pregledniku.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  const ListTile(
                    title: Text('Nema upisanih uređaja'),
                    subtitle: Text('Dodaj prvi (samo admin tvrtke).'),
                  )
                else
                  for (final d in _items)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.router_outlined),
                        title: Text('${d['displayName'] ?? d['id']}'),
                        subtitle: Text(
                          (d['networkLabel'] ?? '').toString().isEmpty
                              ? 'Aktivnost: ${d['isActive'] == false ? "ne" : "da"}'
                              : d['networkLabel'].toString(),
                        ),
                        trailing: _admin
                            ? const Icon(Icons.edit_outlined)
                            : null,
                        onTap: _admin ? () => unawaited(_openEdit(id: d['id']?.toString())) : null,
                      ),
                    ),
              ],
            ),
    );
  }
}
