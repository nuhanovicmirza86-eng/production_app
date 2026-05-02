import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';
import 'development_project_edit_screen.dart';
import 'development_project_team_screen.dart';
import '../widgets/development_project_tasks_section.dart';

/// Korak 5 MVP — pregled projekta (live stream).
class DevelopmentProjectDetailsScreen extends StatelessWidget {
  const DevelopmentProjectDetailsScreen({
    super.key,
    required this.companyData,
    required this.projectId,
  });

  final Map<String, dynamic> companyData;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final service = DevelopmentProjectService();
    final canEditCore = DevelopmentPermissions.canEditDevelopmentProjectCore(
      role: companyData['role']?.toString(),
      companyData: companyData,
    );

    return StreamBuilder<DevelopmentProjectModel?>(
      stream: service.watchProject(projectId),
      builder: (context, snap) {
        final p = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Projekat razvoja'),
            actions: [
              if (canEditCore && p != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Uredi',
                  onPressed: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => DevelopmentProjectEditScreen(
                          companyData: companyData,
                          project: p,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: () {
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Učitavanje nije uspjelo.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (p == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final kpi = p.kpi;
            final ai = p.ai;
            return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                p.projectName.isEmpty ? 'Projekat' : p.projectName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                p.projectCode,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Status i tijek',
                children: [
                  _kv(context, 'Status', DevelopmentDisplay.projectStatusLabel(p.status)),
                  _kv(context, 'Tip', DevelopmentDisplay.projectTypeLabel(p.projectType)),
                  _kv(context, 'Gate', p.currentGate),
                  _kv(context, 'Faza', p.currentStage),
                  _kv(context, 'Napredak', '${p.progressPercent}%'),
                  _kv(context, 'Prioritet', p.priority),
                  _kv(context, 'Rizik', p.riskLevel),
                ],
              ),
              _SectionCard(
                title: 'Poslovna godina',
                children: [
                  _kv(context, 'Godina', p.businessYearLabel.isNotEmpty
                      ? p.businessYearLabel
                      : p.businessYearId),
                  _kv(context, 'Kvartal', p.businessQuarter),
                  _kv(context, 'Mjesec', p.businessMonth),
                  if (p.isCarriedOver)
                    _kv(context, 'Prijenos', 'Da'),
                ],
              ),
              _SectionCard(
                title: 'Tim',
                children: [
                  _kv(context, 'Project Manager', p.projectManagerName),
                  if (p.team.isNotEmpty)
                    ...p.team.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DevelopmentDisplay.teamProjectRoleLabel(m.projectRole)} · ${m.displayName.isEmpty ? m.userId : m.displayName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Uloga: ${m.systemRole} · Zadaci: ${m.canEditTasks ? "da" : "ne"} · '
                              'Dokumenti: ${m.canUploadDocuments ? "da" : "ne"} · Gate: ${m.canApproveGate ? "da" : "ne"}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (p.teamMemberIds.isNotEmpty)
                    _kv(
                      context,
                      'Članovi (ID)',
                      p.teamMemberIds.join(', '),
                    ),
                  if (DevelopmentPermissions.canEditDevelopmentProjectTeam(
                    role: companyData['role']?.toString(),
                    companyData: companyData,
                    project: p,
                    currentUserId: FirebaseAuth.instance.currentUser?.uid,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => DevelopmentProjectTeamScreen(
                                  companyData: companyData,
                                  project: p,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.groups_2_outlined),
                          label: const Text('Uredi tim'),
                        ),
                      ),
                    ),
                ],
              ),
              DevelopmentProjectTasksSection(
                companyData: companyData,
                project: p,
              ),
              if ((p.customerName ?? '').isNotEmpty ||
                  (p.productName ?? '').isNotEmpty)
                _SectionCard(
                  title: 'Kupac / proizvod',
                  children: [
                    if ((p.customerName ?? '').isNotEmpty)
                      _kv(context, 'Kupac', p.customerName!),
                    if ((p.productName ?? '').isNotEmpty)
                      _kv(context, 'Proizvod', p.productName!),
                  ],
                ),
              _SectionCard(
                title: 'Financije',
                children: [
                  _kv(context, 'Valuta', p.currency),
                  if (p.budgetPlanned != null)
                    _kv(context, 'Budžet plan', '${p.budgetPlanned}'),
                  if (p.budgetActual != null)
                    _kv(context, 'Budžet stvarno', '${p.budgetActual}'),
                ],
              ),
              _SectionCard(
                title: 'KPI',
                children: [
                  if (kpi.schedulePerformance != null)
                    _kv(context, 'Schedule perf.', '${kpi.schedulePerformance}'),
                  if (kpi.costPerformance != null)
                    _kv(context, 'Cost perf.', '${kpi.costPerformance}'),
                  if (kpi.qualityReadiness != null)
                    _kv(context, 'Quality readiness', '${kpi.qualityReadiness}'),
                  if (kpi.overallHealthScore != null)
                    _kv(context, 'Health', '${kpi.overallHealthScore}'),
                  if (kpi.schedulePerformance == null &&
                      kpi.costPerformance == null &&
                      kpi.overallHealthScore == null)
                    Text(
                      'KPI će se puniti iz izvršenja i agregata.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              _SectionCard(
                title: 'AI uvidi',
                children: [
                  if (ai.riskPrediction.isNotEmpty)
                    _kv(context, 'Predikcija rizika', ai.riskPrediction),
                  if (ai.delayProbability != null)
                    _kv(context, 'Kašnjenje (vj.)', '${ai.delayProbability}'),
                  if (ai.recommendedActionCount != null)
                    _kv(
                      context,
                      'Preporuke',
                      '${ai.recommendedActionCount}',
                    ),
                  if (ai.riskPrediction.isEmpty && ai.delayProbability == null)
                    Text(
                      'AI analiza još nije pokrenuta.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              _SectionCard(
                title: 'Audit',
                children: [
                  _kv(context, 'Kreirao', p.createdByName),
                  _kv(context, 'Ažurirao', p.updatedBy),
                ],
              ),
            ],
          );
          }(),
        );
      },
    );
  }

  static Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
