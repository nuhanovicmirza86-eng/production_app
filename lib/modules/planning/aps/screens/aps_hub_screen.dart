import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../helpers/aps_gantt_info_copy.dart';
import '../helpers/aps_session_context.dart';
import '../services/aps_operational_cache.dart';
import '../services/aps_p1_write_service.dart';
import '../widgets/aps_info_icon_button.dart';
import 'aps_capacity_screen.dart';
import 'aps_gantt_read_only_screen.dart';
import 'aps_ai_execution_assistant_screen.dart';
import 'aps_optimization_screen.dart';
import 'aps_scenarios_demands_screen.dart';

/// Operativni APS hub — kanonski ulaz iz Production dashboarda.
///
/// Gate: [ProductionAccessHelper.canAccessApsP1Callable] (modul + uloga).
/// Debug Callable smoke (P0/P1/P2) ostaje odvojeno u [ApsDebugHubScreen].
class ApsHubScreen extends StatefulWidget {
  const ApsHubScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ApsHubScreen> createState() => _ApsHubScreenState();
}

class _ApsHubScreenState extends State<ApsHubScreen> {
  late final ApsSessionContext _session;
  final ApsP1WriteService _prefetchService = ApsP1WriteService();

  @override
  void initState() {
    super.initState();
    _session = ApsSessionContext.fromCompanyData(widget.companyData);
    if (_session.accessOk && _session.hasPlantKey) {
      ApsOperationalCache.instance.warmUp(
        service: _prefetchService,
        companyId: _session.companyId,
        plantKey: _session.plantKey,
      );
    }
  }

  bool get _accessOk => _session.accessOk;

  @override
  Widget build(BuildContext context) {
    if (!_accessOk) {
      return Scaffold(
        appBar: AppBar(title: const Text('Napredno planiranje')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nema pristupa. Potrebna pretplata Napredno planiranje i '
              'Scenariji planiranja te uloga menadžera proizvodnje, administratora '
              'ili super administratora.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final companyData = widget.companyData;
    final hasAiAssistant = ProductionModuleKeys.hasApsAiAssistantModule(
      companyData,
    );
    final canOpenAiAssistant = ProductionAccessHelper.canAccessApsP6Callable(
      role: _session.role,
      companyData: companyData,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Napredno planiranje'),
        actions: [
          IconButton(
            tooltip: 'Informacije o modulu',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: 'Napredno planiranje',
              body: ApsGanttInfoCopy.hubModuleInfoBody,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Odaberite funkciju planiranja. Scenariji i potrebe, Kapaciteti, '
            'Optimizacija, Raspored po resursima i Operonix AI APS Asistent '
            '(uz pretplatu) su dostupni prema modulu i ulozi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ApsHubTile(
            icon: Icons.list_alt_outlined,
            title: 'Scenariji i potrebe',
            subtitle:
                'Kreiranje potražnji i scenarija, sastav scenarija, generiranje rasporeda '
                'i ulaz u raspored po resursima.',
            infoBody: ApsGanttInfoCopy.hubScenariosDemandsCardInfoBody,
            enabled: true,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ApsScenariosDemandsScreen(companyData: companyData),
                ),
              );
            },
          ),
          _ApsHubTile(
            icon: Icons.speed_outlined,
            title: 'Kapaciteti',
            subtitle:
                'Gruba procjena kapaciteta, opterećenje resursa i upozorenja po scenariju.',
            infoBody: ApsGanttInfoCopy.hubCapacityCardInfoBody,
            enabled: true,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ApsCapacityScreen(companyData: companyData),
                ),
              );
            },
          ),
          _ApsHubTile(
            icon: Icons.tune_outlined,
            title: ApsGanttInfoCopy.optimizationScreenTitle,
            subtitle: ApsGanttInfoCopy.optimizationHubTileSubtitle,
            infoBody: ApsGanttInfoCopy.hubOptimizationCardInfoBody,
            enabled: true,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ApsOptimizationScreen(companyData: companyData),
                ),
              );
            },
          ),
          _ApsHubTile(
            icon: Icons.psychology_outlined,
            title: ApsGanttInfoCopy.aiApsAssistantModuleName,
            subtitle: ApsGanttInfoCopy.aiApsAssistantHubTileSubtitle,
            infoBody: ApsGanttInfoCopy.hubAiCardInfoBody,
            enabled: hasAiAssistant && canOpenAiAssistant,
            badge: hasAiAssistant ? null : 'Kasnije',
            onTap: hasAiAssistant && canOpenAiAssistant
                ? () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ApsAiExecutionAssistantScreen(
                          companyData: companyData,
                        ),
                      ),
                    );
                  }
                : null,
          ),
          _ApsHubTile(
            icon: Icons.view_timeline_outlined,
            title: ApsGanttInfoCopy.hubScheduleTileTitle,
            subtitle: ApsGanttInfoCopy.hubScheduleTileSubtitle,
            infoBody: ApsGanttInfoCopy.hubScheduleCardInfoBody,
            enabled: true,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ApsGanttReadOnlyScreen(companyData: companyData),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApsHubTile extends StatelessWidget {
  const _ApsHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.badge,
    this.infoBody,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String? badge;
  final String? infoBody;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = !enabled;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: muted ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : null,
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          size: 32,
          color: muted ? cs.onSurfaceVariant : cs.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: muted ? cs.onSurfaceVariant : null,
                ),
              ),
            ),
            if (infoBody != null && infoBody!.trim().isNotEmpty)
              ApsInfoIconButton(
                tooltip: 'O kartici $title',
                title: title,
                body: infoBody!,
                size: 18,
              ),
            if (badge != null)
              Chip(
                label: Text(badge!, style: theme.textTheme.labelSmall),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.chevron_right)
            : Icon(Icons.lock_outline, color: cs.outline),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
