import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// LAN uređaji — work_time_devices (demo).
class WorkTimeDevicesScreen extends StatelessWidget {
  const WorkTimeDevicesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uređaji za evidenciju')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Uređaji na pogonu šalju prijave preko lokalne mreže. Ova stranica '
            'samo prikazuje vezu, ne pristupa vašim adresama izravno iz pretraživača.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 2; i++)
            Card(
              child: ListTile(
                leading: const Icon(Icons.router_outlined),
                title: Text('Kiosk #${i + 1}'),
                subtitle: Text('Mrežna adresa: 192.168.1.${10 + i} · zadnja usklađenost: probni zapis'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}
