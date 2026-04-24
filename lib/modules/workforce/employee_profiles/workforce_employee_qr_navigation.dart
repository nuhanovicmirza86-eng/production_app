import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import 'employee_edit_screen.dart';
import 'workforce_qr_payload.dart';

/// Otvara [EmployeeEditScreen] nakon valjanog [tryParseWorkforceEmployeeQr].
///
/// Koriste [WorkforceEmployeeQrScanScreen] i glavni proizvodni QR tok.
/// Vraća `true` ako je uređivač otvoren i zatvoren (uspješan tok).
Future<bool> openWorkforceEmployeeFromBadgeQr({
  required BuildContext context,
  required Map<String, dynamic> companyData,
  required String rawPayload,
}) async {
  final parsed = tryParseWorkforceEmployeeQr(rawPayload);
  if (parsed == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ovo nije Operonix bedž radnika. Koristi QR s tiskanog bedža iz modula Radna snaga.',
          ),
        ),
      );
    }
    return false;
  }

  final sessionCompanyId = (companyData['companyId'] ?? '').toString().trim();
  final sessionPlantKey = (companyData['plantKey'] ?? '').toString().trim();
  final role = ProductionAccessHelper.normalizeRole(companyData['role']);
  final globalTenantAdmin =
      ProductionAccessHelper.isAdminRole(role) ||
      ProductionAccessHelper.isSuperAdminRole(role);

  if (parsed.companyId != sessionCompanyId) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR je za drugu kompaniju. Prijavi se na ispravan nalog.',
          ),
        ),
      );
    }
    return false;
  }

  if (!globalTenantAdmin && parsed.plantKey != sessionPlantKey) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR je za drugi pogon od tvog profila. Odaberi ispravan pogon ili koristi nalog admina.',
          ),
        ),
      );
    }
    return false;
  }

  try {
    final ref = FirebaseFirestore.instance
        .collection('workforce_employees')
        .doc(parsed.employeeDocId);
    final snap = await ref.get();
    if (!snap.exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Radnik nije pronađen u bazi.')),
        );
      }
      return false;
    }

    final data = snap.data() ?? {};
    final docCompany = (data['companyId'] ?? '').toString().trim();
    final docPlant = (data['plantKey'] ?? '').toString().trim();
    // Admin / super_admin u kompaniji može otvoriti radnika u pogonskom kontekstu s bedža
    // (sessionPlantKey često odgovara „trenutnom“ pogonu u UI-ju, ne pogonu iz QR-a).
    final expectedPlant =
        globalTenantAdmin ? parsed.plantKey.trim() : sessionPlantKey.trim();
    if (docCompany != sessionCompanyId || docPlant != expectedPlant) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              globalTenantAdmin
                  ? 'Podaci radnika ne odgovaraju QR-u (pogon ili kompanija).'
                  : 'Zapis ne pripada tvom pogonu.',
            ),
          ),
        );
      }
      return false;
    }

    final employee = WorkforceEmployee.fromDoc(snap);
    if (!context.mounted) return false;
    final mergedData = Map<String, dynamic>.from(companyData)
      ..['plantKey'] = employee.plantKey;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            EmployeeEditScreen(companyData: mergedData, existing: employee),
      ),
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Otvaranje profila nije uspjelo. Pokušaj ponovno.'),
        ),
      );
    }
    return false;
  }
}
