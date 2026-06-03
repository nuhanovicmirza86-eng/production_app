import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/user_display_label.dart';
import '../../../finance_integrations/models/finance_downtime_event_cost_doc.dart';
import '../../../finance_integrations/services/finance_derived_aggregates_service.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
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
  final _derivedFinance = FinanceDerivedAggregatesService();
  String? _prefetchedUsersForEventId;
  String? _costsLoadedForEventId;
  Future<List<FinanceDowntimeEventCostDoc>>? _costsFuture;

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

  Future<List<FinanceDowntimeEventCostDoc>> _costsForEvent(
    DowntimeEventModel m,
  ) {
    if (_costsLoadedForEventId != m.id || _costsFuture == null) {
      _costsLoadedForEventId = m.id;
      _costsFuture = _derivedFinance.fetchDowntimeEventCosts(
        companyId: _companyId,
        downtimeEventId: m.id,
      );
    }
    return _costsFuture!;
  }

  void _ensureUsersPrefetched(DowntimeEventModel m) {
    if (_prefetchedUsersForEventId == m.id) return;
    _prefetchedUsersForEventId = m.id;
    UserDisplayLabel.prefetchUids(FirebaseFirestore.instance, [
      m.operatorId,
      m.reportedBy,
      m.resolvedBy,
      m.verifiedBy,
      m.createdBy,
      m.updatedBy,
    ]).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _auditTimestampLine(DateTime? at, String storedActor) {
    if (at == null) return '—';
    final when = BaFormattedDate.formatDateTime(at);
    final who = UserDisplayLabel.personLine('', storedActor);
    if (who == '—') return when;
    return '$when · $who';
  }

  String _linkedRecordLabel(String stored) {
    final t = stored.trim();
    if (t.isEmpty) return '—';
    if (UserDisplayLabel.looksLikeFirebaseUid(t)) {
      return 'Povezano u sustavu';
    }
    return t;
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
          _ensureUsersPrefetched(m);

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
                                  'Utjecaj na mjere učinka',
                                  () {
                                    final f = <String>[
                                      if (m.affectsOee) 'iskoristivost resursa',
                                      if (m.affectsOoe) 'učinak s gubicima',
                                      if (m.affectsTeep) 'cijeli planirani fond',
                                    ];
                                    return f.isEmpty ? '—' : f.join(', ');
                                  }(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (FinancePermissions.canViewControllingAnalytics(
                          companyData: widget.companyData,
                          role: _role,
                        )) ...[
                          const SizedBox(height: 12),
                          FutureBuilder<List<FinanceDowntimeEventCostDoc>>(
                            future: _costsForEvent(m),
                            builder: (context, costSnap) {
                              if (costSnap.hasError) {
                                return Card(
                                  shape: operonixProductionCardShape(),
                                  child: ListTile(
                                    title: const Text(
                                      'Procjena troška (controlling)',
                                    ),
                                    subtitle: Text(
                                      AppErrorMapper.toMessage(
                                        costSnap.error!,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (!costSnap.hasData) {
                                return Card(
                                  shape: operonixProductionCardShape(),
                                  child: const ListTile(
                                    title: Text(
                                      'Procjena troška (controlling)',
                                    ),
                                    subtitle: Text('Učitavanje…'),
                                  ),
                                );
                              }
                              final costs = costSnap.data!;
                              if (costs.isEmpty) {
                                return Card(
                                  shape: operonixProductionCardShape(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Procjena troška (controlling)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Još nema agregata za ovaj zastoj. '
                                          'Nakon preračuna financijskog KPI-ja za '
                                          'odgovarajući mjesec pojavit će se procjena '
                                          '(OEE minute u periodu × satnica).',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final loc =
                                  Localizations.localeOf(context).toString();
                              final fmt = NumberFormat.decimalPattern(loc);
                              return Card(
                                shape: operonixProductionCardShape(),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Procjena troška (controlling)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      ...costs.map(
                                        (d) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${d.periodYear}-${d.periodMonth.toString().padLeft(2, '0')} · '
                                                  '${d.oeeMinutesInPeriod} min zastoja (OEE)',
                                                ),
                                              ),
                                              Text(
                                                '${fmt.format(d.estimatedDowntimeCost)} ${d.baseCurrency}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
                                  BaFormattedDate.formatDateTime(m.startedAt),
                                ),
                                _kv(
                                  'Kraj',
                                  m.endedAt != null
                                      ? BaFormattedDate.formatDateTime(
                                          m.endedAt!,
                                        )
                                      : '—',
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
                                if (m.correctiveActionId.isNotEmpty)
                                  _kv(
                                    'Povezana CAPA',
                                    _linkedRecordLabel(m.correctiveActionId),
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
                                  'Nalog',
                                  m.productionOrderCode.isNotEmpty
                                      ? m.productionOrderCode
                                      : '—',
                                ),
                                _kv(
                                  'Radni centar',
                                  '${m.workCenterCode} ${m.workCenterName}'
                                      .trim(),
                                ),
                                _kv(
                                  'Proces',
                                  '${m.processCode} ${m.processName}'.trim(),
                                ),
                                _kv(
                                  'Smjena',
                                  m.shiftName.isNotEmpty ? m.shiftName : '—',
                                ),
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
                              'dolazi u sljedećoj iteraciji. Referenca se veže na kartici Uzrok / rješenje.',
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
                                  'Prijavio',
                                  UserDisplayLabel.personLine(
                                    m.reportedByName,
                                    m.reportedBy,
                                  ),
                                ),
                                _kv(
                                  'Operater',
                                  UserDisplayLabel.personLine(
                                    '',
                                    m.operatorId,
                                  ),
                                ),
                                _kv(
                                  'Riješio',
                                  UserDisplayLabel.personLine(
                                    m.resolvedByName,
                                    m.resolvedBy,
                                  ),
                                ),
                                _kv(
                                  'Verificirao',
                                  UserDisplayLabel.personLine(
                                    m.verifiedByName,
                                    m.verifiedBy,
                                  ),
                                ),
                                _kv(
                                  'Kreirano',
                                  _auditTimestampLine(m.createdAt, m.createdBy),
                                ),
                                _kv(
                                  'Ažurirano',
                                  _auditTimestampLine(m.updatedAt, m.updatedBy),
                                ),
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
