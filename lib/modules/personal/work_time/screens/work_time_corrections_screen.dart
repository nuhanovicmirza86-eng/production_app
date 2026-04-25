import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Korekcije — [work_time_corrections] + [company_audit_logs] (IATF).
class WorkTimeCorrectionsScreen extends StatelessWidget {
  const WorkTimeCorrectionsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Korekcije evidencije')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Svaka ispravka: razlog, stara i nova vrijednost, tko je odobrio. '
            'Tijek u tvrtki može uključivati dva rukovoditelja (ovisno o pravilu).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Oznaka')),
                  DataColumn(label: Text('Zaposlenik')),
                  DataColumn(label: Text('Dan')),
                  DataColumn(label: Text('Vrsta promjene')),
                  DataColumn(label: Text('Bilo je')),
                  DataColumn(label: Text('Sada je')),
                  DataColumn(label: Text('Razlog')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Odobrio')),
                ],
                rows: const [
                  DataRow(
                    cells: [
                      DataCell(Text('C-001')),
                      DataCell(Text('M. Ivić')),
                      DataCell(Text('24.4.')),
                      DataCell(Text('pomak ulaza')),
                      DataCell(Text('14:00')),
                      DataCell(Text('13:50')),
                      DataCell(Text('Kiosk kasnio')),
                      DataCell(Text('odobreno')),
                      DataCell(Text('Admin')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('C-002')),
                      DataCell(Text('A. Kovač')),
                      DataCell(Text('1.4.')),
                      DataCell(Text('Dodatni izlaz')),
                      DataCell(Text('—')),
                      DataCell(Text('22:00')),
                      DataCell(Text('Zaboravljen očitan')),
                      DataCell(Text('na čekanju')),
                      DataCell(Text('—')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
