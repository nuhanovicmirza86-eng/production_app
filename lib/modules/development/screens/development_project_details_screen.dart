import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';
import 'development_project_edit_screen.dart';
import 'development_project_team_screen.dart';
import '../widgets/development_project_documents_section.dart';
import '../widgets/development_project_approvals_section.dart';
import '../widgets/development_project_changes_section.dart';
import '../widgets/development_project_release_readiness_section.dart';
import '../widgets/development_project_risks_section.dart';
import '../widgets/development_project_stages_section.dart';
import '../widgets/development_project_tasks_section.dart';

Future<void> _promptCloseDevelopmentProject(
  BuildContext context, {
  required Map<String, dynamic> companyData,
  required DevelopmentProjectModel project,
}) async {
  final companyId = (companyData['companyId'] ?? '').toString().trim();
  final plantKey = (companyData['plantKey'] ?? '').toString().trim();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Zatvori projekat'),
      content: Text(
        'Formalno zatvaranje (status „zatvoren”). '
        'Voditelj projekta može zatvoriti tek kad je status aktivnosti „završen”. '
        'Nastaviti za „${project.projectCode}”?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zatvori')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Zatvaram projekat…')),
        ],
      ),
    ),
  );
  try {
    final service = DevelopmentProjectService();
    await service.closeProjectViaCallable(
      companyId: companyId,
      plantKey: plantKey,
      projectId: project.id,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projekat je formalno zatvoren.')),
      );
    }
  } on FirebaseFunctionsException catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      final m = e.message?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (m != null && m.isNotEmpty) ? m : e.toString(),
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zatvaranje: $e')),
      );
    }
  }
}

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
                  if (p.releasedToProductionAt != null) ...[
                    _kv(
                      context,
                      'Release u proizvodnju',
                      p.releasedToProductionGate?.isNotEmpty == true
                          ? p.releasedToProductionGate!
                          : 'Da',
                    ),
                    _kv(
                      context,
                      'Release (datum)',
                      p.releasedToProductionAt!.toLocal().toString(),
                    ),
                    if ((p.releasedToProductionByName ?? '').trim().isNotEmpty)
                      _kv(context, 'Release (korisnik)', p.releasedToProductionByName!),
                  ],
                  if (p.closedAt != null) ...[
                    _kv(
                      context,
                      'Formalno zatvoren',
                      p.closedAt!.toLocal().toString(),
                    ),
                    if ((p.closedByName ?? '').trim().isNotEmpty)
                      _kv(context, 'Zatvorio', p.closedByName!),
                  ],
                  if (DevelopmentPermissions.canCloseDevelopmentProject(
                        role: companyData['role']?.toString(),
                        companyData: companyData,
                      ) &&
                      p.status != DevelopmentProjectStatuses.closed &&
                      p.status != DevelopmentProjectStatuses.cancelled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _promptCloseDevelopmentProject(
                            context,
                            companyData: companyData,
                            project: p,
                          ),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Formalno zatvori projekat'),
                        ),
                      ),
                    ),
                ],
              ),
              DevelopmentProjectStagesSection(
                companyData: companyData,
                project: p,
                currentUserId: FirebaseAuth.instance.currentUser?.uid,
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
              DevelopmentProjectRisksSection(
                companyData: companyData,
                project: p,
              ),
              DevelopmentProjectApprovalsSection(
                companyData: companyData,
                project: p,
              ),
              DevelopmentProjectChangesSection(
                companyData: companyData,
                project: p,
              ),
              DevelopmentProjectReleaseReadinessSection(
                companyData: companyData,
                project: p,
              ),
              DevelopmentProjectDocumentsSection(
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
                  if (DevelopmentPermissions.canRunDevelopmentProjectAi(
                    role: companyData['role']?.toString(),
                    companyData: companyData,
                  ))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          final nav = Navigator.of(context, rootNavigator: true);
                          final service = DevelopmentProjectService();
                          final cid = (companyData['companyId'] ?? '')
                              .toString()
                              .trim();
                          final pk =
                              (companyData['plantKey'] ?? '').toString().trim();
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text('AI generiše sažetak…'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          try {
                            final md =
                                await service.runDevelopmentProjectAiAnalysis(
                              companyId: cid,
                              plantKey: pk,
                              projectId: p.id,
                            );
                            nav.pop();
                            if (!context.mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('AI sažetak projekta'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 400,
                                  child: MarkdownBody(
                                    data: md,
                                    selectable: true,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Zatvori'),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            nav.pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('AI: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Generiraj AI sažetak'),
                      ),
                    ),
                  if (DevelopmentPermissions.canRunDevelopmentProjectAi(
                    role: companyData['role']?.toString(),
                    companyData: companyData,
                  ))
                    const SizedBox(height: 12),
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
                  if (!DevelopmentPermissions.canRunDevelopmentProjectAi(
                        role: companyData['role']?.toString(),
                        companyData: companyData,
                      ) &&
                      ai.riskPrediction.isEmpty &&
                      ai.delayProbability == null)
                    Text(
                      'AI analiza još nije pokrenuta.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (DevelopmentPermissions.canRunDevelopmentProjectAi(
                        role: companyData['role']?.toString(),
                        companyData: companyData,
                      ) &&
                      ai.riskPrediction.isEmpty &&
                      ai.delayProbability == null)
                    Text(
                      'Polja ispod pune se iz agregata; koristi dugme za svježi sažetak.',
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
