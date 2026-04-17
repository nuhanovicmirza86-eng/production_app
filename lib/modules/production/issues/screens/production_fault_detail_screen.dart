import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/production_fault_operator_service.dart';

/// Pregled jedne prijave kvara (Maintenance `faults`) iz Production app-a.
class ProductionFaultDetailScreen extends StatefulWidget {
  const ProductionFaultDetailScreen({
    super.key,
    required this.companyData,
    required this.faultId,
  });

  final Map<String, dynamic> companyData;
  final String faultId;

  @override
  State<ProductionFaultDetailScreen> createState() =>
      _ProductionFaultDetailScreenState();
}

class _ProductionFaultDetailScreenState extends State<ProductionFaultDetailScreen> {
  final _cancelService = ProductionFaultOperatorService();
  bool _cancelling = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  String get _companyId => _s(widget.companyData['companyId']);

  String get _uid {
    final authUid = _s(FirebaseAuth.instance.currentUser?.uid);
    if (authUid.isNotEmpty) return authUid;
    return _s(widget.companyData['userId']);
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return 'OTVOREN';
      case 'in_progress':
        return 'U TOKU';
      case 'closed':
        return 'ZATVOREN';
      case 'cancelled':
        return 'OTKAZAN';
      default:
        return status.trim().isEmpty ? '-' : status.toUpperCase();
    }
  }

  String _fmt(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate().toLocal();
      return d.toString().substring(0, 16);
    }
    return '-';
  }

  String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final t = _s(v);
      if (t.isNotEmpty) return t;
    }
    return fallback;
  }

  /// Prikaz bez assetId/deviceId — isto kao na assetu (primary / secondary / deviceName).
  String _deviceDisplayTitle(Map<String, dynamic> d) {
    final primary = _s(d['assetPrimaryName']);
    final secondary = _s(d['assetSecondaryName']);
    final dn = _s(d['deviceName']);
    if (primary.isNotEmpty && secondary.isNotEmpty) {
      return '$primary — $secondary';
    }
    if (primary.isNotEmpty) return primary;
    if (secondary.isNotEmpty) return secondary;
    if (dn.isNotEmpty) return dn;
    return 'Uređaj';
  }

  String _plantUiLabel(Map<String, dynamic> d) {
    final code = _firstNonEmpty([d['plantCode'], d['companyPlantCode']]);
    final display = _firstNonEmpty([
      d['plantDisplayName'],
      d['companyPlantDisplayName'],
      d['plantSecondaryName'],
      d['plantName'],
    ]);
    if (code.isNotEmpty && display.isNotEmpty) return '$code — $display';
    if (display.isNotEmpty) return display;
    if (code.isNotEmpty) return code;
    return _s(d['plantKey']);
  }

  DateTime? _entryTime(Map<String, dynamic> e) {
    for (final key in ['at', 'timestamp', 'createdAt', 'time']) {
      final v = e[key];
      if (v is Timestamp) return v.toDate();
    }
    return null;
  }

  String _auditTitle(Map<String, dynamic> e) {
    return _firstNonEmpty([
      e['type'],
      e['eventType'],
      e['action'],
      e['title'],
    ], fallback: 'Zapis');
  }

  /// Prikaz: displayName / nickname s `users/{uid}`, inače email s prijave — bez UID-a.
  List<Widget> _buildCreatorSection(Map<String, dynamic> d) {
    final email = _s(d['createdByEmail']);
    final creatorUid = _s(d['createdByUid']);
    if (creatorUid.isEmpty) {
      return [
        _kv('Kreator', email.isNotEmpty ? email : '—'),
      ];
    }
    return [
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(creatorUid)
            .get(),
        builder: (context, userSnap) {
          var display = '';
          if (userSnap.hasData &&
              userSnap.data != null &&
              userSnap.data!.exists) {
            final u = userSnap.data!.data() ?? {};
            display = _firstNonEmpty([
              u['displayName'],
              u['nickname'],
            ]);
          }
          final who = display.isNotEmpty
              ? display
              : (email.isNotEmpty ? email : '—');
          final sub =
              display.isNotEmpty && email.isNotEmpty && display != email
                  ? email
                  : '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Kreator', who),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 120, bottom: 6),
                  child: Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  Widget _kv(String k, String v) {
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  bool _canCancelOwnOpen(Map<String, dynamic> d) {
    final status = _s(d['status']).toLowerCase();
    final createdBy = _s(d['createdByUid']);
    final takenBy = _s(d['takenByUid']);
    return status == 'open' &&
        createdBy == _uid &&
        takenBy.isEmpty &&
        _companyId.isNotEmpty;
  }

  Future<void> _confirmCancel() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Otkaži prijavu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Otkaz je moguć samo dok je kvar OTVOREN i prije nego ga održavanje preuzme.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Razlog (opcionalno)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ne'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Otkaži'),
            ),
          ],
        );
      },
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (ok != true || !mounted) {
      return;
    }

    setState(() => _cancelling = true);
    try {
      await _cancelService.cancelOwnOpenFault(
        faultId: widget.faultId,
        expectedCompanyId: _companyId,
        cancelReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prijava je otkazana.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ne mogu otkazati: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('faults')
        .doc(widget.faultId.trim());

    return Scaffold(
      appBar: AppBar(title: const Text('Detalj prijave kvara')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Greška: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snap.data!;
          if (!doc.exists) {
            return const Center(child: Text('Kvar nije pronađen.'));
          }
          final d = doc.data() ?? <String, dynamic>{};
          final createdBy = _s(d['createdByUid']);
          if (createdBy != _uid) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nemate pristup ovom kvaru.'),
              ),
            );
          }

          final title = _deviceDisplayTitle(d);
          final status = _s(d['status']);
          final photoUrl = _s(d['photoUrl']);
          final workOrderId = _s(d['workOrderId']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                title.isEmpty ? 'Kvar' : title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: doc.id));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Interna referenca kopirana (za podršku).',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Kopiraj referencu za podršku'),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dugi ID se ne prikazuje u UI — samo kopiranje ako treba podršci.',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const SizedBox(height: 8),
              Text('Status: ${_statusLabel(status)}'),
              const SizedBox(height: 6),
              Text('Tip: ${_s(d['faultType'])}'),
              const SizedBox(height: 6),
              Text('Pogon: ${_plantUiLabel(d)}'),
              const SizedBox(height: 12),
              const Text(
                'Uređaj',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _deviceDisplayTitle(d),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _kv('Pantheon', _s(d['pantheonCode'])),
              _kv('Lokacija', _s(d['locationPath'])),
              _kv('Radi', d['isRunningReported'] == true ? 'Da' : 'Ne'),
              const SizedBox(height: 12),
              const Text(
                'Opis',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(_s(d['description']).isEmpty ? '-' : _s(d['description'])),
              const SizedBox(height: 12),
              Text('Kreirano: ${_fmt(d['createdAt'])}'),
              const SizedBox(height: 8),
              ..._buildCreatorSection(d),
              if (_s(d['cancelReason']).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Razlog otkaza: ${_s(d['cancelReason'])}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (photoUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Slika',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    height: 220,
                    width: double.infinity,
                    webHtmlElementStrategy: kIsWeb
                        ? WebHtmlElementStrategy.prefer
                        : WebHtmlElementStrategy.never,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, _, _) => const Text(
                      'Slika se ne može učitati (URL / CORS / mreža).',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              if (_s(d['maintenanceNote']).isNotEmpty ||
                  _s(d['takenByUid']).isNotEmpty ||
                  _s(d['closedByUid']).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Održavanje',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _kv('Napomena', _s(d['maintenanceNote'])),
                _kv('Preuzeo', _s(d['takenByEmail'])),
                _kv('Preuzeto', _fmt(d['takenAt'])),
                _kv('Zatvorio', _s(d['closedByEmail'])),
                _kv('Zatvoreno', _fmt(d['closedAt'])),
              ],
              if (workOrderId.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Radni nalog',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: workOrderId));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ID radnog naloga kopiran.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Kopiraj vezu na radni nalog (ID)'),
                ),
              ],
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref.collection('audit_log').limit(40).snapshots(),
                builder: (context, auditSnap) {
                  if (auditSnap.hasError) {
                    return Text(
                      'Dnevnik: nije dostupan (${auditSnap.error})',
                      style: const TextStyle(color: Colors.black54),
                    );
                  }
                  if (!auditSnap.hasData) {
                    return const SizedBox.shrink();
                  }
                  final entries = auditSnap.data!.docs
                      .map((x) => x.data())
                      .toList(growable: false);
                  if (entries.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  entries.sort((a, b) {
                    final da = _entryTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final db = _entryTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return db.compareTo(da);
                  });
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dnevnik promjena',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...entries.map((e) {
                        final when = _entryTime(e);
                        final whenStr = when != null
                            ? when.toLocal().toString().substring(0, 16)
                            : '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text(_auditTitle(e)),
                            subtitle: Text(
                              '$whenStr\n${_s(e['message']).isNotEmpty ? _s(e['message']) : _s(e['details'])}',
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_canCancelOwnOpen(d))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _confirmCancel,
                    icon: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(_cancelling ? 'Otkazujem…' : 'Otkaži prijavu'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
