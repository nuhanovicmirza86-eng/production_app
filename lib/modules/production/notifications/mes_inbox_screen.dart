import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:production_app/modules/auth/register/screens/pending_users_screen.dart';
import 'package:production_app/modules/development/screens/development_project_details_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_dashboard_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_shift_summary_screen.dart';
import 'package:production_app/modules/production/production_orders/screens/production_order_details_screen.dart';
import 'package:production_app/modules/finance_integrations/screens/finance_ai_assistant_screen.dart';
import 'package:production_app/modules/finance_integrations/screens/finance_controlling_hub_screen.dart';
import 'package:production_app/modules/quality/screens/quality_hub_screen.dart';
import 'package:production_app/modules/quality/screens/ncr_detail_screen.dart';
import 'package:production_app/modules/quality/utils/ncr_open_action_navigation.dart';
import 'package:production_app/modules/production/ai/screens/operonix_ai_operational_briefing_screen.dart';
import 'package:production_app/modules/production/ai/screens/operonix_ai_watchlist_screen.dart';
import 'package:production_app/modules/production/ai/screens/production_ai_hub_screen.dart';

import 'mes_inbox_attention.dart';
import 'mes_inbox_close_without_action_dialog.dart';
import 'mes_inbox_filter_bar.dart';
import 'mes_inbox_presentation.dart';
import 'mes_notification_preferences_screen.dart';
import 'mes_notification_prefs.dart';
import 'open_pending_evidence_verification.dart';

/// In-app inbox za MES matricu — `users/{uid}/mes_inbox`.
class MesInboxScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const MesInboxScreen({super.key, required this.companyData});

  @override
  State<MesInboxScreen> createState() => _MesInboxScreenState();
}

class _MesInboxScreenState extends State<MesInboxScreen> {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  MesInboxListFilter _filter = MesInboxListFilter.unread;
  MesInboxPeriodFilter _period = MesInboxPeriodFilter.all;
  bool _filtersExpanded = false;
  bool _bulkBusy = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Za škart je `entityType` = production_execution; nalog je u [extra.productionOrderId].
  String _productionOrderIdForLink(Map<String, dynamic> m) {
    final et = _s(m['entityType']);
    var id = _s(m['entityId']);
    if (et == 'production_order' && id.isNotEmpty) return id;
    final ex = m['extra'];
    if (ex is Map) {
      final p = _s(ex['productionOrderId']);
      if (p.isNotEmpty) return p;
    }
    return id;
  }

