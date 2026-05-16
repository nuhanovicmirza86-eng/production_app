import 'package:flutter/material.dart';

import '../models/personal_employee_doc.dart';
import '../services/personal_employee_read_service.dart';

/// Minimalni pregled zaposlenika (read path / smoke) — bez create/edit/detalja.
class PersonalEmployeesListScreen extends StatefulWidget {
  const PersonalEmployeesListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<PersonalEmployeesListScreen> createState() =>
      _PersonalEmployeesListScreenState();
}

class _PersonalEmployeesListScreenState extends State<PersonalEmployeesListScreen> {
  final PersonalEmployeeReadService _readService = PersonalEmployeeReadService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zaposlenici')),
        body: const Center(
          child: Text(
            'Nedostaje podatak o kompaniji. Obrati se administratoru.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Zaposlenici')),
      body: StreamBuilder<List<PersonalEmployeeDoc>>(
        stream: _readService.streamEmployees(companyId: _companyId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Greška pri učitavanju: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const <PersonalEmployeeDoc>[];
          if (rows.isEmpty) {
            return const Center(child: Text('Nema zaposlenika u listi.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = rows[i];
              final name = '${e.firstName} ${e.lastName}'.trim();
              final parts = <String>[
                if (e.homePlantKey.isNotEmpty) e.homePlantKey,
                if (e.employmentType.isNotEmpty) e.employmentType,
                if (e.status.isNotEmpty) e.status,
              ];
              final subtitle = parts.join(' · ');
              return ListTile(
                title: Text(name.isEmpty ? '—' : name),
                subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
              );
            },
          );
        },
      ),
    );
  }
}
