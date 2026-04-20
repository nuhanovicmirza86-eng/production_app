import 'package:flutter/material.dart';

import '../../production/qr/production_qr_scan_flow.dart';
import '../widgets/logistics_hub_overview_tab.dart';
import '../warehouse_hub/screens/warehouse_hub_screen.dart';
import '../wms/screens/wms_picking_screen.dart';
import '../wms/screens/wms_putaway_screen.dart';
import '../wms/screens/wms_quality_screen.dart';
import '../wms/screens/wms_receipts_list_screen.dart';
import '../wms/screens/wms_receiving_screen.dart';
import '../wms/screens/wms_shipping_screen.dart';
import '../routes/screens/warehouse_routes_screen.dart';
import '../adjustments/screens/inventory_adjustments_screen.dart';

/// Glavni radni prostor logističkog menadžera: **pregled zona + master (MAG_*) + cijeli WMS tok + QR kao alat**.
///
/// Otvara se samo kad kompanija ima modul `logistics` u pretplati (vidi [ProductionDashboardScreen]).
///
/// QR nije ulazni ekran — zadnji je tab (sken na podu kad treba).
class LogisticsHubEntryScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const LogisticsHubEntryScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 11,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Centralni magacin / Hub'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pregled'),
              Tab(text: 'Master'),
              Tab(text: 'Prijem'),
              Tab(text: 'Kvaliteta'),
              Tab(text: 'Putaway'),
              Tab(text: 'FIFO'),
              Tab(text: 'Otpremna'),
              Tab(text: 'Evidencija'),
              Tab(text: 'Rute'),
              Tab(text: 'Korekcije'),
              Tab(text: 'QR'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Builder(
              builder: (ctx) => LogisticsHubOverviewTab(
                onNavigateToHubTab: (i) =>
                    DefaultTabController.of(ctx).animateTo(i),
              ),
            ),
            WarehouseHubScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsReceivingScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsQualityScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsPutawayScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsPickingScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsShippingScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WmsReceiptsListScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            WarehouseRoutesScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            InventoryAdjustmentsScreen(
              companyData: companyData,
              embedInHubShell: true,
            ),
            _LogisticsQrToolTab(companyData: companyData),
          ],
        ),
      ),
    );
  }
}

class _LogisticsQrToolTab extends StatelessWidget {
  const _LogisticsQrToolTab({required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Skeniranje na podu',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'QR nije „ulaz u magacin“ — ovo je alat kad trebaš pročitati kod '
          '(nalog, etiketa, lot, paleta). Na desktopu bez kamere možeš zalijepiti sadržaj.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => runProductionQrScanFlow(
            context: context,
            companyData: companyData,
          ),
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Otvori skeniranje QR'),
        ),
      ],
    );
  }
}
