import 'package:flutter/material.dart';

import '../widgets/qms_iatf_help.dart';
import 'qms_screens_bundle.dart' deferred as qms;

/// Centralni ulaz u QMS modul (pretplata `quality` + uloga iz matrice).
///
/// Ekrani destinacija učitavaju se **odgođeno** ([qms]) da prvi prikaz Huba ne vuče
/// sve QMS biblioteke odjednom (brži prvi frame, manji posao za JIT u debugu).
class QualityHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const QualityHubScreen({super.key, required this.companyData});

  Future<void> _pushQms(
    BuildContext context,
    Widget Function() page,
  ) async {
    await qms.loadLibrary();
    if (!context.mounted) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page()),
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
      (
        icon: Icons.menu_book_outlined,
        title: 'Metodologija · IATF',
        subtitle: 'Reakcijski plan, CAPA, PFMEA, ocjene rizika',
        iatfTitle: 'Metodologija',
        iatfMessage: QmsIatfStrings.methodologyWhy,
        onTap: () => _pushQms(
          context,
          () => qms.QmsMethodologyReferenceScreen(),
        ),
      ),
      (
        icon: Icons.dashboard_outlined,
        title: 'Dashboard',
        subtitle: 'KPI, otvoreni NCR/CAPA',
        iatfTitle: 'QMS dashboard',
        iatfMessage: QmsIatfStrings.dashboard,
        onTap: () => _pushQms(
          context,
          () => qms.QualityDashboardScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.folder_special_outlined,
        title: 'Dokumentacija',
        subtitle: 'Radni uputi, pakovanje, obrasci — kasnije vezano na proizvode',
        iatfTitle: 'Dokumentacija',
        iatfMessage: QmsIatfStrings.documentationHub,
        onTap: () => _pushQms(
          context,
          () => qms.QualityDocumentationScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.picture_as_pdf_outlined,
        title: 'Izvještaj za vodstvo',
        subtitle: 'NCR, CAPA, trend OK/NOK, top PFMEA · PDF',
        iatfTitle: 'Izvještaj za vodstvo',
        iatfMessage: QmsIatfStrings.managementReport,
        onTap: () => _pushQms(
          context,
          () => qms.QmsManagementReportScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.account_tree,
        title: 'PFMEA (proces)',
        subtitle: 'S, O, D, RPN, AP · po proizvodu',
        iatfTitle: 'PFMEA u QMS-u',
        iatfMessage: QmsIatfStrings.listPfmea,
        onTap: () => _pushQms(
          context,
          () => qms.QmsPfmeaListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.engineering_outlined,
        title: 'Kontrolni planovi',
        subtitle: 'Master data (APQP)',
        iatfTitle: 'Kontrolni plan (APQP)',
        iatfMessage:
            '${QmsIatfStrings.kpiControlPlans}\n\n${QmsIatfStrings.termApqp}',
        onTap: () => _pushQms(
          context,
          () => qms.ControlPlansListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.fact_check_outlined,
        title: 'Planovi inspekcije',
        subtitle: 'Ulaz / u procesu / finalno',
        iatfTitle: 'Plan inspekcije',
        iatfMessage: QmsIatfStrings.kpiInspectionPlans,
        onTap: () => _pushQms(
          context,
          () => qms.InspectionPlansListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.qr_code_scanner,
        title: 'Izvrši inspekciju',
        subtitle: 'Sken LOT-a ili naloga',
        iatfTitle: 'Izvršenje inspekcije',
        iatfMessage:
            '${QmsIatfStrings.executeInspection}\n\n${QmsIatfStrings.termTraceability}',
        onTap: () => _pushQms(
          context,
          () => qms.ExecuteInspectionScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.history,
        title: 'Povijest inspekcija',
        subtitle: 'Zadnji OK/NOK, lot, plan, datum',
        iatfTitle: 'Povijest inspekcija',
        iatfMessage: QmsIatfStrings.listInspectionResults,
        onTap: () => _pushQms(
          context,
          () => qms.InspectionResultsListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.support_agent_outlined,
        title: 'Reklamacija kupca',
        subtitle: 'NCR · izvor CUSTOMER',
        iatfTitle: 'Reklamacija kupca',
        iatfMessage: QmsIatfStrings.claimCustomer,
        onTap: () => _pushQms(
          context,
          () => qms.NcrClaimCreateScreen(
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
        onTap: () => _pushQms(
          context,
          () => qms.NcrClaimCreateScreen(
            companyData: cd,
            claimSource: 'SUPPLIER',
          ),
        ),
      ),
      (
        icon: Icons.report_gmailerrorred_outlined,
        title: 'NCR',
        subtitle: 'Svi neskladi',
        iatfTitle: 'NCR (nesklad)',
        iatfMessage: QmsIatfStrings.listNcr,
        onTap: () => _pushQms(
          context,
          () => qms.NcrListScreen(companyData: cd),
        ),
      ),
      (
        icon: Icons.task_alt_outlined,
        title: 'CAPA',
        subtitle: 'Korektivne akcije',
        iatfTitle: 'CAPA',
        iatfMessage: QmsIatfStrings.listCapa,
        onTap: () => _pushQms(
          context,
          () => qms.CapaTrackingScreen(companyData: cd),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalitet (QMS)'),
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
                'IATF-friendly QMS: kontrolni plan → inspekcija → NCR → CAPA → sljedljivost.',
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
