import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../production/station_pages/screens/production_evidence_operator_hub_screen.dart';
import '../widgets/qms_iatf_help.dart';
import 'capa_tracking_screen.dart';
import 'control_plans_list_screen.dart';
import 'execute_inspection_screen.dart';
import 'inspection_plans_list_screen.dart';
import 'inspection_results_list_screen.dart';
import 'internal_audit_list_screen.dart';
import 'ncr_claim_create_screen.dart';
import 'ncr_action_history_hub_screen.dart';
import 'ncr_list_screen.dart';
import 'ncr_open_actions_list_screen.dart';
import 'quality_dashboard_screen.dart';
import 'quality_documentation_screen.dart';
import 'qms_management_report_screen.dart';
import 'qms_methodology_reference_screen.dart';
import 'qms_pfmea_list_screen.dart';

/// Centralni ulaz u QMS modul (pretplata `quality` + uloga iz matrice).
class QualityHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const QualityHubScreen({super.key, required this.companyData});

  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  Future<void> _push(
    BuildContext context,
    Widget page,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cd = companyData;

    final items = <({
      IconData icon,
      String title,
      String subtitle,
      String? iatfTitle,
      String? iatfMessage,
      Future<void> Function() onTap,
    })>[
      if (ProductionAccessHelper.canAccessQualityControlEvidenceHub(_role))
        (
          icon: Icons.fact_check_outlined,
          title: 'Kontrolne evidencije',
          subtitle:
              'Kontrola pakovanja, finalna kontrola, kontrola u procesu i odobrenje prvog komada.',
          iatfTitle: 'Kontrolne evidencije',
          iatfMessage:
              'Operativni ulaz u kontrolne evidencije koje Operater kvaliteta smije završiti.',
          onTap: () => _push(
            context,
            ProductionEvidenceOperatorHubScreen(companyData: cd),
          ),
        ),
      if (ProductionAccessHelper.canAccessNcrOpenActionsInbox(_role))
        (
          icon: Icons.inbox_outlined,
          title: 'Moje otvorene akcije',
          subtitle:
              'NCR zadaci po ulozi — dorada, ponovna kontrola, zatvaranje.',
          iatfTitle: 'Moje otvorene akcije',
          iatfMessage:
              'Jedinstveni inbox otvorenih koraka NCR toka — direktan ulaz u zadatak.',
          onTap: () => _push(
            context,
            NcrOpenActionsListScreen(companyData: cd),
          ),
        ),
      (
        icon: Icons.menu_book_outlined,
        title: 'Metodologija · IATF',
        subtitle: 'Reakcijski plan, CAPA, PFMEA, ocjene rizika',
        iatfTitle: 'Metodologija',
        iatfMessage: QmsIatfStrings.methodologyWhy,
        onTap: () => _push(
          context,
          const QmsMethodologyReferenceScreen(),
        ),
      ),
      (
        icon: Icons.dashboard_outlined,
        title: 'Pregled kvaliteta',
        subtitle: 'Ključni brojevi, otvorena neslaganja i CAPA',
        iatfTitle: 'Pregled kvaliteta',
        iatfMessage: QmsIatfStrings.dashboard,
        onTap: () => _push(
          context,
          QualityDashboardScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.folder_special_outlined,
        title: 'Dokumentacija',
        subtitle: 'Radne upute, pakovanje, obrasci — pregled dokumenata',
        iatfTitle: 'Dokumentacija',
        iatfMessage: QmsIatfStrings.documentationHub,
        onTap: () => _push(
          context,
          QualityDocumentationScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.picture_as_pdf_outlined,
        title: 'Izvještaj za vodstvo',
        subtitle: 'NCR, CAPA, trend OK/NOK, top PFMEA · PDF',
        iatfTitle: 'Izvještaj za vodstvo',
        iatfMessage: QmsIatfStrings.managementReport,
        onTap: () => _push(
          context,
          QmsManagementReportScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.account_tree,
        title: 'PFMEA (proces)',
        subtitle: 'S, O, D, RPN, AP · po proizvodu',
        iatfTitle: 'PFMEA u QMS-u',
        iatfMessage: QmsIatfStrings.listPfmea,
        onTap: () => _push(
          context,
          QmsPfmeaListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.engineering_outlined,
        title: 'Kontrolni planovi',
        subtitle: 'Master data (APQP)',
        iatfTitle: 'Kontrolni plan (APQP)',
        iatfMessage:
            '${QmsIatfStrings.kpiControlPlans}\n\n${QmsIatfStrings.termApqp}',
        onTap: () => _push(
          context,
          ControlPlansListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.fact_check_outlined,
        title: 'Planovi kontrole',
        subtitle: 'Ulaz / u procesu / finalno',
        iatfTitle: 'Plan kontrole',
        iatfMessage: QmsIatfStrings.kpiInspectionPlans,
        onTap: () => _push(
          context,
          InspectionPlansListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.qr_code_scanner,
        title: 'Izvrši kontrolu',
        subtitle: 'Sken LOT-a ili naloga',
        iatfTitle: 'Izvršenje kontrole',
        iatfMessage:
            '${QmsIatfStrings.executeInspection}\n\n${QmsIatfStrings.termTraceability}',
        onTap: () => _push(
          context,
          ExecuteInspectionScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.history,
        title: 'Povijest kontrola',
        subtitle: 'Zadnji OK/NOK, lot, plan, datum',
        iatfTitle: 'Povijest kontrola',
        iatfMessage: QmsIatfStrings.listInspectionResults,
        onTap: () => _push(
          context,
          InspectionResultsListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.support_agent_outlined,
        title: 'Reklamacija kupca',
        subtitle: 'NCR · izvor CUSTOMER',
        iatfTitle: 'Reklamacija kupca',
        iatfMessage: QmsIatfStrings.claimCustomer,
        onTap: () => _push(
          context,
          NcrClaimCreateScreen(
            companyData: cd,
            claimSource: 'CUSTOMER',
          ),
        ),
      ),
      (
        icon: Icons.local_shipping_outlined,
        title: 'Reklamacija dobavljača',
        subtitle: 'NCR · izvor SUPPLIER (SCAR)',
        iatfTitle: 'Reklamacija dobavljača',
        iatfMessage: QmsIatfStrings.claimSupplier,
        onTap: () => _push(
          context,
          NcrClaimCreateScreen(
            companyData: cd,
            claimSource: 'SUPPLIER',
          ),
        ),
      ),
      (
        icon: Icons.report_gmailerrorred_outlined,
        title: 'NCR',
        subtitle: 'Neusklađenosti',
        iatfTitle: 'NCR (nesklad)',
        iatfMessage: QmsIatfStrings.listNcr,
        onTap: () => _push(
          context,
          NcrListScreen(companyData: cd),
        ),
      ),
      if (ProductionAccessHelper.canViewNcrActionHistory(_role))
        (
          icon: Icons.history_toggle_off,
          title: 'Historija akcija NCR-a',
          subtitle:
              'Poslovni zapis akcija — dorada, dodjela, rokovi i izvor.',
          iatfTitle: 'Historija akcija NCR-a',
          iatfMessage:
              'Append-only ledger akcija na neusaglašenostima — odvojeno od '
              'IATF audit traga i hodograma trenutnog koraka.',
          onTap: () => _push(
            context,
            NcrActionHistoryHubScreen(companyData: cd),
          ),
        ),
      (
        icon: Icons.task_alt_outlined,
        title: 'CAPA',
        subtitle: 'Korektivne akcije',
        iatfTitle: 'CAPA',
        iatfMessage: QmsIatfStrings.listCapa,
        onTap: () => _push(
          context,
          CapaTrackingScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.assignment_turned_in_outlined,
        title: 'Interni audit',
        subtitle: 'IATF 9.2 · nalazi i veza na CAPA',
        iatfTitle: 'Interni audit',
        iatfMessage: QmsIatfStrings.listInternalAudits,
        onTap: () => _push(
          context,
          InternalAuditListScreen(companyData: cd),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalitet'),
        actions: [
          QmsIatfInfoIcon(
            title: 'QMS i IATF 16949',
            message: QmsIatfStrings.hubModule,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'IATF zatvoreni krug: NCR → root cause / CAPA → verifikacija → zatvaranje '
                '(podaci po kompaniji).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            );
          }
          final e = items[index - 1];
          return _HubTile(
            icon: e.icon,
            title: e.title,
            subtitle: e.subtitle,
            iatfTitle: e.iatfTitle,
            iatfMessage: e.iatfMessage,
            onTap: e.onTap,
          );
        },
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final String? iatfTitle;
  final String? iatfMessage;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iatfTitle,
    this.iatfMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iatfTitle != null &&
                iatfMessage != null &&
                iatfTitle!.isNotEmpty &&
                iatfMessage!.isNotEmpty)
              QmsIatfInfoIcon(
                title: iatfTitle!,
                message: iatfMessage!,
                size: 20,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onTap(),
      ),
    );
  }
}
