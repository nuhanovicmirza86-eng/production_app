import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../production_orders/screens/production_order_details_screen.dart';
import '../models/downtime_event_model.dart';
import '../services/downtime_service.dart';

class DowntimeDetailsScreen extends StatefulWidget {
  const DowntimeDetailsScreen({
    super.key,
    required this.companyData,
    required this.downtimeId,
  });

  final Map<String, dynamic> companyData;
  final String downtimeId;

  @override
  State<DowntimeDetailsScreen> createState() => _DowntimeDetailsScreenState();
}

class _DowntimeDetailsScreenState extends State<DowntimeDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _downtimeService = DowntimeService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.downtime,
  );

  bool get _canVerify =>
      ProductionAccessHelper.canVerifyDowntime(_role);

  bool get _canViewOrders => ProductionAccessHelper.canView(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  void _openProductionOrder(BuildContext context, String orderId) {
    final id = orderId.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionOrderDetailsScreen(
          companyData: widget.companyData,
          productionOrderId: id,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(
    BuildContext context,
    DowntimeEventModel m,
    String status,
  ) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      await _downtimeService.updateStatus(
        downtimeId: m.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUid: u.uid,
        newStatus: status,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status je ažuriran.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  Future<void> _resolve(BuildContext context, DowntimeEventModel m) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = u.displayName?.trim().isNotEmpty == true
        ? u.displayName!.trim()
        : (u.email ?? u.uid);
    try {
      await _downtimeService.resolveDowntime(
        downtimeId: m.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUid: u.uid,
        actorDisplayName: name,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zastoj je označen kao riješen.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  Future<void> _verify(BuildContext context, DowntimeEventModel m) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = u.displayName?.trim().isNotEmpty == true
        ? u.displayName!.trim()
        : (u.email ?? u.uid);
    try {
      await _downtimeService.verifyDowntime(
        downtimeId: m.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUid: u.uid,
        actorDisplayName: name,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zastoj je verificiran.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  Future<void> _rejectDialog(BuildContext context, DowntimeEventModel m) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odbij zastoj'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Razlog odbijanja (opcionalno)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odbij'),
          ),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      return;
    }
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = u.displayName?.trim().isNotEmpty == true
        ? u.displayName!.trim()
        : (u.email ?? u.uid);
    try {
      await _downtimeService.rejectDowntime(
        downtimeId: m.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUid: u.uid,
        actorDisplayName: name,
        noteAppend: ctrl.text.trim(),
      );
      ctrl.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zastoj je odbijen.')),
        );
      }
    } catch (e) {
      ctrl.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(v.isEmpty ? '—' : v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.downtimeId.trim();
    if (id.isEmpty || _companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalji zastoja')),
        body: const Center(child: Text('Nedostaju podaci za učitavanje.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zastoj'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Osnovno'),
            Tab(text: 'Vremenska linija'),
            Tab(text: 'Uzrok / rješenje'),
            Tab(text: 'Povezano'),
            Tab(text: 'Dokazi'),
            Tab(text: 'CAPA'),
            Tab(text: 'Audit'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('downtime_events')
            .doc(id)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(AppErrorMapper.toMessage(snap.error!)));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final m = DowntimeEventModel.fromDoc(snap.data!);
          if (m.companyId != _companyId || m.plantKey != _plantKey) {
            return const Center(
              child: Text('Nemaš pristup ovom zastoju.'),
            );
          }

          final now = DateTime.now();
          final mins = m.effectiveDurationMinutesNow(now);

          return Column(
            children: [
              Material(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_canManage &&
                          DowntimeEventStatus.isOpenLike(m.status)) ...[
                        OutlinedButton(
                          onPressed: m.status == DowntimeEventStatus.open
                              ? () => _setStatus(
                                  context,
                                  m,
                                  DowntimeEventStatus.inProgress,
                                )
                              : null,
                          child: const Text('U tijeku'),
                        ),
                        FilledButton(
                          onPressed: () => _resolve(context, m),
                          child: const Text('Zatvori (riješeno)'),
                        ),
                      ],
                      if (_canManage &&
                          m.status == DowntimeEventStatus.resolved &&
                          _canVerify)
                        FilledButton.tonal(
                          onPressed: () => _verify(context, m),
                          child: const Text('Verifikuj'),
                        ),
                      if (_canManage &&
                          DowntimeEventStatus.isOpenLike(m.status))
                        TextButton(
                          onPressed: () => _rejectDialog(context, m),
                          child: const Text('Odbij'),
                        ),
                      if (_canManage &&
                          m.status != DowntimeEventStatus.archived &&
                          m.status != DowntimeEventStatus.rejected)
                        TextButton(
                          onPressed: () async {
                            final u = FirebaseAuth.instance.currentUser;
                            if (u == null) return;
                            try {
                              await _downtimeService.archiveDowntime(
                                downtimeId: m.id,
                                companyId: _companyId,
                                plantKey: _plantKey,
                                actorUid: u.uid,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppErrorMapper.toMessage(e)),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Arhiviraj'),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.downtimeCode,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                _kv('Status', DowntimeEventStatus.labelHr(m.status)),
                                _kv('Kritičnost', DowntimeSeverity.labelHr(m.severity)),
                                _kv(
                                  'Kategorija',
                                  DowntimeCategoryKeys.labelHr(m.downtimeCategory),
                                ),
                                _kv('Planirani', m.isPlanned ? 'Da' : 'Ne'),
                                _kv(
                                  'OEE / OOE / TEEP',
                                  () {
                                    final f = <String>[
                                      if (m.affectsOee) 'OEE',
                                      if (m.affectsOoe) 'OOE',
                                      if (m.affectsTeep) 'TEEP',
                                    ];
                                    return f.isEmpty ? '—' : f.join(', ');
                                  }(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _kv(
                                  'Početak',
                                  m.startedAt.toLocal().toString(),
                                ),
                                _kv(
                                  'Kraj',
                                  m.endedAt?.toLocal().toString() ?? '—',
                                ),
                                _kv(
                                  'Trajanje (min)',
                                  mins == null ? '—' : '$mins',
                                ),
                                _kv(
                                  'Zapisano trajanje',
                                  m.durationMinutes == null
                                      ? '—'
                                      : '${m.durationMinutes}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _kv('Razlog', m.downtimeReason),
                                _kv('Opis', m.description),
                                _kv(
                                  'CAPA obavezna',
                                  m.correctiveActionRequired ? 'Da' : 'Ne',
                                ),
                                _kv('CAPA ID', m.correctiveActionId),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _kv('Nalog', m.productionOrderCode),
                                _kv('ID naloga', m.productionOrderId),
                                _kv(
                                  'Radni centar',
                                  '${m.workCenterCode} ${m.workCenterName}',
                                ),
                                _kv('Proces', '${m.processCode} ${m.processName}'),
                                _kv('Smjena', m.shiftName.isNotEmpty ? m.shiftName : m.shiftId),
                                if (m.productionOrderId.isNotEmpty && _canViewOrders) ...[
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openProductionOrder(
                                      context,
                                      m.productionOrderId,
                                    ),
                                    icon: const Icon(Icons.assignment_outlined),
                                    label: Text(
                                      m.productionOrderCode.isNotEmpty
                                          ? 'Otvori nalo ${m.productionOrderCode}'
                                          : 'Otvori nalo (detalj)',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: m.attachments.isEmpty
                                ? const Text(
                                    'Nema priloženih dokaza. (Prva verzija — kasnije slike / datoteke.)',
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: m.attachments
                                        .map(
                                          (a) => Text(a.toString()),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Poveznica na korektivne aktivnosti iz Maintenance / QMS modula '
                              'dolazi u sljedećoj iteraciji. Koristite CAPA ID polje ako već postoji u sistemu.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          shape: operonixProductionCardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _kv('Prijavio', '${m.reportedByName} (${m.reportedBy})'),
                                _kv('Operater ID', m.operatorId),
                                _kv('Riješio', '${m.resolvedByName} (${m.resolvedBy})'),
                                _kv('Verificirao', '${m.verifiedByName} (${m.verifiedBy})'),
                                _kv('Kreirano', '${m.createdAt} · ${m.createdBy}'),
                                _kv('Ažurirano', '${m.updatedAt} · ${m.updatedBy}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
