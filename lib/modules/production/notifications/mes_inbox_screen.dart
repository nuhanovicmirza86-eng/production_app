import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:production_app/modules/auth/register/screens/pending_users_screen.dart';
import 'package:production_app/modules/development/screens/development_project_details_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_dashboard_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_shift_summary_screen.dart';
import 'package:production_app/modules/production/production_orders/screens/production_order_details_screen.dart';
import 'package:production_app/modules/quality/screens/quality_hub_screen.dart';

import 'mes_notification_preferences_screen.dart';

/// In-app inbox za MES matricu — `users/{uid}/mes_inbox`.
class MesInboxScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const MesInboxScreen({super.key, required this.companyData});

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

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

  Future<void> _openDeepLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final route = _s(data['deepLinkRoute']);
    final cd = companyData;

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
      default:
        break;
    }
  }

  Future<void> _markRead(String docId) async {
    if (docId.isEmpty) return;
    final callable = _functions.httpsCallable('markMesInboxRead');
    await callable.call(<String, dynamic>{'inboxDocId': docId});
  }

  Future<void> _acknowledge(
    BuildContext context,
    String docId,
  ) async {
    if (docId.isEmpty) return;
    try {
      final callable = _functions.httpsCallable('ackMesInboxItem');
      await callable.call(<String, dynamic>{'inboxDocId': docId});
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Potvrda nije uspjela: ${e.message}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Potvrda nije uspjela: $e')),
      );
    }
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Greška: ${snap.error}'));
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
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final title = _s(m['title']).isEmpty
                  ? _s(m['eventCode'])
                  : _s(m['title']);
              final body = _s(m['body']);
              final sev = _s(m['severity']);
              final read = m['readAt'] != null;
              final needsAck = m['requiresAction'] == true;
              final acked = m['acknowledgedAt'] != null;
              final eventCode = _s(m['eventCode']);

              return ListTile(
                title: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (sev.isNotEmpty) sev,
                        if (eventCode.isNotEmpty) eventCode,
                        body,
                      ].where((e) => e.isNotEmpty).join(' — '),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (needsAck && acked)
                      const Text(
                        'Potvrđeno',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                trailing: SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!read)
                        const Icon(Icons.circle, size: 10, color: Colors.teal),
                      if (needsAck && !acked)
                        IconButton(
                          tooltip: 'Potvrdi (ack)',
                          icon: const Icon(Icons.task_alt_outlined),
                          onPressed: () => _acknowledge(context, d.id),
                        ),
                      if (needsAck && acked)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 22,
                        ),
                    ],
                  ),
                ),
                onTap: () async {
                  await _markRead(d.id);
                  if (!context.mounted) return;
                  await _openDeepLink(context, m);
                },
              );
            },
          );
        },
      ),
    );
  }
}