  int _intFromExtra(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  Future<void> _openFinanceAiAssistant(
    BuildContext context,
    Map<String, dynamic> cd,
    Map<String, dynamic> data,
  ) async {
    final ex = data['extra'];
    var by = '';
    var py = 0;
    var pm = 0;
    var pk = '';
    if (ex is Map) {
      by = _s(ex['businessYearId']);
      py = _intFromExtra(ex['periodYear']);
      pm = _intFromExtra(ex['periodMonth']);
      pk = _s(ex['plantKey']);
    }
    if (!context.mounted) return;
    if (by.isEmpty || py < 2000 || pm < 1 || pm > 12) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FinanceControllingHubScreen(companyData: cd),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FinanceAiAssistantScreen(
          companyData: cd,
          businessYearId: by,
          periodYear: py,
          periodMonth: pm,
          plantKey: pk,
        ),
      ),
    );
  }

  Future<void> _openDeepLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final route = _s(data['deepLinkRoute']);
    final cd = widget.companyData;

    if (_s(data['eventCode']) == 'FINANCE_AI_NIGHTLY_DIGEST') {
      await _openFinanceAiAssistant(context, cd, data);
      return;
    }

    switch (route) {
      case 'production_order':
        final orderId = _productionOrderIdForLink(data);
        if (orderId.isNotEmpty) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProductionOrderDetailsScreen(
                companyData: cd,
                productionOrderId: orderId,
              ),
            ),
          );
        }
        break;
      case 'quality_hub':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => QualityHubScreen(companyData: cd),
          ),
        );
        break;
      case 'ncr_detail':
        var ncrId = _s(data['entityId']);
        final nex = data['extra'];
        if (ncrId.isEmpty && nex is Map) {
          ncrId = _s(nex['ncrId']);
        }
        if (ncrId.isNotEmpty) {
          if (nex is Map && _s(nex['actionKind']).isNotEmpty) {
            await openNcrActionFromMesExtra(
              context,
              companyData: cd,
              extra: Map<String, dynamic>.from(nex),
              ncrId: ncrId,
            );
            break;
          }
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => NcrDetailScreen(
                companyData: cd,
                ncrId: ncrId,
              ),
            ),
          );
        } else {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => QualityHubScreen(companyData: cd),
            ),
          );
        }
        break;
      case 'ncr_action_task':
        var ncrIdAction = _s(data['entityId']);
        final exAction = data['extra'];
        if (ncrIdAction.isEmpty && exAction is Map) {
          ncrIdAction = _s(exAction['ncrId']);
        }
        if (ncrIdAction.isNotEmpty) {
          await openNcrActionFromMesExtra(
            context,
            companyData: cd,
            extra: exAction is Map
                ? Map<String, dynamic>.from(exAction)
                : const <String, dynamic>{},
            ncrId: ncrIdAction,
          );
        }
        break;
      case 'evidence_verification':
        await openPendingEvidenceVerification(
          navigator: Navigator.of(context),
          companyData: cd,
          payload: data,
        );
        break;
      case 'ooe_dashboard':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => OoeDashboardScreen(companyData: cd),
          ),
        );
        break;
      case 'pending_users':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const PendingUsersScreen(),
          ),
        );
        break;
      case 'ooe_shift_summary':
        var sid = _s(data['entityId']);
        final ex = data['extra'];
        if (sid.isEmpty && ex is Map) {
          sid = _s(ex['summaryId']);
        }
        if (sid.isNotEmpty) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OoeShiftSummaryScreen(
                companyData: cd,
                initialSummaryDocId: sid,
              ),
            ),
          );
        }
        break;
      case 'development_project':
        var devPid = _s(data['entityId']);
        final dex = data['extra'];
        if (devPid.isEmpty && dex is Map) {
          devPid = _s(dex['developmentProjectId']);
        }
        if (devPid.isNotEmpty) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DevelopmentProjectDetailsScreen(
                companyData: cd,
                projectId: devPid,
              ),
            ),
          );
        }
        break;
      case 'mes_inbox':
        break;
      case 'operonix_ai_watchlist':
        String? alertKey;
        final ox = data['extra'];
        if (ox is Map) {
          alertKey = _s(ox['alertKey']);
          if (alertKey.isEmpty) alertKey = null;
        }
        if (OperonixAiWatchlistScreen.canView(cd)) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OperonixAiWatchlistScreen(
                companyData: cd,
                highlightAlertKey: alertKey,
              ),
            ),
          );
        }
        break;
      case 'operonix_ai_operational_briefing':
        final briefingPlant = _s(data['plantKey']);
        String? plantLabel;
        final bx = data['extra'];
        if (bx is Map) {
          final pl = _s(bx['plantDisplayName']);
          if (pl.isNotEmpty) plantLabel = pl;
        }
        if (OperonixAiOperationalBriefingScreen.canView(cd)) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OperonixAiOperationalBriefingScreen(
                companyData: cd,
                initialPlantKey:
                    briefingPlant.isEmpty ? null : briefingPlant,
                initialPlantLabel: plantLabel,
              ),
            ),
          );
        } else {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProductionAiHubScreen(companyData: cd),
            ),
          );
        }
        break;
      case 'finance_ai_assistant':
        await _openFinanceAiAssistant(context, cd, data);
        break;
      default:
        break;
    }
  }

  Future<void> _markRead(String docId) async {
    if (docId.isEmpty) return;
    final callable = _functions.httpsCallable('markMesInboxRead');
    await callable.call(<String, dynamic>{'inboxDocId': docId});
  }

  DateTime? _createdAt(Map<String, dynamic> data) {
    final v = data['createdAt'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Future<void> _markVisibleRead({
    required int unreadCount,
  }) async {
    if (_bulkBusy || unreadCount <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Označi sve kao pročitano'),
          content: const Text(
            'Sve vidljive obavijesti u ovom filteru i periodu bit će '
            'označene kao pročitane. Akcije ostaju otvorene dok se posao '
            'ne završi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Odustani'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Označi'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final callable = _functions.httpsCallable('markMesInboxReadBulk');
      final result = await callable.call(<String, dynamic>{
        'listFilter': MesInboxPresentation.listFilterWireValue(_filter),
        'period': MesInboxPresentation.periodWireValue(_period),
      });
      final data = result.data;
      var marked = 0;
      if (data is Map) {
        final n = data['markedCount'];
        if (n is int) marked = n;
        if (n is num) marked = n.toInt();
      }
      if (!mounted) return;
      final msg = marked == 0
          ? 'Nema nepročitanih obavijesti u ovom prikazu.'
          : marked == 1
              ? 'Označena 1 obavijest kao pročitano.'
              : 'Označeno $marked obavijesti kao pročitano.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on FirebaseFunctionsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obavijesti nisu označene kao pročitane.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obavijesti nisu označene kao pročitane.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _closeWithoutAction(
    BuildContext context,
    String docId,
  ) async {
    if (docId.isEmpty) return;
    final reason = await showMesInboxCloseWithoutActionDialog(context);
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      final callable = _functions.httpsCallable('closeMesInboxWithoutAction');
      await callable.call(<String, dynamic>{
        'inboxDocId': docId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final msg = (e.message ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty ? 'Zatvaranje bez akcije nije uspjelo.' : msg,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zatvaranje bez akcije nije uspjelo.')),
      );
    }
  }

  Future<void> _acknowledge(
    BuildContext context,
    String docId,
  ) async {
    if (docId.isEmpty) return;
    try {
      final callable = _functions.httpsCallable('ackMesInboxItem');
      await callable.call(<String, dynamic>{'inboxDocId': docId});
    } on FirebaseFunctionsException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Potvrda nije uspjela.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Potvrda nije uspjela.')),
      );
    }
  }

  Widget _filterBar() {
    return MesInboxFilterBar(
      filter: _filter,
      period: _period,
      expanded: _filtersExpanded,
      onToggle: () {
        setState(() => _filtersExpanded = !_filtersExpanded);
      },
      onFilterSelected: (filter) {
        setState(() => _filter = filter);
      },
      onPeriodSelected: (period) {
        setState(() => _period = period);
      },
    );
  }

  Widget _actionGuideBlock(ThemeData theme, MesInboxActionGuide guide) {
    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line('Šta treba', guide.need),
          line('Odgovornost', guide.owner),
          line('Sljedeći korak', guide.nextStep),
          line('Završeno kad', guide.doneWhen),
        ],
      ),
    );
  }

  Widget _inboxCard({
    required ThemeData theme,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> data,
    required MesInboxVisibleCopy copy,
  }) {
    final needsAck = data['requiresAction'] == true;
    final acked = data['acknowledgedAt'] != null;
    final accent = copy.waitingAction || !copy.isRead
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final statusColor = copy.waitingAction || !copy.isRead
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      elevation: copy.isRead ? 0 : 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          try {
            await _markRead(doc.id);
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Obavijest nije označena kao pročitana.'),
              ),
            );
          }
          if (!mounted) return;
          await _openDeepLink(context, data);
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              copy.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: copy.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            copy.readLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.body,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (copy.repeatLabel.isNotEmpty ||
                          copy.lastCheckLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (copy.repeatLabel.isNotEmpty)
                          Text(
                            copy.repeatLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (copy.lastCheckLabel.isNotEmpty)
                          Text(
                            copy.lastCheckLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                      if (copy.actionGuide != null) ...[
                        const SizedBox(height: 10),
                        _actionGuideBlock(theme, copy.actionGuide!),
                      ],
                      if (copy.canCloseWithoutAction) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _closeWithoutAction(context, doc.id),
                            child: const Text('Nije potrebna akcija'),
                          ),
                        ),
                      ],
                      if (copy.closedWithoutAction) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Zatvoreno bez akcije',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (needsAck && acked) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Potvrđeno',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (needsAck && !acked)
                IconButton(
                  tooltip: 'Potvrdi',
                  icon: const Icon(Icons.task_alt_outlined),
                  onPressed: () => _acknowledge(context, doc.id),
                )
              else if (needsAck && acked)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Nisi prijavljen.')),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('mes_inbox')
        .orderBy('createdAt', descending: true)
        .limit(200);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obavijesti (MES)'),
        actions: [
          IconButton(
            tooltip: 'Postavke obavijesti',
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const MesNotificationPreferencesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final prefs = MesNotificationPrefs.fromUser(
                  userSnap.data?.data(),
                );
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Obavijesti se nisu mogle učitati.'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nema obavijesti.'),
                  );
                }
                final visible = <({
                  QueryDocumentSnapshot<Map<String, dynamic>> doc,
                  Map<String, dynamic> data,
                  MesInboxVisibleCopy copy,
                })>[];
                for (final d in docs) {
                  final m = d.data();
                  if (!MesInboxAttention.isVisibleInThisApp(m)) continue;
                  if (!prefs.allowsRow(m)) continue;
                  final copy = MesInboxPresentation.fromRow(m);
                  if (!MesInboxPresentation.matchesFilter(_filter, copy)) {
                    continue;
                  }
                  if (!MesInboxPresentation.matchesPeriod(
                    _period,
                    _createdAt(m),
                  )) {
                    continue;
                  }
                  visible.add((doc: d, data: m, copy: copy));
                }
                final unreadCount =
                    visible.where((row) => !row.copy.isRead).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _bulkBusy || unreadCount == 0
                              ? null
                              : () => _markVisibleRead(unreadCount: unreadCount),
                          icon: _bulkBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.done_all),
                          label: const Text('Označi sve kao pročitano'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text(
                                'Nema obavijesti za odabrani filter i period.',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 16),
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final row = visible[i];
                                return _inboxCard(
                                  theme: theme,
                                  doc: row.doc,
                                  data: row.data,
                                  copy: row.copy,
                                );
                              },
                            ),
                    ),
                  ],
                );
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
