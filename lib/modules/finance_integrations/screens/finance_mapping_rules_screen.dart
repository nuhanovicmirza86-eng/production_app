import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_mapping_rules_service.dart';

class FinanceMappingRulesScreen extends StatelessWidget {
  const FinanceMappingRulesScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context) {
    final svc = FinanceMappingRulesService();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapiranja Operonix → ERP'),
      ),
      body: StreamBuilder(
        stream: svc.watchRules(companyId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nema pravila mapiranja. '
                  'Backend i Callables dodaju zapise u `finance_mapping_rules` kada se konfigurira konektor.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final u = r.updatedAt;
              return ListTile(
                isThreeLine: true,
                leading: Icon(
                  r.enabled ? Icons.rule_folder_outlined : Icons.block,
                ),
                title: Text(
                  r.ruleType.isNotEmpty
                      ? r.ruleType
                      : '${r.sourceEntityType} → ${r.targetEntityType}',
                ),
                subtitle: Text(
                  '${r.sourceEntityType} → ${r.targetEntityType}'
                  '${r.connectionId.isNotEmpty ? '\nveza ${r.connectionId}' : ''}'
                  '\nprio ${r.priority} · ${_labelEnabled(r.enabled)}'
                  '${u != null ? ' · ${df.format(u)}' : ''}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _labelEnabled(bool v) => v ? 'aktivno' : 'isključeno';
}
