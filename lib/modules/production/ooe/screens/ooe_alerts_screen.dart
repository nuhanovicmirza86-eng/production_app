import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart'
    show ProductionAccessHelper, ProductionDashboardCard;
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../models/ooe_alert.dart';
import '../services/ooe_alert_list_service.dart';
import '../services/ooe_alerts_callable_service.dart';

/// Pregled OOE alarma; evaluacija i potvrde preko Callablea.
class OoeAlertsScreen extends StatefulWidget {
  const OoeAlertsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<OoeAlertsScreen> createState() => _OoeAlertsScreenState();
}

class _OoeAlertsScreenState extends State<OoeAlertsScreen> {
  final _listSvc = OoeAlertListService();
  final _call = OoeAlertsCallableService();
  bool _busy = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canAct => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _eval() async {
    if (!_canAct) return;
    setState(() => _busy = true);
    try {
      final m = await _call.evaluate(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      if (mounted) {
        final o = m['opened'] ?? 0;
        final d = m['autoDismissed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Evaluacija: otvoreno $o, auto-zatvoreno $d.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String alertId, String status) async {
    if (_uid == null) return;
    setState(() => _busy = true);
    try {
      await _call.setStatus(companyId: _companyId, alertId: alertId, status: status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmi učinka'),
        actions: [
          if (_canAct)
            IconButton(
              tooltip: 'Osvježi pragove na poslužitelju',
              onPressed: _busy ? null : _eval,
              icon: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CompanyPlantLabelText(
              companyId: _companyId,
              plantKey: _plantKey,
              prefix: '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<OoeAlert>>(
              stream: _listSvc.watchRecentForPlant(
                companyId: _companyId,
                plantKey: _plantKey,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(AppErrorMapper.toMessage(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nema alarma. Postavi praga u „Pragovi alarma” i evaluiraj (ikona radara).',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    final isOpen = a.status == OoeAlert.statusOpen;
                    return Card(
                      child: ListTile(
                        title: Text(
                          a.message?.trim().isNotEmpty == true
                              ? a.message!
                              : '${a.ruleType} · ${a.machineId}',
                          maxLines: 3,
                        ),
                        subtitle: Text(
                          'Status: ${a.status} · ${a.createdAt ?? a.updatedAt ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: isOpen && _canAct
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _setStatus(
                                              a.id,
                                              OoeAlert.statusAcknowledged,
                                            ),
                                    child: const Text('Priznaj'),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _setStatus(
                                              a.id,
                                              OoeAlert.statusDismissed,
                                            ),
                                    child: const Text('Odbaci'),
                                  ),
                                ],
                              )
                            : null,
                      ),
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
