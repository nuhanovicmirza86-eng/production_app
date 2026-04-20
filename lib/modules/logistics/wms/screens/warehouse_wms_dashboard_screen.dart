import 'package:flutter/material.dart';

import 'wms_picking_screen.dart';
import 'wms_putaway_screen.dart';
import 'wms_quality_screen.dart';
import 'wms_receipts_list_screen.dart';
import 'wms_receiving_screen.dart';
import 'wms_shipping_screen.dart';

/// Ulaz u WMS tok: prijem → karantin / QA → putaway → FIFO → otpremna zona.
class WarehouseWmsDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const WarehouseWmsDashboardScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centralni magacin (WMS)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'IATF tok: prijem u zonu RECEIVING (karantin) → odluka kvalitete → putaway → FIFO u zoni APPROVED / PICKING → otpremna zona.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            icon: Icons.move_to_inbox_outlined,
            title: 'Prijem robe',
            subtitle: 'Više stavki; kreira logistics_receipt + lot u karantinu.',
            builder: (_) => WmsReceivingScreen(companyData: companyData),
          ),
          _tile(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Povijest prijema',
            subtitle: 'Zadnjih 50 dokumenata GR.',
            builder: (_) => WmsReceiptsListScreen(companyData: companyData),
          ),
          _tile(
            context,
            icon: Icons.verified_outlined,
            title: 'Kvaliteta (karantin)',
            subtitle: 'Lista lotova u statusu quarantine.',
            builder: (_) => WmsQualityScreen(companyData: companyData),
          ),
          _tile(
            context,
            icon: Icons.view_module_outlined,
            title: 'Putaway',
            subtitle: 'Lokacija + prijelaz u pripremu (PICKING_STAGING).',
            builder: (_) => WmsPutawayScreen(companyData: companyData),
          ),
          _tile(
            context,
            icon: Icons.format_list_numbered_outlined,
            title: 'FIFO picking',
            subtitle: 'Preporučeni redoslijed lotova za artikl.',
            builder: (_) => WmsPickingScreen(companyData: companyData),
          ),
          _tile(
            context,
            icon: Icons.local_shipping_outlined,
            title: 'Otpremna zona',
            subtitle: 'Premjesti lot u SHIPPING.',
            builder: (_) => WmsShippingScreen(companyData: companyData),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: builder),
          );
        },
      ),
    );
  }
}
